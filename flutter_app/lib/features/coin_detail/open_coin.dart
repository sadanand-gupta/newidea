import 'package:flutter/material.dart';

import 'package:kryptox/data/models/coin.dart';
import 'package:kryptox/features/coin_detail/coin_detail_screen.dart';

/// Opens the detail page for [coin]. [heroPrefix] must match the prefix the
/// calling list passed to CoinTile/TrendingCard so the logo Hero lines up.
void openCoin(BuildContext context, Coin coin, {required String heroPrefix}) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => CoinDetailScreen(coinId: coin.id, initial: coin, heroTag: '$heroPrefix-${coin.id}'),
    ),
  );
}
