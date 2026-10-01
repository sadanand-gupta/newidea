import 'package:flutter/material.dart';

import 'package:kryptox/core/theme/app_theme.dart';
import 'package:kryptox/core/utils/formatters.dart';
import 'package:kryptox/data/models/coin.dart';
import 'package:kryptox/shared/shared.dart';

/// Hero card of the dashboard: total market cap with its 24h change, plus
/// volume, BTC dominance and coin count. Tapping it opens the stats tab.
class MarketSnapshotCard extends StatelessWidget {
  const MarketSnapshotCard({super.key, required this.stats, required this.onTap});

  final GlobalStats stats;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final change = stats.marketCapChange24h;
    final btc = stats.dominance['BTC'];
    return MergeSemantics(
      child: Semantics(
        button: true,
        hint: 'Opens market stats',
        child: GlassCard(
          onTap: onTap,
          radius: KxLayout.radiusHero,
          glow: KxColors.change(change),
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              KxColors.cyan.withValues(alpha: 0.12),
              KxColors.violet.withValues(alpha: 0.08),
              Colors.white.withValues(alpha: 0.02),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'GLOBAL MARKET CAP',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: KxText.label(11),
                    ),
                  ),
                  const Icon(Icons.arrow_outward_rounded, size: 18, color: KxColors.textMuted),
                ],
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: AnimatedPrice(
                  value: stats.totalMarketCap,
                  compact: true,
                  style: KxText.mono(34, weight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ChangePill(change, size: 12),
                  Text('in the last 24h', style: KxText.body(12, color: KxColors.textDim)),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 14),
              _StatRow(
                children: [
                  StatTile(framed: false, label: '24h volume', value: formatCompact(stats.totalVolume)),
                  StatTile(
                    framed: false,
                    label: 'BTC dominance',
                    value: btc == null ? '—' : '${btc.toStringAsFixed(1)}%',
                  ),
                  StatTile(framed: false, label: 'Coins', value: formatNumber(stats.activeCryptocurrencies)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Loading placeholder with the same outline as [MarketSnapshotCard].
class MarketSnapshotSkeleton extends StatelessWidget {
  const MarketSnapshotSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading market data',
      child: const ExcludeSemantics(
        child: Shimmer(
          child: GlassCard(
            radius: KxLayout.radiusHero,
            padding: EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 120, height: 10),
                SizedBox(height: 12),
                SkeletonBox(width: 180, height: 30),
                SizedBox(height: 10),
                SkeletonBox(width: 90, height: 18),
                SizedBox(height: 20),
                _StatRow(children: [_StatPlaceholder(), _StatPlaceholder(), _StatPlaceholder()]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Label + value placeholder standing in for one [StatTile].
class _StatPlaceholder extends StatelessWidget {
  const _StatPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [SkeletonBox(width: 60, height: 9), SizedBox(height: 8), SkeletonBox(width: 70, height: 14)],
    );
  }
}

/// Equal-width columns separated by a 12px gap.
class _StatRow extends StatelessWidget {
  const _StatRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, child) in children.indexed) ...[if (i > 0) const SizedBox(width: 12), Expanded(child: child)],
      ],
    );
  }
}
