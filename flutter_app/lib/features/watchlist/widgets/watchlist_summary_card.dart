import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:kryptox/core/theme/app_theme.dart';
import 'package:kryptox/core/utils/formatters.dart';
import 'package:kryptox/data/models/coin.dart';
import 'package:kryptox/shared/shared.dart';

/// Hero card above the watchlist: asset count, average 24h move, a diverging
/// bar strip of every asset's 24h change and the best / worst performers.
class WatchlistSummaryCard extends StatelessWidget {
  const WatchlistSummaryCard({super.key, required this.coins});

  final List<Coin> coins;

  @override
  Widget build(BuildContext context) {
    final ranked = coins.where((c) => c.change24h != null).toList()
      ..sort((a, b) => b.change24h!.compareTo(a.change24h!));
    final avg = ranked.isEmpty ? null : ranked.fold<double>(0, (s, c) => s + c.change24h!) / ranked.length;
    final best = ranked.isEmpty ? null : ranked.first;
    final worst = ranked.length > 1 ? ranked.last : null;

    return GlassCard(
      glow: KxColors.violet,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          KxColors.violet.withValues(alpha: 0.13),
          KxColors.cyan.withValues(alpha: 0.07),
          Colors.white.withValues(alpha: 0.02),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: StatTile(
                  framed: false,
                  label: 'ASSETS',
                  valueWidget: CountUp(
                    value: coins.length.toDouble(),
                    format: (v) => '${v.round()}',
                    duration: const Duration(milliseconds: 700),
                    style: KxText.mono(26, weight: FontWeight.w700),
                  ),
                ),
              ),
              Container(width: 1, height: 42, color: KxColors.border),
              const SizedBox(width: 16),
              Expanded(
                child: StatTile(
                  framed: false,
                  label: 'AVG 24H',
                  valueWidget: CountUp(
                    value: avg,
                    format: formatPercent,
                    duration: const Duration(milliseconds: 900),
                    style: KxText.mono(
                      22,
                      weight: FontWeight.w700,
                      color: avg == null ? KxColors.textMuted : KxColors.change(avg),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (ranked.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('24H CHANGE BY ASSET', style: KxText.label(9, color: KxColors.textMuted)),
            const SizedBox(height: 8),
            SizedBox(
              height: 48,
              width: double.infinity,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: 1),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (context, t, _) =>
                    CustomPaint(painter: _ChangeBarsPainter([for (final c in ranked) c.change24h!], t)),
              ),
            ),
          ],
          if (best != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _PerformerChip(coin: best, label: 'BEST'),
                ),
                if (worst != null) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: _PerformerChip(coin: worst, label: 'WORST'),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Compact avatar · label · symbol · 24h change chip tinted by the change.
class _PerformerChip extends StatelessWidget {
  const _PerformerChip({required this.coin, required this.label});

  final Coin coin;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = KxColors.change(coin.change24h);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(KxLayout.radiusButton),
        color: color.withValues(alpha: 0.07),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          // No hero tag: the same coin is also in the list below.
          CoinAvatar(coin: coin, size: 30),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: KxText.label(9, color: color)),
                const SizedBox(height: 1),
                Text(
                  coin.symbol,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: KxText.display(14, weight: FontWeight.w600),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: ChangePill(coin.change24h, size: 10, filled: false),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Diverging bar strip around a zero line: one bar per value (best → worst),
/// grown to full height as [progress] goes from 0 to 1.
class _ChangeBarsPainter extends CustomPainter {
  _ChangeBarsPainter(this.values, this.progress);

  final List<double> values;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final n = values.length;
    if (n == 0 || size.width <= 0) return;
    final mid = size.height / 2;

    canvas.drawLine(
      Offset(0, mid),
      Offset(size.width, mid),
      Paint()
        ..color = KxColors.borderStrong
        ..strokeWidth = 1,
    );

    final maxAbs = math.max(values.map((v) => v.abs()).reduce(math.max), 0.5);
    final gap = n > 40 ? 1.0 : 3.0;
    final barWidth = ((size.width - gap * (n - 1)) / n).clamp(1.0, 18.0).toDouble();
    final totalWidth = barWidth * n + gap * (n - 1);
    final radius = Radius.circular(math.min(barWidth / 2, 3));
    var x = math.max(0.0, (size.width - totalWidth) / 2);

    for (final v in values) {
      final h = math.max(1.5, v.abs() / maxAbs * (mid - 2) * progress);
      final up = v >= 0;
      final rect = up ? Rect.fromLTWH(x, mid - h, barWidth, h) : Rect.fromLTWH(x, mid, barWidth, h);
      final color = KxColors.change(v);
      final paint = Paint()
        ..shader = LinearGradient(
          begin: up ? Alignment.topCenter : Alignment.bottomCenter,
          end: up ? Alignment.bottomCenter : Alignment.topCenter,
          colors: [color, color.withValues(alpha: 0.3)],
        ).createShader(rect);
      canvas.drawRRect(
        up
            ? RRect.fromRectAndCorners(rect, topLeft: radius, topRight: radius)
            : RRect.fromRectAndCorners(rect, bottomLeft: radius, bottomRight: radius),
        paint,
      );
      x += barWidth + gap;
    }
  }

  @override
  bool shouldRepaint(_ChangeBarsPainter old) => old.progress != progress || !listEquals(old.values, values);
}
