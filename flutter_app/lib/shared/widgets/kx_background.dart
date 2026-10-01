import 'dart:math';

import 'package:flutter/material.dart';

import 'package:kryptox/core/theme/app_theme.dart';

/// Ambient animated backdrop: slowly drifting neon glows over a faint
/// perspective grid. Sits behind every route.
class KxBackground extends StatefulWidget {
  const KxBackground({super.key, required this.child, this.intensity = 1});

  final Widget child;

  /// 0..1, how strong the glows are (detail pages use a calmer backdrop).
  final double intensity;

  @override
  State<KxBackground> createState() => _KxBackgroundState();
}

class _KxBackgroundState extends State<KxBackground> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(seconds: 24))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: KxColors.bg,
      child: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (_, __) => CustomPaint(painter: _BackdropPainter(_controller.value, widget.intensity)),
              ),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

class _BackdropPainter extends CustomPainter {
  _BackdropPainter(this.t, this.intensity);

  final double t;
  final double intensity;

  void _glow(Canvas canvas, Offset center, double radius, Color color) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: 0.22 * intensity),
          color.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final a = t * 2 * pi;
    final w = size.width, h = size.height;

    _glow(canvas, Offset(w * (0.15 + 0.1 * sin(a)), h * (0.08 + 0.05 * cos(a))), w * 0.9, KxColors.violet);
    _glow(canvas, Offset(w * (0.9 + 0.08 * cos(a)), h * (0.35 + 0.06 * sin(a))), w * 0.75, KxColors.cyan);
    _glow(canvas, Offset(w * (0.4 + 0.12 * sin(a + 2)), h * (0.95 + 0.04 * cos(a))), w * 0.8, KxColors.magenta);

    // Faint grid that fades out towards the bottom.
    const spacing = 36.0;
    final gridPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.05 * intensity),
          Colors.white.withValues(alpha: 0),
        ],
        stops: const [0, 0.7],
      ).createShader(Offset.zero & size)
      ..strokeWidth = 0.5;
    final offset = (t * spacing * 4) % spacing; // slow vertical scroll
    for (var x = 0.0; x <= w; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, h), gridPaint);
    }
    for (var y = offset - spacing; y <= h; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(_BackdropPainter old) => old.t != t || old.intensity != intensity;
}
