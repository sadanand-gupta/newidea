import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:kryptox/data/models/coin.dart';
import 'package:kryptox/core/theme/app_theme.dart';
import 'package:kryptox/core/utils/formatters.dart';

/// Interactive neon line chart. Drag (or hover, on desktop/web) to scrub:
/// [onScrub] reports the point under the pointer (null when released) so the
/// page header can show it.
class PriceChart extends StatelessWidget {
  const PriceChart({super.key, required this.points, required this.days, this.onScrub});

  final List<PricePoint> points;
  final int days;
  final ValueChanged<PricePoint?>? onScrub;

  String _axisTime(DateTime t) => days <= 1
      ? formatTime(t)
      : days <= 90
      ? formatDateShort(t)
      : formatMonthYear(t);

  String _rangeName() => switch (days) {
    1 => 'past 24 hours',
    365 => 'past year',
    _ => 'past $days days',
  };

  @override
  Widget build(BuildContext context) {
    // Defensive: callers should guard, but never crash on a thin series.
    final valid = [
      for (final p in points)
        if (p.price.isFinite) p,
    ];
    if (valid.length < 2) {
      return Center(
        child: Text('Not enough data to draw a chart', style: KxText.body(13, color: KxColors.textMuted)),
      );
    }

    final spots = [for (final p in valid) FlSpot(p.time.millisecondsSinceEpoch.toDouble(), p.price)];
    var lo = valid.first.price, hi = valid.first.price;
    for (final p in valid) {
      if (p.price < lo) lo = p.price;
      if (p.price > hi) hi = p.price;
    }
    // Pad the Y range; flat series (stablecoins) still get a visible band.
    var pad = max((hi - lo) * 0.12, hi.abs() * 0.001);
    // An all-zero series would give a zero interval, which fl_chart rejects.
    if (pad <= 0) pad = 1;
    final minY = lo - pad, maxY = hi + pad;
    final minX = spots.first.x, maxX = spots.last.x;
    // "Nice" steps (1/2/5 x 10^n) so axis labels read as round numbers.
    final yInterval = _niceStep((maxY - minY) / 4);
    final xInterval = max((maxX - minX) / 4, 1.0);

    final color = valid.last.price >= valid.first.price ? KxColors.up : KxColors.down;
    final labelStyle = KxText.mono(10, color: KxColors.textDim);
    final textScaler = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.4);

