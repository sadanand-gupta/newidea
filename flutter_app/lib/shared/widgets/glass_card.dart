import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:kryptox/core/theme/app_theme.dart';

/// Frosted glass panel with a hairline gradient border.
///
/// [blur] is off by default: blurring is expensive, so it's reserved for
/// floating chrome (nav bar, search) rather than every list row.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 20,
    this.blur = false,
    this.glow,
    this.onTap,
    this.gradient,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool blur;

  /// Optional coloured outer glow, e.g. for the hero card.
  final Color? glow;
  final VoidCallback? onTap;

  /// Override the fill (defaults to translucent white).
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    Widget content = Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: shape,
        splashColor: KxColors.cyan.withValues(alpha: 0.08),
        highlightColor: Colors.white.withValues(alpha: 0.03),
        child: Padding(padding: padding, child: child),
      ),
    );

    content = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        gradient:
            gradient ??
            LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white.withValues(alpha: 0.07), Colors.white.withValues(alpha: 0.025)],
            ),
      ),
      child: content,
    );

    if (blur) {
      content = BackdropFilter(filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18), child: content);
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: [
          if (glow != null) BoxShadow(color: glow!.withValues(alpha: 0.25), blurRadius: 32, spreadRadius: -4),
        ],
      ),
      child: CustomPaint(
        foregroundPainter: _GradientBorderPainter(radius),
        child: ClipRRect(borderRadius: shape, child: content),
      ),
    );
  }
}

class _GradientBorderPainter extends CustomPainter {
  _GradientBorderPainter(this.radius);

  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(0.5);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.18),
          Colors.white.withValues(alpha: 0.04),
          KxColors.cyan.withValues(alpha: 0.12),
        ],
      ).createShader(rect);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)), paint);
  }

  @override
  bool shouldRepaint(_GradientBorderPainter old) => old.radius != radius;
}
