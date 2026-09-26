import 'package:flutter/material.dart';

import '../library/likes_controller.dart';
import '../models/track.dart';
import '../player_controller.dart';
import 'empty_state.dart';
import 'layout.dart';
import 'screen_header.dart';
import 'theme.dart';

/// Library tab: everything the app manages, plus whatever the user has chosen
/// to expose from their own folders.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.controller,
    required this.likes,
  });

  final PlayerController controller;
  final LikesController likes;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: AnimatedBuilder(
        animation: Listenable.merge([controller, likes]),
        builder: (context, _) {
          final tracks = controller.tracks;
          final folderCount = controller.folders.length;

          return Column(
            children: [
              ScreenHeader(
                title: 'Library',
                trailing: _LibraryActions(
                  folderCount: folderCount,
                  isScanning: controller.isScanning,
                  onAddFolder: () => controller.addMusicFolder(),
                ),
              ),
              Expanded(
                child: tracks.isEmpty
                    ? EmptyState(
                        icon: Icons.library_music_outlined,
                        title: 'Nothing here yet',
                        message: folderCount == 0
                            ? 'Add a folder to scan, or search for something '
                                'to download.'
                            : 'No audio found in your folders yet.',
                      )
                    : _TrackList(controller: controller, likes: likes),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LibraryActions extends StatelessWidget {
  const _LibraryActions({
    required this.folderCount,
    required this.isScanning,
    required this.onAddFolder,
  });

  final int folderCount;
  final bool isScanning;
  final Future<void> Function() onAddFolder;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isScanning)
          const Padding(
            padding: EdgeInsets.only(right: 12),
            child: SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: SC.textFaint,
              ),
            ),
          ),
        TextButton.icon(
          onPressed: isScanning ? null : onAddFolder,
          icon: const Icon(Icons.create_new_folder_outlined, size: 18),
          label: Text(folderCount == 0 ? 'Add folder' : 'Folders ($folderCount)'),
          style: TextButton.styleFrom(
            foregroundColor: SC.text,
            textStyle: const TextStyle(fontSize: 13),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
              side: const BorderSide(color: SC.outline),
            ),
          ),
        ),
      ],
    );
  }
}

class _TrackList extends StatelessWidget {
  const _TrackList({required this.controller, required this.likes});

  final PlayerController controller;
  final LikesController likes;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.only(top: 8, bottom: kBottomOverlayInset),
      itemCount: controller.tracks.length,
      separatorBuilder: (_, _) => const Divider(
        height: 1,
        thickness: 1,
        color: SC.outline,
        indent: 76,
      ),
      itemBuilder: (context, index) {
        final track = controller.tracks[index];
        final isCurrent = controller.currentIndex == index;
        return _TrackTile(
          track: track,
          isCurrent: isCurrent,
          isPlaying: isCurrent && controller.playing,
          isLiked: likes.isLiked(track.id),
          onTap: () => controller.playTrackAt(index),
          onToggleLike: () => likes.toggle(track),
        );
      },
    );
  }
}

class _TrackTile extends StatelessWidget {
  const _TrackTile({
    required this.track,
    required this.isCurrent,
    required this.isPlaying,
    required this.isLiked,
    required this.onTap,
    required this.onToggleLike,
  });

  final Track track;
  final bool isCurrent;
  final bool isPlaying;
  final bool isLiked;
  final VoidCallback onTap;
  final VoidCallback onToggleLike;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Row(
          children: [
            SizedBox(
              width: 36,
              height: 36,
              child: isPlaying
                  ? _PlayingBars()
                  : DecoratedBox(
                      decoration: BoxDecoration(
                        color: SC.surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.music_note,
                        size: 18,
                        color: SC.textFaint,
                      ),
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: SC.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    track.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: SC.textMuted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onToggleLike,
              iconSize: 20,
              color: isLiked ? SC.text : SC.textGhost,
              icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border),
              tooltip: isLiked ? 'Remove from Liked' : 'Add to Liked',
            ),
          ],
        ),
      ),
    );
  }
}

/// Tiny animated bars shown on the row that is currently playing.
class _PlayingBars extends StatefulWidget {
  const _PlayingBars();

  @override
  State<_PlayingBars> createState() => _PlayingBarsState();
}

class _PlayingBarsState extends State<_PlayingBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(3, (i) {
            final phase = (_c.value * 3 - i) % 3;
            final height = 8 + 20 * (phase < 2 ? phase : 3 - phase);
            return Container(
              width: 3,
              height: height,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                color: SC.text,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }
}
