import 'package:flutter/material.dart';

import '../library/likes_controller.dart';
import '../library/likes_repository.dart';
import '../player_controller.dart';
import 'empty_state.dart';
import 'layout.dart';
import 'screen_header.dart';
import 'theme.dart';

/// Liked songs tab. Reads straight from [LikesController], which persists the
/// hearted set to disk.
class LikedScreen extends StatelessWidget {
  const LikedScreen({
    super.key,
    required this.likes,
    required this.player,
  });

  final LikesController likes;
  final PlayerController player;

  Future<void> _play(BuildContext context, LikedTrack track) async {
    final ok = await player.playTrackById(track.id);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${track.title}" is no longer in your library'),
          backgroundColor: SC.surfaceHigh,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: AnimatedBuilder(
        animation: Listenable.merge([likes, player]),
        builder: (context, _) {
          final items = likes.liked;
          return Column(
            children: [
              ScreenHeader(
                title: 'Liked',
                trailing: items.isEmpty
                    ? null
                    : Text(
                        '${items.length}',
                        style: const TextStyle(
                          color: SC.textFaint,
                          fontSize: 15,
                        ),
                      ),
              ),
              Expanded(
                child: items.isEmpty
                    ? const EmptyState(
                        icon: Icons.favorite_border,
                        title: 'No likes yet',
                        message: 'Tap the heart on any track and it lands here.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.only(
                          top: 8,
                          bottom: kBottomOverlayInset,
                        ),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const Divider(
                          height: 1,
                          thickness: 1,
                          color: SC.outline,
                          indent: 76,
                        ),
                        itemBuilder: (context, index) {
                          final track = items[index];
                          final isCurrent =
                              player.currentTrack?.id == track.id;
                          return _LikedTile(
                            title: track.title,
                            artist: track.artist,
                            isCurrent: isCurrent,
                            isPlaying: isCurrent && player.playing,
                            onTap: () => _play(context, track),
                            onUnlike: () => likes.remove(track.id),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LikedTile extends StatelessWidget {
  const _LikedTile({
    required this.title,
    required this.artist,
    required this.isCurrent,
    required this.isPlaying,
    required this.onTap,
    required this.onUnlike,
  });

  final String title;
  final String artist;
  final bool isCurrent;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback onUnlike;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      leading: SizedBox(
        width: 36,
        height: 36,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: SC.surface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isPlaying ? Icons.graphic_eq : Icons.favorite,
            size: 18,
            color: isPlaying ? SC.text : SC.textFaint,
          ),
        ),
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isCurrent ? SC.text : SC.text,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        artist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: SC.textMuted, fontSize: 13),
      ),
      trailing: IconButton(
        onPressed: onUnlike,
        iconSize: 20,
        color: SC.textFaint,
        icon: const Icon(Icons.favorite),
        tooltip: 'Remove from Liked',
      ),
    );
  }
}