    // Reserve exactly as much room as the widest price label needs, so big
    // prices, tiny prices and large text scales never clip or overlap.
    var labelWidth = 0.0;
    for (final v in [minY, maxY, (minY + maxY) / 2]) {
      final tp = TextPainter(
        text: TextSpan(text: _axisPrice(v, yInterval), style: labelStyle),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
        maxLines: 1,
      )..layout();
      labelWidth = max(labelWidth, tp.width);
      tp.dispose();
    }
    // Slack covers the mono web font arriving after this measurement (the
    // fallback font is narrower, which clipped the last glyph: "$85.00I").
    final rightReserved = (labelWidth * 1.15 + 16).clamp(44.0, 132.0).toDouble();
    final bottomReserved = (textScaler.scale(10) + 12).clamp(24.0, 34.0).toDouble();

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
              reservedSize: rightReserved,
              interval: yInterval,
              getTitlesWidget: (value, meta) {
                // Skip the edges and ticks so close to them they'd be clipped.
                if (value - meta.min < yInterval * 0.35 || meta.max - value < yInterval * 0.35) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    _axisPrice(value, yInterval),
                    style: labelStyle,
                    maxLines: 1,
                    softWrap: false,
                    textScaler: textScaler,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: bottomReserved,
              interval: xInterval,
              getTitlesWidget: (value, meta) {
                // Skip labels that would be clipped at the chart edges.
                if (value - meta.min < xInterval * 0.4 || meta.max - value < xInterval * 0.4) {
                  return const SizedBox.shrink();
                }
                final t = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(_axisTime(t), style: labelStyle, maxLines: 1, softWrap: false, textScaler: textScaler),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          handleBuiltInTouches: true,
          // Forgiving hit area so sparse series (1Y, 90D) are easy to scrub.
          touchSpotThreshold: 40,
          // Full-height crosshair instead of a line that stops at the point.
          getTouchLineStart: (_, __) => -double.infinity,
          getTouchLineEnd: (_, __) => double.infinity,
          touchCallback: (event, response) {
            if (onScrub == null) return;
            final spot = response?.lineBarSpots?.firstOrNull;
            // spotIndex refers to the (possibly still animating) chart data, so
            // bounds-check it against the current points.
            if (!event.isInterestedForInteractions ||
                spot == null ||
                spot.spotIndex < 0 ||
                spot.spotIndex >= valid.length) {
              onScrub!(null);
              return;
            }
            if (event is FlPanStartEvent || event is FlLongPressStart || event is FlTapDownEvent) {
              HapticFeedback.selectionClick();
            }
            onScrub!(valid[spot.spotIndex]);
          },
          getTouchedSpotIndicator: (bar, indexes) => [
            for (final _ in indexes)
              TouchedSpotIndicatorData(
                FlLine(color: KxColors.cyan.withValues(alpha: 0.6), strokeWidth: 1, dashArray: [4, 4]),
                FlDotData(
                  getDotPainter: (_, __, ___, ____) =>
                      FlDotCirclePainter(radius: 6, color: KxColors.bg, strokeWidth: 3, strokeColor: color),
                ),
              ),
          ],
          touchTooltipData: LineTouchTooltipData(
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            maxContentWidth: 180,
            tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            tooltipBorderRadius: BorderRadius.circular(10),
            tooltipBorder: const BorderSide(color: KxColors.borderStrong),
            getTooltipColor: (_) => KxColors.bgElevated.withValues(alpha: 0.94),
            getTooltipItems: (touched) => [
              for (final s in touched)
                LineTooltipItem(
                  '${formatChartPrice(s.y)}\n',
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

    final first = valid.first.price, last = valid.last.price;
    final change = first == 0 ? null : (last / first - 1) * 100;
    final summary =
        'Price chart, ${_rangeName()}. '
        'From ${formatChartPrice(first)} to ${formatChartPrice(last)}'
        '${change == null ? '' : ', ${formatPercent(change)}'}. '
        'Low ${formatChartPrice(lo)}, high ${formatChartPrice(hi)}.';

    // Left-to-right "draw in" reveal whenever a new range is loaded.
    return Semantics(
      container: true,
      label: summary,
      child: RepaintBoundary(
        child: TweenAnimationBuilder<double>(
          key: ValueKey('$days-${valid.length}-${valid.first.time}'),
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 1100),
          curve: Curves.easeInOutCubic,
          builder: (_, reveal, child) => ClipRect(clipper: _RevealClipper(reveal), child: child),
          child: chart,
        ),
      ),
    );
  }
}

/// Price formatting that stays readable for micro-cap coins: keeps ~4
/// significant digits below $0.0001 (e.g. $0.0000001234) instead of
/// rounding to $0.00000000.
String formatChartPrice(num? value) {
  if (value == null) return '—';
  final v = value.toDouble();
  if (!v.isFinite) return '—';
  final abs = v.abs();
  if (abs > 0 && abs < 0.0001) {
    final decimals = min((-log(abs) / ln10).ceil() + 3, 18);
    return '${v < 0 ? '-' : ''}\$${abs.toStringAsFixed(decimals)}';
  }
  return formatPrice(v);
}

/// Rounds a raw axis step up to 1, 2 or 5 x 10^n.
double _niceStep(double raw) {
  if (!raw.isFinite || raw <= 0) return 1;
  final exp = pow(10, (log(raw) / ln10).floor()).toDouble();
  final f = raw / exp;
  final nice = f <= 1
      ? 1.0
      : f <= 2
      ? 2.0
      : f <= 5
      ? 5.0
      : 10.0;
  return nice * exp;
}

/// Axis label with just enough precision to tell neighbouring ticks apart.
String _axisPrice(double v, double step) {
  final abs = v.abs();
  if (abs >= 1000) {
    final divisor = abs >= 1e12
        ? 1e12
        : abs >= 1e9
        ? 1e9
        : abs >= 1e6
        ? 1e6
        : 1e3;
    // Compact ($64.25K) is only unambiguous if its resolution fits the step.
    if (divisor / 100 <= step) return formatCompact(v);
  }
  final needed = step > 0 ? max(0, (-log(step) / ln10 - 1e-9).ceil()) : 2;
  final base = abs >= 1000
      ? 0
      : abs >= 1 || abs == 0
      ? 2
      : abs >= 0.0001
      ? priceDecimals(v)
      : min((-log(abs) / ln10).ceil() + 3, 18);
  final decimals = min(max(needed, base), 18);
  if (abs >= 0.0001 || abs == 0) return formatPrice(v, decimals: decimals);
  return '${v < 0 ? '-' : ''}\$${abs.toStringAsFixed(decimals)}';
}

class _RevealClipper extends CustomClipper<Rect> {
  _RevealClipper(this.progress);

  final double progress;

  @override
  Rect getClip(Size size) => progress >= 1
      // Fully revealed: stop clipping so the line glow and the tooltip aren't
      // cut off at the edges (the tree stays the same, so no state is lost).
      ? (Offset.zero & size).inflate(200)
      : Rect.fromLTWH(0, 0, size.width * progress, size.height);

  @override
  bool shouldReclip(_RevealClipper old) => old.progress != progress;
}
