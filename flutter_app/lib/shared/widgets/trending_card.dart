import 'package:flutter/material.dart';

import 'package:kryptox/core/theme/app_theme.dart';
import 'package:kryptox/core/utils/formatters.dart';
import 'package:kryptox/data/models/coin.dart';
import 'package:kryptox/shared/widgets/animated_price.dart';
import 'package:kryptox/shared/widgets/change_pill.dart';
import 'package:kryptox/shared/widgets/coin_avatar.dart';
import 'package:kryptox/shared/widgets/glass_card.dart';
import 'package:kryptox/shared/widgets/sparkline.dart';

/// Compact card for the horizontal "trending" carousel.
class TrendingCard extends StatelessWidget {
  const TrendingCard({super.key, required this.coin, required this.onTap, required this.heroPrefix});

  final Coin coin;
  final VoidCallback onTap;
  final String heroPrefix;

  @override
  Widget build(BuildContext context) {
    final color = KxColors.change(coin.change24h);
    return Semantics(
      container: true,
      button: true,
      label:
          '${coin.name}, ${coin.symbol}, price ${formatPrice(coin.price)}, '
          '24 hour change ${spokenChange(coin.change24h)}',
      child: SizedBox(
        width: 168,
        child: GlassCard(
          onTap: onTap,
          padding: const EdgeInsets.all(14),
          glow: color.withValues(alpha: 0.6),
          child: ExcludeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CoinAvatar(coin: coin, size: 28, heroTag: '$heroPrefix-${coin.id}'),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        coin.symbol,
                        style: KxText.display(14, weight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Scales down rather than overflowing the fixed-width card at large text sizes.
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: ChangePill(coin.change24h, size: 10, filled: false),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                SizedBox(
                  height: 36,
                  child: coin.sparkline.length > 1
                      ? RepaintBoundary(
                          child: Sparkline(values: coin.sparkline, color: color),
                        )
                      : null,
                ),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: AnimatedPrice(
                    value: coin.price,
                    style: KxText.mono(15, weight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
