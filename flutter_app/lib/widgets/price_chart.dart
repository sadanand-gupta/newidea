import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/coin.dart';
import '../theme/app_theme.dart';
import 'formatters.dart';

/// Interactive neon line chart. Drag to scrub: [onScrub] reports the point
/// under the finger (null when released) so the page header can show it.
class PriceChart extends StatelessWidget {
  const PriceChart({super.key, required this.points, required this.days, this.onScrub});

  final List<PricePoint> points;
  final int days;
  final ValueChanged<PricePoint?>? onScrub;

  String _axisPrice(double v) => v >= 1000 ? formatCompact(v) : formatPrice(v);

  String _axisTime(DateTime t) => days <= 1
      ? formatTime(t)
      : days <= 90
          ? formatDateShort(t)
          : formatMonthYear(t);

  @override
  Widget build(BuildContext context) {
    final spots = [
      for (final p in points) FlSpot(p.time.millisecondsSinceEpoch.toDouble(), p.price),
    ];
    final prices = points.map((p) => p.price);
    final lo = prices.reduce(min), hi = prices.reduce(max);
    // Pad the Y range; flat series (stablecoins) still get a visible band.
    var pad = max((hi - lo) * 0.12, hi * 0.001);
    // An all-zero series would give a zero interval, which fl_chart rejects.
    if (pad <= 0) pad = 1;
    final minY = lo - pad, maxY = hi + pad;
    final minX = spots.first.x, maxX = spots.last.x;
    final yInterval = (maxY - minY) / 4;
    final xInterval = max((maxX - minX) / 4, 1.0);

    final color = points.last.price >= points.first.price ? KxColors.up : KxColors.down;
    final labelStyle = KxText.mono(10, color: KxColors.textMuted);

    final chart = LineChart(
      LineChartData(
        minX: minX,
        maxX: maxX,
        minY: minY,
        maxY: maxY,
        clipData: const FlClipData.all(),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: yInterval,
          getDrawingHorizontalLine: (_) => FlLine(color: KxColors.border, strokeWidth: 1, dashArray: [3, 5]),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 62,
              interval: yInterval,
              getTitlesWidget: (value, meta) {
                if (value == meta.min || value == meta.max) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(_axisPrice(value), style: labelStyle, maxLines: 1),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: xInterval,
              getTitlesWidget: (value, meta) {
                // Skip labels that would be clipped at the chart edges.
                if (value - meta.min < xInterval * 0.4 || meta.max - value < xInterval * 0.4) {
                  return const SizedBox.shrink();
                }
                final t = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(_axisTime(t), style: labelStyle),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          handleBuiltInTouches: true,
          touchCallback: (event, response) {
            if (onScrub == null) return;
            final spot = response?.lineBarSpots?.firstOrNull;
            // spotIndex refers to the (possibly still animating) chart data, so
            // bounds-check it against the current points.
            if (!event.isInterestedForInteractions ||
                spot == null ||
                spot.spotIndex < 0 ||
                spot.spotIndex >= points.length) {
              onScrub!(null);
              return;
            }
            if (event is FlPanStartEvent || event is FlLongPressStart || event is FlTapDownEvent) {
              HapticFeedback.selectionClick();
            }
            onScrub!(points[spot.spotIndex]);
          },
          getTouchedSpotIndicator: (bar, indexes) => [
            for (final _ in indexes)
              TouchedSpotIndicatorData(
                FlLine(color: KxColors.cyan.withValues(alpha: 0.6), strokeWidth: 1, dashArray: [4, 4]),
                FlDotData(
                  getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                    radius: 6,
                    color: KxColors.bg,
                    strokeWidth: 3,
                    strokeColor: color,
                  ),
                ),
              ),
          ],
          touchTooltipData: LineTouchTooltipData(
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            tooltipBorderRadius: BorderRadius.circular(10),
            tooltipBorder: const BorderSide(color: KxColors.borderStrong),
            getTooltipColor: (_) => KxColors.bgElevated.withValues(alpha: 0.92),
            getTooltipItems: (touched) => [
              for (final s in touched)
                LineTooltipItem(
                  '${formatPrice(s.y)}\n',
                  KxText.mono(13, weight: FontWeight.w700),
                  children: [
                    TextSpan(
                      text: formatDateTime(DateTime.fromMillisecondsSinceEpoch(s.x.toInt())),
                      style: KxText.mono(10, color: KxColors.textDim),
                    ),
                  ],
                ),
            ],
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            color: color,
            barWidth: 2.4,
            isCurved: true,
            curveSmoothness: 0.15,
            preventCurveOverShooting: true,
            isStrokeCapRound: true,
            shadow: Shadow(color: color.withValues(alpha: 0.7), blurRadius: 12),
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [color.withValues(alpha: 0.32), color.withValues(alpha: 0.0)],
              ),
            ),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );

    // Left-to-right "draw in" reveal whenever a new range is loaded.
    return TweenAnimationBuilder<double>(
      key: ValueKey('$days-${points.length}-${points.first.time}'),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeInOutCubic,
      builder: (_, reveal, child) => ClipRect(clipper: _RevealClipper(reveal), child: child),
      child: chart,
    );
  }
}

class _RevealClipper extends CustomClipper<Rect> {
  _RevealClipper(this.progress);

  final double progress;

  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, size.width * progress, size.height);

  @override
  bool shouldReclip(_RevealClipper old) => old.progress != progress;
}
