import 'package:audio_service/audio_service.dart';

/// A single playable item in the library.
///
/// Right now tracks come from files in the app's own music directory, which is
/// also where the yt-dlp/ffmpeg pipeline will write to later on.
class Track {
  const Track({
    required this.id,
    required this.path,
    required this.title,
    this.artist = 'Unknown artist',
    this.album,
    this.duration,
    this.artUri,
  });

  final String id;
  final String path;
  final String title;
  final String artist;
  final String? album;
  final Duration? duration;
  final Uri? artUri;

  /// Audio formats ExoPlayer/just_audio can decode without ffmpeg help.
  static const supportedExtensions = <String>{
    'mp3', 'm4a', 'aac', 'flac', 'wav', 'ogg', 'opus', 'oga', 'webm', 'mp4', 'mka',
  };

  MediaItem toMediaItem() => MediaItem(
        id: id,
        title: title,
        artist: artist,
        album: album,
        duration: duration,
        artUri: artUri,
        extras: {'path': path},
      );

  @override
  String toString() => 'Track($title - $artist)';
}
