import 'package:flutter/material.dart';

import 'package:kryptox/core/theme/app_theme.dart';
import 'package:kryptox/core/utils/formatters.dart';
import 'package:kryptox/data/models/coin.dart';
import 'package:kryptox/shared/shared.dart';

/// Circulating / total / max supply, plus how much of the max is already in
/// circulation when the coin has a cap.
class SupplyCard extends StatelessWidget {
  const SupplyCard({super.key, required this.coin});

  final Coin coin;

  @override
  Widget build(BuildContext context) {
    final circulating = coin.circulatingSupply;
    final max = coin.maxSupply;
    final ratio = (circulating != null && max != null && max > 0)
        ? (circulating / max).clamp(0.0, 1.0).toDouble()
        : null;
    final unit = coin.symbol.isEmpty ? '' : ' ${coin.symbol}';

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SupplyRow(label: 'Circulating', value: circulating, unit: unit, dot: KxColors.cyan),
          _SupplyRow(label: 'Total', value: coin.totalSupply, unit: unit, dot: KxColors.violet),
          // CoinGecko reports max_supply as null for uncapped coins (e.g. ETH).
          _SupplyRow(label: 'Max', value: max, unit: unit, dot: KxColors.magenta, missing: '∞  No fixed cap'),
          const SizedBox(height: 14),
          if (ratio != null)
            _SupplyProgress(ratio: ratio)
          else
            Text(
              circulating == null
                  ? 'Circulating supply not reported.'
                  : 'No fixed maximum supply, so there is no circulation progress to show.',
              style: KxText.body(12, color: KxColors.textDim),
            ),
        ],
      ),
    );
  }
}

/// Coloured dot, label and right-aligned amount.
class _SupplyRow extends StatelessWidget {
  const _SupplyRow({
    required this.label,
    required this.value,
    required this.unit,
    required this.dot,
    this.missing = '—',
  });

  final String label;
  final double? value;

  /// Symbol suffix (" BTC"), or empty.
  final String unit;
  final Color dot;

  /// Shown when [value] is null.
  final String missing;

  @override
  Widget build(BuildContext context) {
    final value = this.value;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: dot,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: dot.withValues(alpha: 0.6), blurRadius: 6)],
            ),
          ),
          const SizedBox(width: 10),
          // Label and value share the row 2:3 so the values form a clean
          // right-aligned column regardless of label length.
          Expanded(
            flex: 2,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: KxText.body(13, color: KxColors.textDim),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  value == null ? missing : '${formatNumber(value)}$unit',
                  maxLines: 1,
                  style: KxText.mono(
                    13,
                    weight: FontWeight.w600,
                    color: value == null ? KxColors.textMuted : KxColors.text,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated "circulating / max" gauge.
class _SupplyProgress extends StatelessWidget {
  const _SupplyProgress({required this.ratio});

  final double ratio;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: ratio),
      duration: const Duration(milliseconds: 1700),
      // Leading interval lets the section's entrance finish before filling.
      curve: const Interval(0.25, 1, curve: Curves.easeOutCubic),
      builder: (context, v, _) {
        final fill = v.clamp(0.0, 1.0).toDouble();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'CIRCULATING / MAX',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KxText.label(10, color: KxColors.textMuted),
                  ),
                ),
                GradientText('${(fill * 100).toStringAsFixed(1)}%', style: KxText.mono(15, weight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              height: 10,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: KxColors.border),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: fill,
                  // Without this the childless DecoratedBox gets loose height
                  // constraints from Align and collapses to 0px tall.
                  heightFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: KxColors.brandGradient,
                      borderRadius: BorderRadius.circular(5),
                      boxShadow: [BoxShadow(color: KxColors.cyan.withValues(alpha: 0.5), blurRadius: 10)],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${(ratio * 100).toStringAsFixed(1)}% of max supply in circulation',
              style: KxText.body(11, color: KxColors.textMuted),
            ),
          ],
        );
      },
    );
  }
}
