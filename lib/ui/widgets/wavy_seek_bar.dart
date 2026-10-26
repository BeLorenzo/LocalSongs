import 'dart:math' as math;
import 'package:flutter/material.dart';

class WavySeekBar extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final bool isPlaying;
  final ValueChanged<Duration> onSeek;

  const WavySeekBar({
    super.key,
    required this.position,
    required this.duration,
    required this.isPlaying,
    required this.onSeek,
  });

  @override
  State<WavySeekBar> createState() => _WavySeekBarState();
}

class _WavySeekBarState extends State<WavySeekBar> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  double? _dragValue;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (widget.isPlaying) {
      _animController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant WavySeekBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !_animController.isAnimating) {
      _animController.repeat();
    } else if (!widget.isPlaying && _animController.isAnimating) {
      _animController.stop();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxMs = widget.duration.inMilliseconds > 0 ? widget.duration.inMilliseconds.toDouble() : 1.0;
    final currentMs = (_dragValue ?? widget.position.inMilliseconds.toDouble()).clamp(0.0, maxMs);
    final progress = (currentMs / maxMs).clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (details) {
            final rel = (details.localPosition.dx / width).clamp(0.0, 1.0);
            setState(() => _dragValue = rel * maxMs);
          },
          onHorizontalDragUpdate: (details) {
            final rel = (details.localPosition.dx / width).clamp(0.0, 1.0);
            setState(() => _dragValue = rel * maxMs);
          },
          onHorizontalDragEnd: (details) {
            if (_dragValue != null) {
              widget.onSeek(Duration(milliseconds: _dragValue!.toInt()));
              setState(() => _dragValue = null);
            }
          },
          onTapDown: (details) {
            final rel = (details.localPosition.dx / width).clamp(0.0, 1.0);
            widget.onSeek(Duration(milliseconds: (rel * maxMs).toInt()));
          },
          child: SizedBox(
            height: 38,
            child: AnimatedBuilder(
              animation: _animController,
              builder: (context, child) {
                return CustomPaint(
                  size: Size(width, 38),
                  painter: _WavyTrackPainter(
                    progress: progress,
                    phase: _animController.value * 2 * math.pi,
                    isWavy: widget.isPlaying,
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _WavyTrackPainter extends CustomPainter {
  final double progress;
  final double phase;
  final bool isWavy;

  _WavyTrackPainter({
    required this.progress,
    required this.phase,
    required this.isWavy,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final progressX = size.width * progress;

    // 1. Tratto inattivo (parte da ascoltare) -> linea piatta grigio-trasparente
    final inactivePaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    if (progressX < size.width) {
      canvas.drawLine(
        Offset(math.min(progressX + 4.0, size.width), centerY),
        Offset(size.width, centerY),
        inactivePaint,
      );
    }

    // 2. Tratto attivo (ascoltato) -> ONDULATO se in riproduzione, PIATTO se in pausa
    final activePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(0, centerY);

    if (isWavy && progressX > 8) {
      const waveLength = 26.0;
      const amplitude = 3.8;
      for (double x = 0; x <= progressX; x += 2) {
        final y = centerY + math.sin((x / waveLength * 2 * math.pi) - phase) * amplitude;
        path.lineTo(x, y);
      }
    } else {
      path.lineTo(progressX, centerY);
    }
    canvas.drawPath(path, activePaint);

    // 3. Thumb (pallino sulla posizione)
    final thumbPaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(progressX, centerY), 6.5, thumbPaint);

    final thumbBorderPaint = Paint()
      ..color = Colors.black45
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(Offset(progressX, centerY), 6.5, thumbBorderPaint);
  }

  @override
  bool shouldRepaint(covariant _WavyTrackPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.phase != phase ||
        oldDelegate.isWavy != isWavy;
  }
}
