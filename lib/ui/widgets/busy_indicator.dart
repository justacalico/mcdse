import 'dart:math';

import 'package:flutter/material.dart';

/// Ported from `UserControls/BusyIndicator.xaml` — eight dots arranged in a
/// circle, each fading in sequence (staggered 0.2 s, 1.6 s fade).
class BusyIndicator extends StatefulWidget {
  const BusyIndicator({super.key, this.color});

  final Color? color;

  @override
  State<BusyIndicator> createState() => _BusyIndicatorState();
}

class _BusyIndicatorState extends State<BusyIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? const Color(0xFF9B9B9B);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return SizedBox(
          width: 100,
          height: 100,
          child: Stack(
            children: [
              for (var i = 0; i < 8; i++)
                _dot(color, i),
            ],
          ),
        );
      },
    );
  }

  Widget _dot(Color color, int i) {
    final angle = -pi / 2 + i * (2 * pi / 8);
    const radius = 36.0;
    const center = 50.0;
    // Each dot begins 0.2 s (1/8 of 1.6 s) after the previous one.
    var t = (_controller.value - i / 8.0) % 1.0;
    if (t < 0) t += 1.0;
    final opacity = (1.0 - t).clamp(0.0, 1.0);
    return Positioned(
      left: center + radius * cos(angle) - 8,
      top: center + radius * sin(angle) - 8,
      child: Opacity(
        opacity: opacity,
        child: Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}
