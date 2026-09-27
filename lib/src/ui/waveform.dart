import 'package:flutter/material.dart';

import 'theme.dart';

/// Static waveform bars with a playhead, in the style of SoundCloud's seek bar.
///
/// The peaks are decoded once per track (see `MediaMetadataService`) and cached,
/// so scrubbing is just a repaint. Only the bars either side of the playhead
/// change colour, which keeps it cheap even at a few hundred bars.
class WaveformSeekBar extends StatelessWidget {
  const WaveformSeekBar({
    super.key,
    required this.peaks,
    required this.progress,
    required this.onSeek,
    this.height = 72,
    this.barWidth = 3,
    this.barGap = 2,
  });

  /// Amplitudes in 0..1. An empty list renders a flat placeholder.
  final List<double> peaks;

  /// Playback position as a fraction of the track, 0..1.
  final double progress;

  /// Receives a new position as a fraction, 0..1.
  final ValueChanged<double> onSeek;

  final double height;
  final double barWidth;
  final double barGap;

  void _handle(Offset localPosition, double width) {
    onSeek((localPosition.dx / width).clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final resolved = _resolvePeaks(width);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => _handle(d.localPosition, width),
          onHorizontalDragUpdate: (d) => _handle(d.localPosition, width),
          child: SizedBox(
            height: height,
            width: width,
            child: CustomPaint(
              painter: _WaveformPainter(
                peaks: resolved,
                progress: progress.clamp(0.0, 1.0),
                barWidth: barWidth,
                barGap: barGap,
                playedColor: SC.text,
                unplayedColor: SC.outline,
                playheadColor: SC.text,
              ),
            ),
          ),
        );
      },
    );
  }

  /// Fits the peaks to the available width, resampling if they do not line up.
  ///
  /// The number of bars is derived from the layout rather than fixed, so the
  /// waveform looks the same on any screen. Interpolation keeps the shape
  /// recognisable when downsampling a long track.
  List<double> _resolvePeaks(double width) {
    final barCount = ((width + barGap) / (barWidth + barGap)).floor();
    if (barCount <= 0) return const [];
    if (peaks.isEmpty) {
      return List.filled(barCount, 0.12);
    }
    if (peaks.length == barCount) return peaks;

    return List.generate(barCount, (i) {
      // Take the loudest sample in each source window rather than averaging:
      // averaging flattens transients and the waveform stops looking like
      // the music.
      final start = (i * peaks.length / barCount).floor();
      final end = ((i + 1) * peaks.length / barCount).ceil().clamp(start + 1, peaks.length);
      var loudest = 0.0;
      for (var j = start; j < end; j++) {
        if (peaks[j] > loudest) loudest = peaks[j];
      }
      return loudest;
    });
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.peaks,
    required this.progress,
    required this.barWidth,
    required this.barGap,
    required this.playedColor,
    required this.unplayedColor,
    required this.playheadColor,
  });

  final List<double> peaks;
  final double progress;
  final double barWidth;
  final double barGap;
  final Color playedColor;
  final Color unplayedColor;
  final Color playheadColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (peaks.isEmpty) return;

    final centreY = size.height / 2;
    final step = barWidth + barGap;
    final playedX = size.width * progress;

    final playedPaint = Paint()
      ..color = playedColor
      ..style = PaintingStyle.fill;
    final unplayedPaint = Paint()
      ..color = unplayedColor
      ..style = PaintingStyle.fill;

    for (var i = 0; i < peaks.length; i++) {
      final x = i * step;
      if (x > size.width) break;

      // A floor keeps silent passages visible as a hairline rather than
      // nothing at all, which reads as a rendering bug.
      final amplitude = peaks[i].clamp(0.04, 1.0);
      final barHeight = amplitude * size.height;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, centreY - barHeight / 2, barWidth, barHeight),
        Radius.circular(barWidth / 2),
      );

      canvas.drawRRect(rect, x + barWidth / 2 <= playedX ? playedPaint : unplayedPaint);
    }

    // Playhead: a thin bright line so the exact position is readable at a
    // glance, independent of which bars happen to be filled.
    if (progress > 0) {
      canvas.drawRect(
        Rect.fromLTWH(playedX - 0.75, 0, 1.5, size.height),
        Paint()..color = playheadColor,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.progress != progress ||
      old.peaks != peaks ||
      old.playedColor != playedColor ||
      old.unplayedColor != unplayedColor;
}
