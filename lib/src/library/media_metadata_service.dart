import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/track.dart';
import 'native_bridge.dart';

/// Fills in the details a bare file listing cannot know: real tags, embedded
/// cover art, and duration.
///
/// SAF hands over a display name and nothing else, so without this every track
/// would be titled by its filename with no artwork - even though the files
/// almost always carry perfect ID3 tags.
///
/// Reads go through the platform extractor, so this works for every format
/// Android can decode and needs no bundled tooling. Results are cached per URI
/// for the session, and artwork is cached on disk by the platform side.
class MediaMetadataService {
  MediaMetadataService({NativeBridge? bridge})
      : _bridge = bridge ?? const NativeBridge();

  final NativeBridge _bridge;

  /// How many files to inspect concurrently. Metadata reads touch disk and do
  /// a decode step, so going wide just thrashes the storage queue.
  static const _concurrency = 4;

  final Map<String, MediaTags> _cache = {};
  final Map<String, List<double>> _waveforms = {};
  final Set<String> _inFlight = {};

  /// Tags for [track], read once per session.
  Future<MediaTags> tagsFor(Track track) {
    final cached = _cache[track.uri];
    if (cached != null) return Future.value(cached);
    return _readTags(track);
  }

  Future<MediaTags> _readTags(Track track) async {
    // Another caller may already be reading this file; share the result rather
    // than hammering the extractor with duplicates.
    while (_inFlight.contains(track.uri)) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final cached = _cache[track.uri];
      if (cached != null) return cached;
    }

    _inFlight.add(track.uri);
    try {
      final tags = await _bridge.readMetadata(track.uri);
      _cache[track.uri] = tags;
      return tags;
    } on PlatformException catch (e) {
      debugPrint('metadata read failed for ${track.uri}: ${e.message}');
      return const MediaTags();
    } on MissingPluginException {
      // Platform side unavailable (unit tests); tags simply stay empty.
      return const MediaTags();
    } finally {
      _inFlight.remove(track.uri);
    }
  }

  /// Waveform peaks for [track], decoded once per session.
  Future<List<double>> waveformFor(Track track) {
    final cached = _waveforms[track.uri];
    if (cached != null) return Future.value(cached);
    return _readWaveform(track);
  }

  Future<List<double>> _readWaveform(Track track) async {
    _inFlight.add('wave:${track.uri}');
    try {
      final peaks = await _bridge.readWaveform(track.uri);
      _waveforms[track.uri] = peaks;
      return peaks;
    } catch (e) {
      debugPrint('waveform decode failed for ${track.uri}: $e');
      return const [];
    } finally {
      _inFlight.remove('wave:${track.uri}');
    }
  }

  /// Returns [track] enriched with real tags where the file has them.
  ///
  /// Filename-derived values are kept as the fallback, so a track with no tags
  /// still shows something sensible.
  Track enrich(Track track, MediaTags tags) {
    if (tags.isEmpty && !tags.hasArtwork) return track;
    return Track(
      id: track.id,
      uri: track.uri,
      // Tag wins, but an empty or placeholder-looking tag does not.
      title: _cleanTag(tags.title) ?? track.title,
      artist: _cleanTag(tags.artist) ?? track.artist,
      album: tags.album,
      duration: tags.duration ?? track.duration,
      artUri: tags.hasArtwork ? Uri.file(tags.artworkPath!) : track.artUri,
    );
  }

  /// Rejects tags that are technically present but useless.
  static String? _cleanTag(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    // Some taggers write the literal filename or a lone dash.
    if (trimmed == '-' || trimmed.length > 200) return null;
    return trimmed;
  }

  /// Reads tags for a batch of tracks with bounded concurrency.
  ///
  /// Returns the tracks in the same order, enriched where possible. Failures
  /// are swallowed per file so one unreadable track cannot fail the scan.
  Future<List<Track>> enrichAll(List<Track> tracks) async {
    final results = List<Track?>.filled(tracks.length, null);
    var next = 0;

    Future<void> worker() async {
      while (true) {
        final index = next++;
        if (index >= tracks.length) return;
        final track = tracks[index];
        try {
          final tags = await tagsFor(track);
          results[index] = enrich(track, tags);
        } catch (_) {
          results[index] = track;
        }
      }
    }

    await Future.wait([
      for (var i = 0; i < _concurrency; i++) worker(),
    ]);

    return [for (final t in results) t ?? tracks.first];
  }
}
