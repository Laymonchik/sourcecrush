import 'package:flutter/material.dart';

/// Scrolls its text horizontally when it does not fit, and gets out of the way
/// when it does.
///
/// Implemented by rendering two copies of the text and translating them by
/// exactly one copy's width, so the loop point is seamless.
class MarqueeText extends StatefulWidget {
  const MarqueeText({
    super.key,
    required this.text,
    required this.style,
    this.fadeWidth = 20,
  });

  final String text;
  final TextStyle style;

  /// Width of the soft fade applied to both ends while scrolling.
  final double fadeWidth;

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  );

  /// Width of one copy of the text plus the gap before the next copy.
  double _copyStride = 0;
  bool _overflows = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _startIfNeeded();
  }

  @override
  void didUpdateWidget(MarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _controller.reset();
      _startIfNeeded();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startIfNeeded() {
    if (!mounted) return;
    if (_overflows && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!_overflows && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textPainter = TextPainter(
          text: TextSpan(text: widget.text, style: widget.style),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout();

        final textWidth = textPainter.width;
        final available = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : textWidth;
        final gap = available * 0.35;
        _copyStride = textWidth + gap;
        final lineHeight =
            (widget.style.fontSize ?? 14) * (widget.style.height ?? 1.2);
        final overflows = textWidth > available;
        if (overflows != _overflows) {
          // Defer so we never call setState during layout.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => _overflows = overflows);
            _startIfNeeded();
          });
        }
        textPainter.dispose();

        final text = Text(
          widget.text,
          maxLines: 1,
          softWrap: false,
          style: widget.style,
        );

        if (!overflows) {
          return Text(
            widget.text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: widget.style,
          );
        }

        // Height is pinned to the text's own line height: the shader mask sizes
        // itself to the child, and an unpinned Row with 21px text plus the
        // default leading claims far more vertical space than it draws, which
        // pushed the heading around in the now playing column.
        return SizedBox(
          height: lineHeight,
          child: ClipRect(
            child: ShaderMask(
              shaderCallback: (rect) => const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.transparent,
                  Colors.white,
                  Colors.white,
                  Colors.transparent,
                ],
                stops: [0, 0.12, 0.88, 1],
              ).createShader(rect),
              blendMode: BlendMode.dstIn,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return Transform.translate(
                    offset: Offset(-_controller.value * _copyStride, 0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        text,
                        SizedBox(width: gap),
                        text,
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
