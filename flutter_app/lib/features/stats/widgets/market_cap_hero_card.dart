import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:kryptox/core/theme/app_theme.dart';
import 'package:kryptox/core/utils/formatters.dart';
import 'package:kryptox/data/models/coin.dart';
import 'package:kryptox/shared/shared.dart';

/// Hero card of the stats tab: total market cap, its 24h change and a 7-day
/// "pulse" sparkline of the most-traded coins.
class MarketCapHeroCard extends StatelessWidget {
  const MarketCapHeroCard({super.key, required this.stats});

  final GlobalStats stats;

  /// Market-cap weighted 7d index of [coins], rebased to 100. A real,
  /// data-driven "pulse" line: the top-volume coins carry most of the market cap.
  static List<double>? _pulse(List<Coin> coins) {
    final series = coins
        .where((c) => c.sparkline.length > 1 && c.sparkline.first > 0 && (c.marketCap ?? 0) > 0)
        .toList();
    if (series.isEmpty) return null;
    final n = series.map((c) => c.sparkline.length).reduce(math.min);
    final totalCap = series.fold<double>(0, (s, c) => s + c.marketCap!);
    return List<double>.generate(n, (i) {
      var v = 0.0;
      for (final c in series) {
        final s = c.sparkline;
        final idx = (i * (s.length - 1) / (n - 1)).round();
        v += s[idx] / s.first * (c.marketCap! / totalCap);
      }
      return v * 100;
    });
  }

  @override
  Widget build(BuildContext context) {
    final change = stats.marketCapChange24h;
    final pulse = _pulse(stats.topVolume);
    final changeText = change == null
        ? '24h change unavailable'
        : '${change >= 0 ? 'Up' : 'Down'} ${change.abs().toStringAsFixed(2)}% in the last 24 hours';

    return GlassCard(
      glow: KxColors.cyan,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          KxColors.cyan.withValues(alpha: 0.12),
          KxColors.violet.withValues(alpha: 0.10),
          Colors.white.withValues(alpha: 0.02),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBadge(icon: Icons.public_rounded, color: KxColors.cyan, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text('TOTAL MARKET CAP', style: KxText.label(11), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              ChangePill(change, size: 12),
            ],
          ),
          const SizedBox(height: 14),
          Semantics(
            label: 'Total market cap ${formatCompact(stats.totalMarketCap)}. $changeText',
            excludeSemantics: true,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: AnimatedPrice(
                value: stats.totalMarketCap,
                compact: true,
                style: KxText.mono(36, weight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 4),
          ExcludeSemantics(
            child: Text(
              changeText,
              style: KxText.body(12, color: KxColors.textDim),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (pulse != null)
            _PulseChart(values: pulse)
          else
            _GlowRule(color: change == null ? KxColors.cyan : KxColors.change(change)),
        ],
      ),
    );
  }
}

/// Sparkline of the top-volume index with its caption and 7d change.
class _PulseChart extends StatelessWidget {
  const _PulseChart({required this.values});

  final List<double> values;

  @override
  Widget build(BuildContext context) {
    final change = (values.last / values.first - 1) * 100;
    final color = KxColors.change(change);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 14),
        ExcludeSemantics(
          child: SizedBox(
            height: 64,
            child: Sparkline(values: values, color: color),
          ),
        ),
        const SizedBox(height: 8),
        Tooltip(
          message: 'Market-cap weighted 7-day performance of the most-traded coins, rebased to 100',
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '7D PULSE · TOP-VOLUME INDEX',
                  style: KxText.label(9, color: KxColors.textDim),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(formatPercent(change), style: KxText.mono(11, color: color)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Glowing hairline that anchors the card when there is no chart data.
class _GlowRule extends StatelessWidget {
  const _GlowRule({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        height: 2,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [color.withValues(alpha: 0), color, color.withValues(alpha: 0)]),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 10)],
        ),
      ),
    );
  }
}
