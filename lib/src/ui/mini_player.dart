import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/track.dart';
import '../player_controller.dart';
import 'marquee_text.dart';
import 'now_playing_screen.dart';
import 'theme.dart';

/// Floating "now playing" pill.
///
/// It is drawn on top of the page rather than in a reserved slot, so content
/// scrolls underneath it. The background is a blurred, translucent panel so the
/// content still reads through, and long titles scroll instead of truncating.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key, required this.controller});

  final PlayerController controller;

  static const _radius = BorderRadius.all(Radius.circular(999));

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

        final durationMs = controller.duration.inMilliseconds;
        final progress = durationMs == 0
            ? 0.0
            : (controller.position.inMilliseconds / durationMs)
                .clamp(0.0, 1.0);

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: ClipRRect(
            borderRadius: _radius,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                decoration: BoxDecoration(
                  // Translucent so whatever is underneath stays visible.
                  color: SC.surfaceHigh.withValues(alpha: 0.72),
                  borderRadius: _radius,
                  border: Border.all(color: SC.outline),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Progress runs along the very top edge of the pill.
                    SizedBox(
                      height: 2,
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.transparent,
                        valueColor: const AlwaysStoppedAnimation(SC.text),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                      child: Row(
                        children: [
                          // Artwork and text open the full player; the
                          // transport buttons handle their own taps. The
                          // scrollable text is the only flexible child of this
                          // row, which is what keeps the marquee bounded.
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _openNowPlaying(context),
                            child: _Artwork(track: track),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _openNowPlaying(context),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  MarqueeText(
                                    text: track.title,
                                    style: const TextStyle(
                                      color: SC.text,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      height: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  // The artist stays put: only the title
                                  // scrolls, matching the reference player.
                                  Text(
                                    track.artist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: SC.textMuted,
                                      fontSize: 12,
                                      height: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _RoundButton(
                            iconSize: 20,
                            onPressed: controller.previous,
                            child: const Icon(
                              Icons.skip_previous,
                              color: SC.text,
                            ),
                          ),
                          const SizedBox(width: 6),
                          _RoundButton(
                            iconSize: 26,
                            size: 46,
                            emphasised: true,
                            onPressed: controller.togglePlay,
                            child: Icon(
                              controller.playing ? Icons.pause : Icons.play_arrow,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(width: 6),
                          _RoundButton(
                            iconSize: 20,
                            onPressed: controller.next,
                            child: const Icon(Icons.skip_next, color: SC.text),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Circular album art. Falls back to a grey placeholder until real cover art is
/// available from the download pipeline.
class _Artwork extends StatelessWidget {
  const _Artwork({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context) {
    final artUri = track.artUri;
    final isLocalFile = artUri != null && artUri.scheme == 'file';
    final hasNetworkArt = artUri != null && artUri.scheme == 'http';

    Widget child = const Icon(
      Icons.music_note,
      color: Color(0xB3FFFFFF),
      size: 20,
    );

    if (isLocalFile) {
      child = Image.file(
        File(artUri.toFilePath()),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => child,
      );
    } else if (hasNetworkArt) {
      child = Image.network(
        artUri.toString(),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => child,
      );
    }

    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: SC.artworkGradient,
        border: Border.all(color: SC.outline),
      ),
      child: ClipOval(child: child),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.child,
    required this.onPressed,
    required this.iconSize,
    this.size = 40,
    this.emphasised = false,
  });

  final Widget child;
  final VoidCallback onPressed;
  final double iconSize;
  final double size;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Material(
        color: emphasised ? SC.text : SC.surfaceHigh,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Center(
            child: IconTheme(data: IconThemeData(size: iconSize), child: child),
          ),
        ),
      ),
    );
  }
}
