import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart' show LoopMode;

import 'audio/sourcecrush_audio_handler.dart';
import 'library/library_repository.dart';
import 'library/music_folder_repository.dart';
import 'library/native_bridge.dart';
import 'models/track.dart';

/// UI-facing facade over [SourcecrushAudioHandler] and the library sources.
///
/// Everything the widgets need to render lives here as a [ChangeNotifier] so
/// the UI can stay dumb: it reads fields and calls intent methods.
class PlayerController extends ChangeNotifier {
  PlayerController(
    this._handler, {
    LibraryRepository? repository,
    MusicFolderRepository? folderRepository,
  })  : _repository = repository ?? const LibraryRepository(),
        _folders = folderRepository ?? MusicFolderRepository();

  final SourcecrushAudioHandler _handler;
  final LibraryRepository _repository;
  final MusicFolderRepository _folders;

  List<Track> _tracks = const [];
  List<Track> get tracks => _tracks;
  bool get hasTracks => _tracks.isEmpty == false;

  /// URIs currently loaded into the audio handler's queue, so the player is
  /// only reloaded when the library actually changed.
  List<String> _loadedUris = const [];

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

  /// Folders the user has chosen to scan.
  List<MusicFolder> get folders => _folders.folders;

  bool _scanning = false;
  bool get isScanning => _scanning;

  /// Re-reads every source: the app's music directory plus each folder the
  /// user granted. Safe to call on resume.
  Future<void> refreshLibrary() async {
    if (_scanning) return;
    _scanning = true;
    notifyListeners();
    try {
      final downloaded = await _repository.scan();
      final fromFolders = await _folders.scanAll();

      // Downloads first (they are the app's own files), then folder tracks.
      _tracks = [...downloaded, ...fromFolders];
      notifyListeners();
      await _ensureQueueLoaded();
    } finally {
      _scanning = false;
      notifyListeners();
    }
  }

  /// Prompts for a folder and adds it to the scan set.
  ///
  /// Returns true when a new folder was registered.
  Future<bool> addMusicFolder() async {
    final folder = await _folders.addFolder();
    if (folder == null) return false;
    await refreshLibrary();
    return true;
  }

  Future<void> removeMusicFolder(String uri) async {
    await _folders.removeFolder(uri);
    await refreshLibrary();
  }

  Future<void> playTrackAt(int index) async {
    if (index < 0 || index >= _tracks.length) return;
    await _ensureQueueLoaded();
    _index = index;
    _position = Duration.zero;
    notifyListeners();
    await _handler.playTrackAt(index);
  }

  /// Plays a liked track by looking it up in the current library.
  ///
  /// Returns false when the file is no longer present.
  Future<bool> playTrackById(String id) async {
    final index = _tracks.indexWhere((t) => t.id == id);
    if (index == -1) return false;
    await playTrackAt(index);
    return true;
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
    final uris = _tracks.map((t) => t.uri).toList();
    if (listEquals(uris, _loadedUris)) return;

    // Reloading mid-playback would interrupt the current track, so the new
    // queue is picked up the next time playback starts instead.
    if (_handler.playing) return;

    final keepIndex =
        (_index ?? 0).clamp(0, uris.isEmpty ? 0 : uris.length - 1);
    await _handler.loadTracks(_tracks, initialIndex: keepIndex, autoPlay: false);
    _loadedUris = uris;
  }
}
