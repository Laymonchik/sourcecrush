import 'package:flutter/material.dart';

import '../models/track.dart';
import '../player_controller.dart';
import 'marquee_text.dart';
import 'theme.dart';
import 'track_artwork.dart';
import 'waveform.dart';

/// Full screen player: large artwork, waveform scrubber, transport controls.
class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key, required this.controller});

  final PlayerController controller;

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  /// Peaks for the track on screen, keyed by uri so switching tracks re-decodes
  /// rather than showing the previous track's shape.
  final Map<String, List<double>> _waveforms = {};
  String? _waveformFor;
  bool _decoding = false;

  PlayerController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onPlaybackChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadWaveform());
  }

  @override
  void dispose() {
    _controller.removeListener(_onPlaybackChanged);
    super.dispose();
  }

  void _onPlaybackChanged() {
    // Position ticks arrive many times a second; only the track identity is
    // interesting here.
    final id = _controller.currentTrack?.id;
    if (id != _waveformFor) {
      _loadWaveform();
    } else if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadWaveform() async {
    final track = _controller.currentTrack;
    if (track == null) return;

    _waveformFor = track.id;
    final cached = _waveforms[track.id];
    if (cached != null) {
      if (mounted) setState(() {});
      return;
    }

    _decoding = true;
    if (mounted) setState(() {});

    final peaks = await _controller.waveformFor(track);
    if (!mounted) return;

    // The user may have skipped on while this was decoding.
    if (_controller.currentTrack?.id == track.id) {
      _waveforms[track.id] = peaks;
    }
    _decoding = false;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SC.background,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final track = _controller.currentTrack;
          if (track == null) {
            return const Center(
              child: Text(
                'Nothing playing',
                style: TextStyle(color: SC.textFaint),
              ),
            );
          }

          final duration = _controller.duration;
          final durationMs = duration.inMilliseconds;
          final progress = durationMs <= 0
              ? 0.0
              : (_controller.position.inMilliseconds / durationMs)
                  .clamp(0.0, 1.0);

          return SafeArea(
            child: Column(
              children: [
                const _TopBar(),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // Artwork takes the space it can while leaving room for
                      // the heading and controls on a short screen.
                      final side = (constraints.maxWidth * 0.82)
                          .clamp(0.0, constraints.maxHeight * 0.50);

                      return Column(
                        children: [
                          SizedBox(height: constraints.maxHeight * 0.03),
                          Center(
                            child: SizedBox(
                              width: side,
                              height: side,
                              child: TrackArtwork(
                                track: track,
                                borderRadius: 16,
                              ),
                            ),
                          ),
                          // Fixed gaps rather than a scroll view: the layout
                          // is already bounded, and scrolling here made the
                          // heading drift away from the artwork.
                          SizedBox(height: constraints.maxHeight * 0.05),
                          _TrackHeading(track: track),
                          const Spacer(),
                        ],
                      );
                    },
                  ),
                ),
                _WaveformSection(
                  controller: _controller,
                  progress: progress,
                  peaks: _waveforms[track.id] ?? const [],
                  decoding: _decoding,
                  onSeek: (fraction) {
                    final target = Duration(
                      milliseconds: (durationMs * fraction).round(),
                    );
                    _controller.seek(target);
                  },
                ),
                _TransportControls(controller: _controller),
                const SizedBox(height: 28),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(
              Icons.keyboard_arrow_down,
              color: SC.text,
              size: 30,
            ),
          ),
          const Spacer(),
          const Text(
            'NOW PLAYING',
            style: TextStyle(
              color: SC.textGhost,
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

class _TrackHeading extends StatelessWidget {
  const _TrackHeading({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          // Centred as a block, then each line scrolls inside its own box. A
          // centred marquee drifts sideways as it moves, which reads as a
          // layout bug, and without the clip the moving text slides out over
          // the artwork and the screen edges.
          ClipRect(
            child: MarqueeText(
              text: track.title,
              style: const TextStyle(
                color: SC.text,
                fontSize: 21,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(height: 6),
          ClipRect(
            child: MarqueeText(
              text: track.artist,
              style: const TextStyle(
                color: SC.textMuted,
                fontSize: 15,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WaveformSection extends StatelessWidget {
  const _WaveformSection({
    required this.controller,
    required this.progress,
    required this.peaks,
    required this.decoding,
    required this.onSeek,
  });

  final PlayerController controller;
  final double progress;
  final List<double> peaks;
  final bool decoding;
  final ValueChanged<double> onSeek;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 8, 28, 0),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              WaveformSeekBar(
                peaks: peaks,
                progress: progress,
                onSeek: onSeek,
              ),
              // Decoding is fast but not instant on a long track; saying so is
              // better than showing an empty bar that looks broken.
              if (decoding && peaks.isEmpty)
                const Text(
                  'Reading waveform...',
                  style: TextStyle(color: SC.textFaint, fontSize: 12),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatPosition(controller.position),
                  style: const TextStyle(color: SC.textFaint, fontSize: 12),
                ),
                Text(
                  _formatPosition(controller.duration),
                  style: const TextStyle(color: SC.textFaint, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatPosition(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
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
            color: SC.text,
            icon: const Icon(Icons.skip_previous),
          ),
          _PlayButton(controller: controller),
          IconButton(
            onPressed: controller.next,
            iconSize: 38,
            color: SC.text,
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
