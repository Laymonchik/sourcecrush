import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/track.dart';

/// A track the user has hearted.
///
/// A snapshot of the metadata is stored alongside the reference so the Liked
/// tab still renders sensibly if the file later goes missing.
class LikedTrack {
  const LikedTrack({
    required this.id,
    required this.title,
    required this.artist,
    this.album,
    this.uri,
  });

  final String id;
  final String title;
  final String artist;
  final String? album;
  final Uri? uri;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        if (album != null) 'album': album,
        if (uri != null) 'uri': uri.toString(),
      };

  static LikedTrack fromJson(Map<String, dynamic> json) => LikedTrack(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? 'Unknown title',
        artist: json['artist'] as String? ?? 'Unknown artist',
        album: json['album'] as String?,
        uri: json['uri'] == null ? null : Uri.tryParse(json['uri'] as String),
      );
}

/// Persists hearted tracks as a small JSON file in the app's support
/// directory.
///
/// A plain file is plenty at this scale: the set is tiny, human readable, and
/// avoids pulling in a database for a handful of rows.
class LikesRepository {
  const LikesRepository();

  static const _fileName = 'liked_tracks.json';

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_fileName');
  }

  /// Loads hearted tracks, newest first. A corrupt file is treated as empty
  /// rather than crashing the app on launch.
  Future<List<LikedTrack>> load() async {
    final file = await _file();
    if (!file.existsSync()) return const [];
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(LikedTrack.fromJson)
          .toList();
    } on FormatException {
      return const [];
    }
  }

  Future<void> save(List<LikedTrack> tracks) async {
    final file = await _file();
    await file.writeAsString(
      jsonEncode([for (final t in tracks) t.toJson()]),
      flush: true,
    );
  }

  /// Builds a like entry from a library track.
  static LikedTrack fromTrack(Track track) => LikedTrack(
        id: track.id,
        title: track.title,
        artist: track.artist,
        album: track.album,
        uri: track.artUri,
      );
}
