import 'package:flutter_test/flutter_test.dart';
import 'package:sourcecrush/src/models/track.dart';

void main() {
  group('Track', () {
    test('keeps the uri it was given, for either scheme', () {
      const local = Track(
        id: 'file:///data/music/a.mp3',
        uri: 'file:///data/music/a.mp3',
        title: 'A',
      );
      const saf = Track(
        id: 'content://media/tree/audio/1',
        uri: 'content://media/tree/audio/1',
        title: 'B',
      );

      expect(local.parsedUri.scheme, 'file');
      expect(saf.parsedUri.scheme, 'content');
    });

    test('parsedUri round trips the original string', () {
      const uri = 'content://com.android.externalstorage/tree/Music%3A%2FAudio';
      const track = Track(id: uri, uri: uri, title: 'T');
      expect(track.parsedUri.toString(), uri);
    });

    test('exposes the uri to the player via extras', () {
      const track = Track(
        id: 'content://tree/1',
        uri: 'content://tree/1',
        title: 'Song',
        artist: 'Band',
      );
      final item = track.toMediaItem();

      expect(item.id, 'content://tree/1');
      expect(item.title, 'Song');
      expect(item.artist, 'Band');
      expect(item.extras?['uri'], 'content://tree/1');
    });

    test('covers the common audio extensions', () {
      for (final ext in ['mp3', 'flac', 'm4a', 'opus', 'wav', 'aac']) {
        expect(Track.supportedExtensions, contains(ext));
      }
    });
  });
}
