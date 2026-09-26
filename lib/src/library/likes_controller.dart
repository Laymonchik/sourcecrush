import 'package:flutter/foundation.dart';

import '../models/track.dart';
import 'likes_repository.dart';

/// Holds which tracks are hearted and persists the set on every change.
class LikesController extends ChangeNotifier {
  LikesController({LikesRepository? repository})
      : _repository = repository ?? const LikesRepository();

  final LikesRepository _repository;

  List<LikedTrack> _liked = const [];
  List<LikedTrack> get liked => _liked;

  bool get isEmpty => _liked.isEmpty;
  int get count => _liked.length;

  /// Loads the persisted set. Call once during startup.
  Future<void> load() async {
    _liked = await _repository.load();
    notifyListeners();
  }

  bool isLiked(String trackId) => _liked.any((t) => t.id == trackId);

  /// Adds or removes a track, then writes the new set to disk.
  Future<void> toggle(Track track) async {
    if (isLiked(track.id)) {
      _liked = [
        for (final t in _liked)
          if (t.id != track.id) t,
      ];
    } else {
      _liked = [LikesRepository.fromTrack(track), ..._liked];
    }
    notifyListeners();
    await _repository.save(_liked);
  }

  Future<void> remove(String trackId) async {
    if (!isLiked(trackId)) return;
    _liked = [
      for (final t in _liked)
        if (t.id != trackId) t,
    ];
    notifyListeners();
    await _repository.save(_liked);
  }

  /// Drops likes whose file is no longer in the library.
  ///
  /// Only safe to call once a library scan has actually completed: pruning
  /// against a partial scan would discard likes for files that merely had not
  /// been enumerated yet.
  Future<void> prune(Set<String> existingIds) async {
    final before = _liked.length;
    _liked = [
      for (final t in _liked)
        if (existingIds.contains(t.id)) t,
    ];
    if (_liked.length == before) return;
    notifyListeners();
    await _repository.save(_liked);
  }
}
