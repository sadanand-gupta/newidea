import 'dart:math' as math;
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';

import 'package:kryptox/core/theme/app_theme.dart';
import 'package:kryptox/data/models/coin.dart';
import 'package:kryptox/features/coin_detail/open_coin.dart';
import 'package:kryptox/shared/shared.dart';

/// "Trending · Top 24h movers" header over a horizontal carousel of
/// [TrendingCard]s that slide in one after another.
class TrendingSection extends StatelessWidget {
  const TrendingSection({super.key, required this.coins, this.clip = false});

  static const String _heroPrefix = 'trend';

  final List<Coin> coins;

  /// Clip the carousel at its own edges (needed when it's narrower than the
  /// window, otherwise pre-built cards would paint beyond the column).
  final bool clip;

  @override
  Widget build(BuildContext context) {
    // Card content grows with the text scale; give the carousel room for it.
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final height = 164 + math.max(0.0, textScale - 1) * 48;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(KxLayout.gutter, 16, KxLayout.gutter, 0),
          child: SectionHeader(
            'Trending',
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.local_fire_department_rounded, size: 14, color: KxColors.warn),
                const SizedBox(width: 4),
                Text(
                  'Top 24h movers',
                  style: KxText.body(11, weight: FontWeight.w500, color: KxColors.textDim),
                ),
              ],
            ),
          ),
        ),
        SizedBox(
          height: height,
          // Let mouse/trackpad users drag the carousel too (web & desktop).
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(dragDevices: PointerDeviceKind.values.toSet()),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: clip ? Clip.hardEdge : Clip.none,
              padding: const EdgeInsets.fromLTRB(KxLayout.gutter, 4, KxLayout.gutter, 12),
              itemCount: coins.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final coin = coins[i];
                return Entrance(
                  key: ValueKey(coin.id),
                  index: i,
                  delay: const Duration(milliseconds: 80),
                  stagger: const Duration(milliseconds: 70),
                  duration: const Duration(milliseconds: 480),
                  offset: const Offset(0.25, 0),
                  child: TrendingCard(
                    coin: coin,
                    heroPrefix: _heroPrefix,
                    onTap: () => openCoin(context, coin, heroPrefix: _heroPrefix),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
