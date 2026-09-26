import 'package:flutter/material.dart';

import '../player_controller.dart';
import 'now_playing_screen.dart';

/// Persistent player bar that sits above the navigation bar on every tab.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key, required this.controller});

  final PlayerController controller;

  void _openNowPlaying(BuildContext context) {
    if (controller.currentTrack == null) return;
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (_, _, _) => NowPlayingScreen(controller: controller),
        transitionsBuilder: (_, animation, _, child) {
          return SlideTransition(
            position: Tween(begin: const Offset(0, 1), end: Offset.zero)
                .chain(CurveTween(curve: Curves.easeOutCubic))
                .animate(animation),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final track = controller.currentTrack;
        if (track == null) return const SizedBox.shrink();

        final accent = Theme.of(context).colorScheme.primary;
        final durationMs = controller.duration.inMilliseconds;
        final progress = durationMs == 0
            ? 0.0
            : (controller.position.inMilliseconds / durationMs)
                .clamp(0.0, 1.0);

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _openNowPlaying(context),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 2,
                  backgroundColor: Colors.white10,
                  valueColor: AlwaysStoppedAnimation(accent),
                ),
                Container(
                  margin: const EdgeInsets.fromLTRB(20, 10, 12, 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16161A),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [accent, accent.withValues(alpha: 0.35)],
                          ),
                        ),
                        child: const Icon(
                          Icons.music_note,
                          color: Colors.black87,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              track.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.45),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: controller.togglePlay,
                        icon: Icon(
                          controller.playing ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
