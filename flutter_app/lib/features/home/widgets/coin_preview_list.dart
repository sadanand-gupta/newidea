import 'package:flutter/material.dart';

import 'package:kryptox/data/models/coin.dart';
import 'package:kryptox/features/coin_detail/open_coin.dart';
import 'package:kryptox/shared/shared.dart';

/// Non-scrolling column of compact [CoinTile]s (no sparkline) for dashboard
/// previews. Each tile opens the coin's detail page.
class CoinPreviewList extends StatelessWidget {
  const CoinPreviewList({super.key, required this.coins, required this.heroPrefix});

  final Iterable<Coin> coins;

  /// Hero tag prefix, unique to the section (see [CoinTile.heroPrefix]).
  final String heroPrefix;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final coin in coins)
          CoinTile(
            coin: coin,
            heroPrefix: heroPrefix,
            showSparkline: false,
            onTap: () => openCoin(context, coin, heroPrefix: heroPrefix),
          ),
      ],
    );
  }
}
