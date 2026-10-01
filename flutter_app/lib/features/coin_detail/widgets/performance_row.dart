import 'package:flutter/material.dart';

import 'package:kryptox/core/theme/app_theme.dart';
import 'package:kryptox/core/utils/formatters.dart';
import 'package:kryptox/data/models/coin.dart';
import 'package:kryptox/shared/shared.dart';

/// Four tiles with the 24h / 7d / 30d / 1y change, tinted by direction.
class PerformanceRow extends StatelessWidget {
  const PerformanceRow({super.key, required this.detail});

  final CoinDetail detail;

  @override
  Widget build(BuildContext context) {
    final entries = <(String, double?)>[
      ('24H', detail.coin.change24h),
      ('7D', detail.coin.change7d),
      ('30D', detail.change30d),
      ('1Y', detail.change1y),
    ];
    return Row(
      children: [
        for (final (i, (label, value)) in entries.indexed) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Entrance(
              index: i,
              delay: const Duration(milliseconds: 200),
              stagger: const Duration(milliseconds: 70),
              duration: const Duration(milliseconds: 450),
              child: _PerfTile(label: label, value: value),
            ),
          ),
        ],
      ],
    );
  }
}

class _PerfTile extends StatelessWidget {
  const _PerfTile({required this.label, required this.value});

  final String label;
  final double? value;

  @override
  Widget build(BuildContext context) {
    final color = KxColors.change(value);
    return GlassCard(
      radius: KxLayout.radiusTile,
      padding: EdgeInsets.zero,
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.16), Colors.white.withValues(alpha: 0.02)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Glowing accent line along the top edge.
          Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color.withValues(alpha: 0), color, color.withValues(alpha: 0)]),
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.7), blurRadius: 10)],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 10, 6, 12),
            child: Column(
              children: [
                Text(label, style: KxText.label(10, color: KxColors.textMuted)),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    formatPercent(value),
                    maxLines: 1,
                    style: KxText.mono(13, weight: FontWeight.w700, color: color),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
