import 'package:flutter/material.dart';

import '../player_controller.dart';
import 'theme.dart';

/// Full screen player: artwork, seek bar, transport controls.
class NowPlayingScreen extends StatelessWidget {
  const NowPlayingScreen({super.key, required this.controller});

  final PlayerController controller;

  String _format(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final track = controller.currentTrack;
          if (track == null) {
            return const Center(
              child: Text('Nothing playing', style: TextStyle(color: Colors.white38)),
            );
          }

          final duration = controller.duration;
          final maxMs = duration.inMilliseconds
              .toDouble()
              .clamp(1, double.infinity)
              .toDouble();
          // Android draws this app edge to edge, so the transport row has to
          // clear the gesture/navigation bar itself.
          final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

          return SafeArea(
            child: Column(
              children: [
                _TopBar(onClose: () => Navigator.of(context).maybePop()),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: 24),
                        const _Artwork(),
                        const SizedBox(height: 40),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Column(
                            children: [
                              Text(
                                track.title,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                track.artist,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.55),
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _SeekBar(
                  controller: controller,
                  maxMs: maxMs,
                  format: _format,
                ),
                _TransportControls(controller: controller),
                SizedBox(height: bottomInset + 20),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 30),
          ),
          const Spacer(),
          const Text(
            'NOW PLAYING',
            style: TextStyle(
              color: Colors.white30,
              fontSize: 11,
              letterSpacing: 2.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _Artwork extends StatelessWidget {
  const _Artwork();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      height: 260,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: SC.artworkGradient,
        border: Border.all(color: SC.outline),
      ),
      child: const Icon(Icons.music_note, size: 84, color: Color(0x1FFFFFFF)),
    );
  }
}

class _SeekBar extends StatelessWidget {
  const _SeekBar({
    required this.controller,
    required this.maxMs,
    required this.format,
  });

  final PlayerController controller;
  final double maxMs;
  final String Function(Duration) format;

  @override
  Widget build(BuildContext context) {
    final positionMs = controller.position.inMilliseconds
        .toDouble()
        .clamp(0.0, maxMs)
        .toDouble();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              activeTrackColor: SC.text,
              inactiveTrackColor: SC.outline,
              thumbColor: SC.text,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            ),
            child: Slider(
              value: positionMs,
              max: maxMs,
              onChanged: (value) {
                controller.seek(Duration(milliseconds: value.round()));
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  format(controller.position),
                  style: const TextStyle(color: SC.textFaint, fontSize: 12),
                ),
                Text(
                  format(controller.duration),
                  style: const TextStyle(color: SC.textFaint, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TransportControls extends StatelessWidget {
  const _TransportControls({required this.controller});

  final PlayerController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            onPressed: controller.toggleShuffle,
            iconSize: 26,
            color: controller.shuffleEnabled ? SC.text : SC.textGhost,
            icon: const Icon(Icons.shuffle),
          ),
          IconButton(
            onPressed: controller.previous,
            iconSize: 38,
            color: Colors.white,
            icon: const Icon(Icons.skip_previous),
          ),
          _PlayButton(controller: controller),
          IconButton(
            onPressed: controller.next,
            iconSize: 38,
            color: Colors.white,
            icon: const Icon(Icons.skip_next),
          ),
          IconButton(
            onPressed: controller.cycleRepeat,
            iconSize: 26,
            color: controller.repeatEnabled ? SC.text : SC.textGhost,
            icon: Icon(
              controller.repeatOne ? Icons.repeat_one : Icons.repeat,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.controller});

  final PlayerController controller;

  @override
  Widget build(BuildContext context) {
    final playing = controller.playing;
    return GestureDetector(
      onTap: controller.togglePlay,
      child: Container(
        width: 76,
        height: 76,
        decoration: const BoxDecoration(
          color: SC.text,
          shape: BoxShape.circle,
        ),
        child: Icon(
          playing ? Icons.pause : Icons.play_arrow,
          size: 40,
          color: Colors.black,
        ),
      ),
    );
  }
}
