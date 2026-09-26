import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart' show LoopMode;

import 'audio/sourcecrush_audio_handler.dart';import 'library/library_repository.dart';
import 'models/track.dart';

/// UI-facing facade over [SourcecrushAudioHandler] and the library on disk.
///
/// Everything the widgets need to render lives here as a [ChangeNotifier] so
/// the UI can stay dumb: it reads fields and calls intent methods.
class PlayerController extends ChangeNotifier {
  PlayerController(this._handler, {LibraryRepository? repository})
      : _repository = repository ?? const LibraryRepository();

  final SourcecrushAudioHandler _handler;
  final LibraryRepository _repository;

  List<Track> _tracks = const [];
  List<Track> get tracks => _tracks;
  bool get hasTracks => _tracks.isEmpty == false;

  /// Paths currently loaded into the audio handler's queue, so we only reload
  /// the player when the library on disk actually changed.
  List<String> _loadedPaths = const [];

  int? _index;
  int? get currentIndex => _index;

  Track? get currentTrack {
    if (_index == null || _index! >= _tracks.length) return null;
    return _tracks[_index!];
  }

  bool get playing => _handler.playing;

  LoopMode get loopMode => _handler.loopMode;
  bool get repeatEnabled => _handler.loopMode != LoopMode.off;
  bool get repeatOne => _handler.loopMode == LoopMode.one;
  bool get shuffleEnabled => _handler.shuffleEnabled;

  Future<void> cycleRepeat() => _handler.cycleRepeat();

  Future<void> toggleShuffle() => _handler.toggleShuffle();

  Duration _position = Duration.zero;
  Duration get position => _position;

  Duration get duration => _handler.duration ?? Duration.zero;

  /// Re-scans the music directory. Safe to call on every resume.
  Future<void> refreshLibrary() async {
    _tracks = await _repository.scan();
    notifyListeners();
    await _ensureQueueLoaded();
  }

  Future<void> playTrackAt(int index) async {
    if (index < 0 || index >= _tracks.length) return;
    await _ensureQueueLoaded();
    _index = index;
    notifyListeners();
    await _handler.playTrackAt(index);
  }

  Future<void> togglePlay() => _handler.togglePlay();

  Future<void> next() => _handler.skipToNext();

  Future<void> previous() => _handler.skipToPrevious();

  Future<void> seek(Duration position) => _handler.seek(position);

  Future<void> seekBy(Duration offset) => _handler.seekBy(offset);

  /// Wires up position/index/playing streams. Call once after construction.
  void attach() {
    _handler.positionStream.listen((value) {
      _position = value;
      notifyListeners();
    });
    _handler.playerStateStream.listen((state) {
      notifyListeners();
    });
    _handler.loopModeStream.listen((_) => notifyListeners());
    _handler.shuffleModeStream.listen((_) => notifyListeners());
    // Keeps the highlighted row in sync when a track ends on its own.
    _handler.currentIndexStream.listen((newIndex) {
      if (newIndex == _index) return;
      _index = newIndex;
      _position = Duration.zero;
      notifyListeners();
    });
  }

  /// Pushes the library into the audio handler when it is out of date.
  ///
  /// Loading is lazy (nothing is decoded until playback starts), so this is
  /// cheap, but it has to happen before any transport control can work.
  Future<void> _ensureQueueLoaded() async {
    final paths = _tracks.map((t) => t.path).toList();
    if (listEquals(paths, _loadedPaths)) return;

    // Reloading mid-playback would interrupt the current track, so the new
    // queue is picked up the next time playback starts instead.
    if (_handler.playing) return;

    final keepIndex = (_index ?? 0).clamp(0, paths.isEmpty ? 0 : paths.length - 1);
    await _handler.loadTracks(_tracks, initialIndex: keepIndex, autoPlay: false);
    _loadedPaths = paths;
  }
}
