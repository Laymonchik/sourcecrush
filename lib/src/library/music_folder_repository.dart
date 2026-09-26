import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:path_provider/path_provider.dart';

import '../models/track.dart';
import 'library_repository.dart';
import 'native_bridge.dart';

/// Manages the set of folders the user has chosen to scan, and enumerates the
/// audio inside them.
///
/// The app never walks the whole device. Access is granted per directory
/// through the system picker and persisted, so the library stays predictable
/// and free of ringtones, voice memos and duplicate rips.
class MusicFolderRepository {
  MusicFolderRepository({NativeBridge? bridge})
      : _bridge = bridge ?? const NativeBridge();

  final NativeBridge _bridge;

  static const _fileName = 'music_folders.json';

  List<MusicFolder> _folders = const [];
  List<MusicFolder> get folders => _folders;

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<void> load() async {
    final file = await _file();
    if (!file.existsSync()) {
      _folders = const [];
      return;
    }
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! List) {
        _folders = const [];
        return;
      }
      _folders = decoded
          .whereType<Map<String, dynamic>>()
          .map(MusicFolder.fromJson)
          .where((f) => f.uri.isNotEmpty)
          .toList();
    } on FormatException {
      _folders = const [];
    }
  }

  Future<void> _persist() async {
    final file = await _file();
    await file.writeAsString(
      jsonEncode([for (final f in _folders) f.toJson()]),
      flush: true,
    );
  }

  /// Opens the system picker and registers whatever the user chooses.
  ///
  /// Returns the new folder, or null if the user cancelled. Re-adding a folder
  /// that is already registered is a no-op rather than a duplicate.
  Future<MusicFolder?> addFolder() async {
    final uri = await _bridge.pickMusicFolder();
    if (uri == null || uri.isEmpty) return null;

    if (_folders.any((f) => f.uri == uri)) return null;

    final name = _displayNameFor(uri);
    final folder = MusicFolder(uri: uri, name: name);
    _folders = [..._folders, folder];
    await _persist();
    return folder;
  }

  /// Forgets a folder and drops the persisted permission with it.
  Future<void> removeFolder(String uri) async {
    _folders = [for (final f in _folders) if (f.uri != uri) f];
    await _persist();
    await _bridge.releaseFolder(uri);
  }

  /// Derives a human readable name from the tree URI, e.g. a document id of
  /// `primary:Music` becomes `Music`.
  String _displayNameFor(String uri) {
    final parsed = Uri.tryParse(uri);
    final segments = parsed?.pathSegments ?? const <String>[];
    if (segments.isEmpty) return 'Folder';
    final docId = segments.last;
    if (docId.isEmpty) return 'Folder';
    final afterColon =
        docId.contains(':') ? docId.substring(docId.indexOf(':') + 1) : docId;
    final name = afterColon.split('/').last;
    return name.isEmpty ? 'Folder' : name;
  }

  /// Lists audio across all registered folders.
  ///
  /// Enumeration is breadth-first and bounded: each folder is read one
  /// directory level at a time, up to [maxDepth] levels and [maxFilesPerFolder]
  /// files. A picked tree can be arbitrarily large, and a scan that never
  /// finishes is worse than one that stops early. Whatever was found is
  /// returned, so the library is always usable.
  Future<List<Track>> scanAll() async {
    final tracks = <Track>[];
    final stillValid = <MusicFolder>[];

    for (final folder in _folders) {
      final hasAccess = await _bridge.hasFolderAccess(folder.uri);
      if (!hasAccess) continue;

      try {
        final found = await _scanFolder(folder);
        tracks.addAll(found.tracks);
        stillValid.add(folder.copyWith(trackCount: found.tracks.length));
      } on TimeoutException {
        // A provider that never answers must not block the whole library.
        // Keep the folder registered so it can be retried or removed.
        debugPrint('scanAll: ${folder.name} timed out, keeping it registered');
        stillValid.add(folder);
      } catch (e) {
        // Folder became unreadable (removed, SD card pulled, ...). Skip it.
        debugPrint('scanAll: skipping ${folder.name}: $e');
      }
    }

    final changed = !_sameFolders(stillValid, _folders);
    _folders = stillValid;
    if (changed) await _persist();

    return tracks;
  }

  Future<_FolderScan> _scanFolder(MusicFolder folder) async {
    final tracks = <Track>[];
    final seen = <String>{};
    var queue = <String>[''];

    for (var depth = 0; depth < maxDepth && queue.isNotEmpty; depth++) {
      final next = <String>[];

      for (final relativeDir in queue) {
        if (tracks.length >= maxFilesPerFolder) break;

        final entries = await _bridge.listAudioIn(
          folder.uri,
          relativeDir: relativeDir,
        );

        for (final entry in entries) {
          if (entry.isDirectory) {
            // Collapse nested directories into one readable label.
            next.add(entry.relativePath);
            continue;
          }
          if (tracks.length >= maxFilesPerFolder) break;
          if (!seen.add(entry.uri)) continue;
          tracks.add(_trackFromFile(entry));
        }
      }

      queue = next;
    }

    return _FolderScan(tracks);
  }

  /// Bounds for a single folder walk, so a huge tree cannot hang the library.
  static const maxDepth = 4;
  static const maxFilesPerFolder = 2000;

  bool _sameFolders(List<MusicFolder> a, List<MusicFolder> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].uri != b[i].uri || a[i].trackCount != b[i].trackCount) {
        return false;
      }
    }
    return true;
  }

  /// Converts a scanned file into a playable track.
  ///
  /// SAF gives us a display name but no tags, so artist/title are parsed from
  /// the filename. Tag reading via ffprobe/ffmpeg can fill these in properly
  /// once the transcode tooling is in place.
  Track _trackFromFile(ScannedFile file) {
    final name = LibraryRepository.stripExtension(file.name);
    final dash = name.indexOf(' - ');
    final title = dash == -1 ? name : name.substring(dash + 3);
    final artist = dash == -1 ? 'Unknown artist' : name.substring(0, dash);

    return Track(
      id: file.uri,
      uri: file.uri,
      title: title,
      artist: artist,
    );
  }
}

class _FolderScan {
  const _FolderScan(this.tracks);

  final List<Track> tracks;
}
