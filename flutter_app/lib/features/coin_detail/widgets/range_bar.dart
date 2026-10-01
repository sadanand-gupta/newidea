import 'package:flutter/material.dart';

import 'package:kryptox/core/theme/app_theme.dart';
import 'package:kryptox/shared/shared.dart';

/// 24h low → high bar with an animated marker at the [current] price, whose
/// glow shifts from red (near the low) to green (near the high).
class DayRangeBar extends StatelessWidget {
  const DayRangeBar({super.key, required this.low, required this.high, required this.current});

  final double low, high, current;

  static const double _marker = 16;
  static const double _track = 6;

  static Color _colorAt(double t) => t < 0.5
      ? Color.lerp(KxColors.down, KxColors.warn, t * 2)!
      : Color.lerp(KxColors.warn, KxColors.up, (t - 0.5) * 2)!;

  @override
  Widget build(BuildContext context) {
    final t = high > low ? ((current - low) / (high - low)).clamp(0.0, 1.0).toDouble() : 0.5;
    final percent = (t * 100).round();
    final lowText = formatChartPrice(low), highText = formatChartPrice(high);
    return Semantics(
      container: true,
      excludeSemantics: true,
      label:
          '24 hour range: low $lowText, high $highText. '
          'Current price is $percent percent of the way from low to high.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Flexible(
                child: Text('24H RANGE', maxLines: 1, overflow: TextOverflow.ellipsis, style: KxText.label(11)),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  '$percent% from low',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: KxText.mono(11, color: KxColors.textDim),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: _marker,
            child: LayoutBuilder(
              builder: (context, constraints) => TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: t),
                duration: const Duration(milliseconds: 1500),
                curve: const Interval(0.2, 1, curve: Curves.easeOutCubic),
                builder: (context, v, _) {
                  final pos = v.clamp(0.0, 1.0).toDouble();
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Positioned(left: 0, right: 0, top: (_marker - _track) / 2, height: _track, child: _Track()),
                      Positioned(
                        left: (constraints.maxWidth - _marker) * pos,
                        top: 0,
                        child: Container(
                          width: _marker,
                          height: _marker,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: KxColors.text,
                            border: Border.all(color: KxColors.bg, width: 3),
                            boxShadow: [
                              BoxShadow(color: _colorAt(pos).withValues(alpha: 0.85), blurRadius: 14, spreadRadius: 1),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _RangeEnd(label: 'LOW', value: lowText, color: KxColors.down),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _RangeEnd(label: 'HIGH', value: highText, color: KxColors.up, end: true),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Red → amber → green gradient track with a soft glow at both ends.
class _Track extends StatelessWidget {
  const _Track();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(DayRangeBar._track / 2),
        gradient: const LinearGradient(colors: [KxColors.down, KxColors.warn, KxColors.up]),
        boxShadow: [
          BoxShadow(color: KxColors.down.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(-20, 0)),
          BoxShadow(color: KxColors.up.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(20, 0)),
        ],
      ),
    );
  }
}

/// Label + price under one end of the bar.
class _RangeEnd extends StatelessWidget {
  const _RangeEnd({required this.label, required this.value, required this.color, this.end = false});

  final String label;
  final String value;
  final Color color;

  /// Right-aligned (the HIGH end).
  final bool end;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: end ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label, style: KxText.label(10, color: color.withValues(alpha: 0.8))),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: end ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(value, maxLines: 1, style: KxText.mono(13, weight: FontWeight.w600)),
        ),
      ],
    );
  }
}
