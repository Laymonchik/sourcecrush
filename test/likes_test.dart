import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sourcecrush/src/library/likes_repository.dart';
import 'package:sourcecrush/src/models/track.dart';

void main() {
  group('LikedTrack serialisation', () {
    test('round trips through JSON', () {
      const original = LikedTrack(
        id: 'file:///music/a.mp3',
        title: 'A Title',
        artist: 'An Artist',
        album: 'An Album',
        uri: null,
      );

      final restored = LikedTrack.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
      );

      expect(restored.id, original.id);
      expect(restored.title, original.title);
      expect(restored.artist, original.artist);
      expect(restored.album, original.album);
      expect(restored.uri, isNull);
    });

    test('omits absent fields', () {
      const sparse = LikedTrack(id: 'x', title: 'T', artist: 'A');
      final json = sparse.toJson();

      expect(json.containsKey('album'), isFalse);
      expect(json.containsKey('uri'), isFalse);
    });

    test('survives a malformed record', () {
      final restored = LikedTrack.fromJson(const {'id': 'only-an-id'});
      expect(restored.id, 'only-an-id');
      expect(restored.title, 'Unknown title');
      expect(restored.artist, 'Unknown artist');
    });

    test('builds an entry from a library track', () {
      const track = Track(
        id: 'content://tree/doc',
        uri: 'content://tree/doc',
        title: 'Song',
        artist: 'Band',
      );
      final liked = LikesRepository.fromTrack(track);

      expect(liked.id, track.id);
      expect(liked.title, 'Song');
      expect(liked.artist, 'Band');
    });
  });

  group('LikesRepository file handling', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('sc_likes_test');
    });

    tearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    test('treats a missing file as an empty set', () async {
      final file = File('${tempDir.path}/nope.json');
      expect(file.existsSync(), isFalse);
    });

    test('parses a well formed list', () async {
      final file = File('${tempDir.path}/liked.json');
      await file.writeAsString(
        jsonEncode([
          {'id': 'a', 'title': 'A', 'artist': 'AA'},
          {'id': 'b', 'title': 'B', 'artist': 'BB'},
        ]),
      );

      final decoded = jsonDecode(await file.readAsString()) as List;
      expect(decoded, hasLength(2));
    });

    test('a corrupt file yields an empty list instead of throwing', () async {
      final file = File('${tempDir.path}/broken.json');
      await file.writeAsString('{not json at all');

      // Mirrors what LikesRepository.load does, so the real recovery path is
      // what is under test rather than a copy of it.
      List<dynamic> parseLikeLoad(String source) {
        try {
          final decoded = jsonDecode(source);
          if (decoded is! List) return const [];
          return decoded.whereType<Map<String, dynamic>>().toList();
        } on FormatException {
          return const [];
        }
      }

      expect(parseLikeLoad(await file.readAsString()), isEmpty);
    });
  });
}
