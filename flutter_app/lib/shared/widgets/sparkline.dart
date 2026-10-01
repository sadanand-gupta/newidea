import 'package:flutter/material.dart';

/// 7-day trend line that draws itself in, with a soft glow and gradient fill.
///
/// Purely decorative: it's excluded from semantics, so callers should expose
/// the trend (e.g. the 7d change) as text.
class Sparkline extends StatelessWidget {
  const Sparkline({super.key, required this.values, required this.color, this.fill = true});

  final List<double> values;
  final Color color;
  final bool fill;

  @override
  Widget build(BuildContext context) {
    // Own layer: list tiles animate in parallel without repainting the row.
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (_, progress, __) =>
              CustomPaint(painter: _SparklinePainter(values, color, progress, fill), size: Size.infinite),
        ),
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
    if (progress <= 0 || !size.width.isFinite || !size.height.isFinite || size.isEmpty) return;
    final data = [
      for (final v in values)
        if (v.isFinite) v,
    ];
    if (data.length < 2) return;

    var lo = data.first, hi = data.first;
    for (final v in data) {
      if (v < lo) lo = v;
      if (v > hi) hi = v;
    }
    final flat = hi - lo == 0;
    final range = flat ? 1.0 : hi - lo;
    final dx = size.width / (data.length - 1);
    // Flat series (stablecoins) sit in the middle instead of on the floor.
    double yOf(double v) =>
        flat ? size.height / 2 : size.height - (v - lo) / range * size.height * 0.9 - size.height * 0.05;

    // Continuous reveal: draw whole segments, then interpolate the last one
    // so the line grows smoothly instead of jumping point to point.
    final head = (data.length - 1) * progress.clamp(0.0, 1.0).toDouble();
    final whole = head.floor();
    final frac = head - whole;

    final line = Path()..moveTo(0, yOf(data[0]));
    for (var i = 1; i <= whole; i++) {
      line.lineTo(i * dx, yOf(data[i]));
    }
    var endX = whole * dx;
    if (frac > 0 && whole + 1 < data.length) {
      final y0 = yOf(data[whole]), y1 = yOf(data[whole + 1]);
      endX = (whole + frac) * dx;
      line.lineTo(endX, y0 + (y1 - y0) * frac);
    }

    if (fill) {
      final area = Path.from(line)
        ..lineTo(endX, size.height)
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
    canvas.drawPath(
      line,
      Paint.from(stroke)
        ..color = color.withValues(alpha: 0.35)
        ..strokeWidth = 4
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawPath(line, stroke);
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.progress != progress || old.values != values || old.color != color || old.fill != fill;
}
