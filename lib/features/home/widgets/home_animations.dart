import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../theme.dart';

/// CustomPainter that draws the animated radar/Wi-Fi signal icon.
class RadarPainter extends CustomPainter {
  const RadarPainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, size.height * 0.75);

    // Pulsing rings
    final pulsePaint = Paint()
      ..style       = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (int i = 0; i < 3; i++) {
      final rp      = (progress + i / 3) % 1.0;
      final radius  = 4.0 + rp * 45;
      final opacity = (1.0 - rp) * 0.3;
      canvas.drawCircle(origin, radius, pulsePaint..color = Colors.white.withValues(alpha: opacity));
    }

    // Static Wi-Fi arcs
    const sweepAngle = math.pi * 0.5;
    const startAngle = -math.pi * 0.75;
    final arcPaint   = Paint()
      ..style       = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap   = StrokeCap.round;
    for (int i = 0; i < 3; i++) {
      final radius  = [18.0, 32.0, 46.0][i];
      final opacity = [0.4,  0.7,  1.0 ][i];
      canvas.drawArc(
        Rect.fromCircle(center: origin, radius: radius),
        startAngle, sweepAngle, false,
        arcPaint..color = Colors.white.withValues(alpha: opacity),
      );
    }

    // Center dot
    canvas.drawCircle(origin, 5.0, Paint()..color = Colors.white);
    canvas.drawCircle(origin, 2.5, Paint()..color = const Color(0xFF1A3A6B).withValues(alpha: 0.4));
  }

  @override
  bool shouldRepaint(RadarPainter old) => old.progress != progress;
}

/// Animated radar icon — continuously loops via an [AnimationController].
class AnimatedRadarIcon extends StatefulWidget {
  const AnimatedRadarIcon({super.key});

  @override
  State<AnimatedRadarIcon> createState() => _AnimatedRadarIconState();
}

class _AnimatedRadarIconState extends State<AnimatedRadarIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState()  { super.initState();  _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(); }

  @override
  void dispose()    { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _ctrl,
    builder:   (_, __) => CustomPaint(size: const Size(90, 90), painter: RadarPainter(_ctrl.value)),
  );
}

/// Blue gradient box with a floating animation that wraps any [child] widget.
class FloatingIconBox extends StatefulWidget {
  const FloatingIconBox({super.key, required this.child});
  final Widget child;

  @override
  State<FloatingIconBox> createState() => _FloatingIconBoxState();
}

class _FloatingIconBoxState extends State<FloatingIconBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _float;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000))..repeat(reverse: true);
    _float = Tween<double>(begin: 0, end: -8).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _float,
    builder:   (_, child) => Transform.translate(offset: Offset(0, _float.value), child: child),
    child: Container(
      width: 110, height: 110,
      decoration: BoxDecoration(
        gradient:     const LinearGradient(
          colors: [Color(0xFF1A3A6B), Color(0xFF2E6BB8)],
          begin:  Alignment.topLeft,
          end:    Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [BoxShadow(color: const Color(0xFF1A3A6B).withValues(alpha: 0.35), blurRadius: 32, offset: const Offset(0, 14))],
      ),
      child: widget.child,
    ),
  );
}
