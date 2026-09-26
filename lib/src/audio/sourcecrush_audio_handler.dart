import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import '../models/track.dart';

/// Owns the single [AudioPlayer] instance and mirrors its state into
/// audio_service's subjects so the notification, lock screen and headset
/// buttons all stay in sync with the UI.
class SourcecrushAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  SourcecrushAudioHandler() {
    _player.playbackEventStream.listen((_) => _broadcastState());
    _player.sequenceStateStream.listen(_onSequenceState);
  }
  final AudioPlayer _player = AudioPlayer();

  /// Exposed so the UI can observe playback state without a second player.
  AudioPlayer get player => _player;

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<int?> get currentIndexStream => _player.currentIndexStream;
  Duration? get duration => _player.duration;

  int? _currentIndex;
  int? get currentIndex => _currentIndex;

  bool get playing => _player.playing;

  /// Replaces the queue with [tracks] and starts at [initialIndex].
  Future<void> loadTracks(
    List<Track> tracks, {
    int initialIndex = 0,
    bool autoPlay = true,
  }) async {
    if (tracks.isEmpty) {
      queue.add(const <MediaItem>[]);
      mediaItem.add(null);
      await _player.stop();
      return;
    }

    queue.add(tracks.map((t) => t.toMediaItem()).toList());
    final index = initialIndex.clamp(0, tracks.length - 1);

    await _player.setAudioSources(
      tracks
          .map(
            // AudioSource.uri handles both file:// (app downloads) and
            // content:// (user-picked folders) URIs.
            (t) => AudioSource.uri(t.parsedUri, tag: t.toMediaItem()),
          )
          .toList(),
      initialIndex: index,
      initialPosition: Duration.zero,
      // Only prepare the first track; the rest load as they come up.
      preload: false,
    );

    _currentIndex = index;
    _syncMediaItem();

    if (autoPlay) await play();
  }

  Future<void> togglePlay() => playing ? pause() : play();

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> skipToNext() => _player.seekToNext();

  @override
  Future<void> skipToPrevious() => _player.seekToPrevious();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  Future<void> seekBy(Duration offset) =>
      _player.seek(_player.position + offset);

  Stream<LoopMode> get loopModeStream => _player.loopModeStream;
  Stream<bool> get shuffleModeStream => _player.shuffleModeEnabledStream;
  LoopMode get loopMode => _player.loopMode;
  bool get shuffleEnabled => _player.shuffleModeEnabled;

  /// Cycles repeat: off -> all -> single track -> off.
  Future<void> cycleRepeat() async {
    final next = switch (_player.loopMode) {
      LoopMode.off => LoopMode.all,
      LoopMode.all => LoopMode.one,
      LoopMode.one => LoopMode.off,
    };
    await _player.setLoopMode(next);
  }

  Future<void> toggleShuffle() =>
      _player.setShuffleModeEnabled(!_player.shuffleModeEnabled);

  /// Called by the UI when a specific row is tapped.
  Future<void> playTrackAt(int index) async {
    if (index < 0 || index >= queue.value.length) return;

    if (index == _currentIndex) {
      await _player.seek(Duration.zero);
      if (!playing) await play();
      return;
    }

    await _player.seek(Duration.zero, index: index);
    await play();
  }

  void _onSequenceState(SequenceState state) {
    final index = state.currentIndex;
    if (index == _currentIndex) return;
    _currentIndex = index;
    _syncMediaItem();
    _broadcastState();
  }

  /// Publishes the current item (title/artist/duration) for the notification.
  void _syncMediaItem() {
    final tag = _player.sequenceState.currentSource?.tag;
    if (tag is! MediaItem) return;
    final duration = _player.duration;
    mediaItem.add(
      duration == null ? tag : tag.copyWith(duration: duration),
    );
  }

  /// Pushes just_audio state into audio_service's [playbackState].
  void _broadcastState() {
    final isPlaying = _player.playing;
    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (isPlaying) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.stop,
        ],
        systemActions: const {MediaAction.seek},
        // Which controls survive in the collapsed notification.
        androidCompactActionIndices: const [0, 1, 2],
        processingState: switch (_player.processingState) {
          ProcessingState.idle => AudioProcessingState.idle,
          ProcessingState.loading => AudioProcessingState.loading,
          ProcessingState.buffering => AudioProcessingState.buffering,
          ProcessingState.ready => AudioProcessingState.ready,
          ProcessingState.completed => AudioProcessingState.completed,
        },
        playing: isPlaying,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        queueIndex: _currentIndex,
        speed: _player.speed,
      ),
    );
  }
}
