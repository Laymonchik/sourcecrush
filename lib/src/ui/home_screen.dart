import 'package:flutter/material.dart';

import '../player_controller.dart';
import 'empty_state.dart';
import 'screen_header.dart';

/// Library tab: everything currently in the app's music directory.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.controller});

  final PlayerController controller;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final tracks = controller.tracks;
          return Column(
            children: [
              const ScreenHeader(title: 'Library'),
              Expanded(
                child: tracks.isEmpty
                    ? const EmptyState(
                        icon: Icons.library_music_outlined,
                        title: 'Nothing here yet',
                        message: 'Tracks you download will show up here.',
                      )
                    : _TrackList(controller: controller),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TrackList extends StatelessWidget {
  const _TrackList({required this.controller});

  final PlayerController controller;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      itemCount: controller.tracks.length,
      separatorBuilder: (_, _) => const Divider(
        height: 1,
        thickness: 1,
        color: Color(0x14FFFFFF),
        indent: 76,
      ),
      itemBuilder: (context, index) {
        final track = controller.tracks[index];
        final isCurrent = controller.currentIndex == index;
        return _TrackTile(
          title: track.title,
          artist: track.artist,
          isCurrent: isCurrent,
          isPlaying: isCurrent && controller.playing,
          onTap: () => controller.playTrackAt(index),
        );
      },
    );
  }
}

class _TrackTile extends StatelessWidget {
  const _TrackTile({
    required this.title,
    required this.artist,
    required this.isCurrent,
    required this.isPlaying,
    required this.onTap,
  });

  final String title;
  final String artist;
  final bool isCurrent;
  final bool isPlaying;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

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
                  ? _PlayingBars(color: accent)
                  : DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.music_note,
                        size: 18,
                        color: Colors.white38,
                      ),
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isCurrent ? accent : Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onTap,
              iconSize: 20,
              color: Colors.white.withValues(alpha: 0.3),
              icon: const Icon(Icons.favorite_border),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tiny animated bars shown on the row that is currently playing.
class _PlayingBars extends StatefulWidget {
  const _PlayingBars({required this.color});

  final Color color;

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
                color: widget.color,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }
}
