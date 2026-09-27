import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Tags and cover art read from an audio file by the platform extractor.
///
/// Every field is optional: plenty of files in the wild carry nothing useful,
/// and a missing tag should degrade to the filename rather than throw.
class MediaTags {
  const MediaTags({
    this.title,
    this.artist,
    this.album,
    this.artworkPath,
    this.duration,
  });

  final String? title;
  final String? artist;
  final String? album;

  /// Absolute path to a downsampled JPEG in the app cache.
  final String? artworkPath;

  final Duration? duration;

  bool get hasArtwork => artworkPath != null;
  bool get isEmpty => title == null && artist == null && album == null;
}

/// One entry inside a picked music folder, as reported by the platform side.
///
/// Enumeration is deliberately one directory level at a time: a granted tree
/// can be enormous, and walking it in full blocks longer than a UI can wait.
/// Subdirectories come back flagged as [isDirectory] for the caller to expand.
class ScannedFile {
  const ScannedFile({
    required this.uri,
    required this.name,
    required this.relativePath,
    this.isDirectory = false,
    this.sizeBytes = 0,
    this.lastModifiedMs,
  });

  /// `content://` URI, which is what ExoPlayer needs to read the file.
  final String uri;
  final String name;

  /// Path relative to the picked folder, e.g. `Rock/Song.mp3`.
  final String relativePath;

  /// True when this entry is a subdirectory rather than an audio file.
  final bool isDirectory;

  final int sizeBytes;
  final DateTime? lastModifiedMs;
}

/// A folder the user granted access to, via the system directory picker.
class MusicFolder {
  const MusicFolder({
    required this.uri,
    required this.name,
    this.trackCount = 0,
  });

  /// `content://` tree URI.
  final String uri;
  final String name;
  final int trackCount;

  MusicFolder copyWith({int? trackCount}) => MusicFolder(
        uri: uri,
        name: name,
        trackCount: trackCount ?? this.trackCount,
      );

  Map<String, dynamic> toJson() => {
        'uri': uri,
        'name': name,
      };

  static MusicFolder fromJson(Map<String, dynamic> json) => MusicFolder(
        uri: json['uri'] as String? ?? '',
        name: json['name'] as String? ?? 'Folder',
      );
}

/// Talks to the Kotlin side for anything that needs the Storage Access
/// Framework: picking a folder and listing the audio inside one.
class NativeBridge {
  const NativeBridge();

  static const _channel = MethodChannel('com.mako.sourcecrush/native');

  /// Upper bound on a single folder walk.
  static const scanTimeout = Duration(seconds: 45);

  /// Directory the package manager extracted the APK's native libraries to,
  /// e.g. `/data/app/~~hash/com.mako.sourcecrush-hash/lib/arm64`.
  ///
  /// Unlike the app's data directory this location is executable, which is why
  /// helper binaries are shipped as jniLibs rather than as assets.
  Future<String?> nativeLibraryDir() =>
      _channel.invokeMethod<String>('nativeLibraryDir');

  /// Opens the system folder picker.
  ///
  /// Returns the granted tree as a `content://` URI, or null if the user
  /// backed out. The Kotlin side takes a persistable read permission before
  /// returning, so access survives reboots.
  Future<String?> pickMusicFolder() =>
      _channel.invokeMethod<String>('pickMusicFolder');

  /// Lists the contents of one directory inside a granted tree.
  ///
  /// Pass an empty [relativeDir] for the picked folder's own files, or a path
  /// like `Rock` to descend. Bounded by [scanTimeout] so a provider that never
  /// answers cannot leave the library spinner running forever.
  Future<List<ScannedFile>> listAudioIn(
    String treeUri, {
    String relativeDir = '',
    Duration timeout = scanTimeout,
  }) async {
    List<Object?>? raw;
    try {
      raw = await _channel
          .invokeListMethod<Object?>(
            'listAudioIn',
            {'treeUri': treeUri, 'relativeDir': relativeDir},
          )
          .timeout(timeout);
    } on TimeoutException {
      debugPrint(
        'listAudioIn timed out after ${timeout.inSeconds}s: '
        '$treeUri/$relativeDir',
      );
      rethrow;
    }
    if (raw == null) return const [];
    return [
      for (final item in raw)
        if (item is Map)
          ScannedFile(
            uri: item['uri'] as String? ?? '',
            name: item['name'] as String? ?? '',
            relativePath: item['relativePath'] as String? ?? '',
            isDirectory: item['isDirectory'] as bool? ?? false,
            sizeBytes: (item['size'] as num?)?.toInt() ?? 0,
            lastModifiedMs: (item['lastModified'] as num?) == null
                ? null
                : DateTime.fromMillisecondsSinceEpoch(
                    (item['lastModified'] as num).toInt(),
                  ),
          ),
    ];
  }

  /// Tags and cover art read out of the file itself.
  ///
  /// [artworkPath] points at a downsampled JPEG in the app cache rather than
  /// shipping image bytes across the channel.
  Future<MediaTags> readMetadata(String uri) async {
    final raw = await _channel.invokeMapMethod<String, Object?>(
      'readMetadata',
      {'uri': uri},
    );
    if (raw == null) return const MediaTags();
    return MediaTags(
      title: raw['title'] as String?,
      artist: raw['artist'] as String?,
      album: raw['album'] as String?,
      artworkPath: raw['artworkPath'] as String?,
      duration: switch (raw['durationMs']) {
        final num ms => Duration(milliseconds: ms.toInt()),
        _ => null,
      },
    );
  }

  /// Peak amplitudes in 0..1, decoded from the audio for the waveform view.
  ///
  /// Returns an empty list when the file cannot be decoded, which the UI
  /// renders as a flat placeholder rather than an error.
  Future<List<double>> readWaveform(String uri, {int buckets = 96}) async {
    final raw = await _channel
        .invokeMapMethod<String, Object?>(
          'readWaveform',
          {'uri': uri, 'buckets': buckets},
        )
        .timeout(const Duration(seconds: 30));
    final peaks = raw?['peaks'] as List<Object?>? ?? const [];
    return [for (final p in peaks) (p as num).toDouble().clamp(0.0, 1.0)];
  }

  /// Releases the persisted permission for a folder the user removed.
  Future<void> releaseFolder(String treeUri) =>
      _channel.invokeMethod<void>('releaseFolder', {'treeUri': treeUri});

  /// True when the folder's persisted grant is still valid (the user may have
  /// revoked it from system settings, or the folder may have been deleted).
  Future<bool> hasFolderAccess(String treeUri) async =>
      await _channel.invokeMethod<bool>('hasFolderAccess', {'treeUri': treeUri}) ??
      false;

  /// Small helper for the rare case where a scanned file is a real file path
  /// rather than a content URI.
  static File? asFile(String uri) {
    final parsed = Uri.tryParse(uri);
    if (parsed == null || parsed.scheme != 'file') return null;
    final path = parsed.toFilePath();
    return File(path);
  }
}
