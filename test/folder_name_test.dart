import 'package:flutter_test/flutter_test.dart';
import 'package:sourcecrush/src/library/native_bridge.dart';

void main() {
  group('MusicFolder', () {
    test('round trips through JSON', () {
      const folder = MusicFolder(
        uri: 'content://tree/primary%3AMusic',
        name: 'Music',
        trackCount: 12,
      );

      // trackCount is derived from a scan, so it is not persisted.
      final json = folder.toJson();
      expect(json.containsKey('trackCount'), isFalse);

      final restored = MusicFolder.fromJson(json);
      expect(restored.uri, folder.uri);
      expect(restored.name, 'Music');
      expect(restored.trackCount, 0);
    });

    test('copyWith replaces only the count', () {
      const folder = MusicFolder(uri: 'content://tree/x', name: 'X');
      final updated = folder.copyWith(trackCount: 7);

      expect(updated.trackCount, 7);
      expect(updated.uri, folder.uri);
      expect(updated.name, folder.name);
    });
  });

  group('SAF file parsing', () {
    test('a scanned file keeps its content uri', () {
      const file = ScannedFile(
        uri: 'content://tree/primary%3AMusic/document%3A12',
        name: 'Artist - Song.mp3',
        relativePath: 'Artist - Song.mp3',
        sizeBytes: 4096,
      );

      expect(file.uri.startsWith('content://'), isTrue);
      expect(file.relativePath, isNot(contains('/')));
    });

    test('a nested file keeps its relative path', () {
      const file = ScannedFile(
        uri: 'content://tree/primary%3AMusic/document%3A99',
        name: 'Song.flac',
        relativePath: 'Rock/Song.flac',
      );

      expect(file.relativePath, 'Rock/Song.flac');
    });

    test('directories are flagged so the caller can expand them', () {
      const dir = ScannedFile(
        uri: 'content://tree/primary%3AMusic/document%3A7',
        name: 'Rock',
        relativePath: 'Rock',
        isDirectory: true,
      );

      expect(dir.isDirectory, isTrue);
    });

    test('files default to not being directories', () {
      const file = ScannedFile(
        uri: 'content://tree/1',
        name: 'a.mp3',
        relativePath: 'a.mp3',
      );

      expect(file.isDirectory, isFalse);
    });

    test('asFile only accepts file:// uris', () {
      expect(NativeBridge.asFile('content://tree/1'), isNull);
      expect(NativeBridge.asFile('not a uri'), isNull);
    });
  });
}
