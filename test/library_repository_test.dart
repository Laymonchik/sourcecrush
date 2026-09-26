import 'package:flutter_test/flutter_test.dart';
import 'package:sourcecrush/src/library/library_repository.dart';

void main() {
  group('LibraryRepository filename parsing', () {
    test('splits "Artist - Title"', () {
      const name = 'Rick Astley - Never Gonna Give You Up.mp3';
      expect(LibraryRepository.artistFromFileName(name), 'Rick Astley');
      expect(
        LibraryRepository.titleFromFileName(name),
        "Never Gonna Give You Up",
      );
    });

    test('falls back to the whole stem when there is no artist', () {
      expect(LibraryRepository.artistFromFileName('field-recording.wav'),
          'Unknown artist');
      expect(LibraryRepository.titleFromFileName('field-recording.wav'),
          'field-recording');
    });

    test('only splits on the first " - "', () {
      expect(
        LibraryRepository.titleFromFileName('a - b - c.flac'),
        'b - c',
      );
      expect(LibraryRepository.artistFromFileName('a - b - c.flac'), 'a');
    });

    test('handles files without an extension', () {
      expect(LibraryRepository.stripExtension('no-extension'), 'no-extension');
    });
  });
}
