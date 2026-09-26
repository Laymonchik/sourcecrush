import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

import '../models/track.dart';

/// Discovers playable files on disk.
///
/// Everything the app downloads (via yt-dlp + ffmpeg) and everything the user
/// imports ends up under `<app documents>/music`, so that is the single source
/// of truth for now. Reading the system MediaStore library can be layered on
/// later without changing the player.
class LibraryRepository {
  const LibraryRepository();

  static const _musicDirName = 'music';

  /// Directory that holds all audio the app manages. Created on demand.
  Future<Directory> musicDirectory() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/$_musicDirName');
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  /// Scans [musicDirectory] for supported audio files.
  ///
  /// Filenames are parsed for a `Artist - Title` shape, which is the naming
  /// convention the download pipeline will use. Once real tags are available
  /// (via ffprobe) this gets replaced by tag data.
  Future<List<Track>> scan() async {
    final dir = await musicDirectory();

    final files = dir
        .listSync(recursive: true, followLinks: false)
        .whereType<File>()
        .where((f) {
          final ext = f.path.split('.').last.toLowerCase();
          return Track.supportedExtensions.contains(ext);
        })
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    return [
      for (final file in files)
        Track(
          id: file.path,
          path: file.path,
          title: titleFromFileName(file.uri.pathSegments.last),
          artist: artistFromFileName(file.uri.pathSegments.last),
        ),
    ];
  }

  /// "Rick Astley - Never Gonna Give You Up.mp3" -> "Never Gonna Give You Up"
  static String titleFromFileName(String fileName) {
    final stem = stripExtension(fileName);
    final dash = stem.indexOf(' - ');
    return dash == -1 ? stem : stem.substring(dash + 3);
  }

  /// "Rick Astley - Never Gonna Give You Up.mp3" -> "Rick Astley"
  static String artistFromFileName(String fileName) {
    final stem = stripExtension(fileName);
    final dash = stem.indexOf(' - ');
    return dash == -1 ? 'Unknown artist' : stem.substring(0, dash);
  }

  static String stripExtension(String fileName) {
    final dot = fileName.lastIndexOf('.');
    return dot <= 0 ? fileName : fileName.substring(0, dot);
  }

  /// Debug-only: copies the bundled demo clips into the music directory.
  ///
  /// This mirrors what the yt-dlp pipeline does (write a file into the music
  /// directory, then rescan), so playback gets exercised end to end before any
  /// of the download machinery exists.
  Future<void> seedDemoTracks() async {
    const demoFiles = [
      'assets/demo/Test Artist - First Track.mp3',
      'assets/demo/Test Artist - Second Track.mp3',
      'assets/demo/Another One - Third Track.flac',
    ];

    final dir = await musicDirectory();
    for (final assetPath in demoFiles) {
      final fileName = assetPath.split('/').last;
      final target = File('${dir.path}/$fileName');
      if (target.existsSync()) continue;
      final data = await rootBundle.load(assetPath);
      await target.writeAsBytes(data.buffer.asUint8List(), flush: true);
    }
  }
}
