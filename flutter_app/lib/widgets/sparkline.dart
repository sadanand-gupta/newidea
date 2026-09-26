import 'package:flutter/material.dart';

/// 7-day trend line that draws itself in, with a soft glow and gradient fill.
class Sparkline extends StatelessWidget {
  const Sparkline({super.key, required this.values, required this.color, this.fill = true});

  final List<double> values;
  final Color color;
  final bool fill;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (_, progress, __) => CustomPaint(
        painter: _SparklinePainter(values, color, progress, fill),
        size: Size.infinite,
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter(this.values, this.color, this.progress, this.fill);

  final List<double> values;
  final Color color;
  final double progress;
  final bool fill;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2 || progress == 0) return;
    var lo = values.first, hi = values.first;
    for (final v in values) {
      if (v < lo) lo = v;
      if (v > hi) hi = v;
    }
    final range = hi - lo == 0 ? 1.0 : hi - lo;
    final dx = size.width / (values.length - 1);
    final count = (values.length * progress).clamp(2, values.length).toInt();

    final line = Path();
    for (var i = 0; i < count; i++) {
      final x = i * dx;
      final y = size.height - (values[i] - lo) / range * size.height * 0.9 - size.height * 0.05;
      i == 0 ? line.moveTo(x, y) : line.lineTo(x, y);
    }

    if (fill) {
      final area = Path.from(line)
        ..lineTo((count - 1) * dx, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color.withValues(alpha: 0.25), color.withValues(alpha: 0)],
          ).createShader(Offset.zero & size),
      );
    }

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(line, Paint.from(stroke)
      ..color = color.withValues(alpha: 0.35)
      ..strokeWidth = 4
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    canvas.drawPath(line, stroke);
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.progress != progress || old.values != values || old.color != color;
}
