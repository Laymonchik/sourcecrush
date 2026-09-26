import 'package:audio_service/audio_service.dart';

/// A single playable item in the library.
///
/// Tracks come from three places, all of which resolve to a URI rather than a
/// filesystem path:
///
///  * the app's own `music` directory, where the yt-dlp/ffmpeg pipeline writes
///    (`file://` URIs),
///  * folders the user granted through the system picker (`content://` URIs),
///  * and later, streamed sources.
class Track {
  const Track({
    required this.id,
    required this.uri,
    required this.title,
    this.artist = 'Unknown artist',
    this.album,
    this.duration,
    this.artUri,
  });

  final String id;

  /// `file://` or `content://` URI. just_audio plays both through ExoPlayer.
  final String uri;

  final String title;
  final String artist;
  final String? album;
  final Duration? duration;
  final Uri? artUri;

  /// Convenience for callers that want the parsed URI.
  Uri get parsedUri => Uri.parse(uri);

  /// Audio formats ExoPlayer can decode without help from ffmpeg.
  static const supportedExtensions = <String>{
    'mp3', 'm4a', 'aac', 'flac', 'wav', 'ogg', 'opus', 'oga',
    'webm', 'mp4', 'mka', 'wma', 'aiff', 'aif', 'ape', 'wv', 'tta',
  };

  MediaItem toMediaItem() => MediaItem(
        id: id,
        title: title,
        artist: artist,
        album: album,
        duration: duration,
        artUri: artUri,
        extras: {'uri': uri},
      );

  @override
  String toString() => 'Track($title - $artist)';
}
