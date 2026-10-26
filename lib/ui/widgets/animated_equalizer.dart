import 'dart:math' as math;
import 'package:flutter/material.dart';

class AnimatedEqualizerBars extends StatefulWidget {
  final bool isPlaying;
  final Color color;
  final double size;

  const AnimatedEqualizerBars({
    super.key,
    required this.isPlaying,
    this.color = const Color(0xFF1DB954),
    this.size = 20,
  });

  @override
  State<AnimatedEqualizerBars> createState() => _AnimatedEqualizerBarsState();
}

class _AnimatedEqualizerBarsState extends State<AnimatedEqualizerBars>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedEqualizerBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isPlaying && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value * 2 * math.pi;
        // In play le tre barre oscillano sfasate; in pausa restano ferme a un'altezza fissa
        final h1 = widget.isPlaying ? (0.25 + 0.65 * ((1 + math.sin(t)) / 2)) : 0.35;
        final h2 = widget.isPlaying ? (0.25 + 0.75 * ((1 + math.sin(t + 1.8)) / 2)) : 0.85;
        final h3 = widget.isPlaying ? (0.25 + 0.65 * ((1 + math.sin(t + 3.6)) / 2)) : 0.55;

        final maxHeight = widget.size;
        final barWidth = (widget.size / 6.0).clamp(2.5, 4.0);
        final spacing = (widget.size / 9.0).clamp(2.0, 3.5);

        return SizedBox(
          height: maxHeight,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildBar(maxHeight * h1, barWidth),
              SizedBox(width: spacing),
              _buildBar(maxHeight * h2, barWidth),
              SizedBox(width: spacing),
              _buildBar(maxHeight * h3, barWidth),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBar(double height, double width) {
    return Container(
      width: width,
      height: height.clamp(3.0, widget.size),
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(1.5),
      ),
    );
  }
}
