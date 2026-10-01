import 'package:flutter/foundation.dart';

import 'package:kryptox/data/models/coin.dart';

/// A fear & greed *style* market sentiment score (0-100), estimated
/// client-side from global market data. Not an official index.
///
/// The score is `50 ± market-cap momentum (±30) ± top-mover balance (±20)`:
/// * momentum: the 24h market-cap change × 6, capped at ±30;
/// * balance: how far the average top-gainer move outweighs the average
///   top-loser move (or vice versa), scaled to ±20.
@immutable
class Sentiment {
  const Sentiment({this.score, this.marketCapChange, this.gainersAvg, this.losersAvg});

  /// Estimates sentiment from the inputs directly. [score] is null when every
  /// input is missing, rather than a misleading "Neutral 50".
  factory Sentiment.fromInputs({double? marketCapChange, double? gainersAvg, double? losersAvg}) {
    if (marketCapChange == null && gainersAvg == null && losersAvg == null) return const Sentiment();
    final momentum = ((marketCapChange ?? 0) * 6).clamp(-30.0, 30.0);
    final g = gainersAvg ?? 0, l = losersAvg ?? 0;
    final spread = g.abs() + l.abs();
    final balance = spread == 0 ? 0.0 : (g + l) / spread * 20;
    return Sentiment(
      score: (50 + momentum + balance).clamp(0.0, 100.0),
      marketCapChange: marketCapChange,
      gainersAvg: gainersAvg,
      losersAvg: losersAvg,
    );
  }

  /// Estimates sentiment from [stats]' 24h market-cap change and the average
  /// 24h move of its top gainers and losers.
  factory Sentiment.estimate(GlobalStats stats) => Sentiment.fromInputs(
    marketCapChange: stats.marketCapChange24h,
    gainersAvg: _averageChange(stats.topGainers),
    losersAvg: _averageChange(stats.topLosers),
  );

  /// How the estimate is made, for display next to the score.
  static const methodNote =
      'Estimated in-app from the 24h market-cap change and the average move of '
      'the top gainers and losers. This is not the Crypto Fear & Greed Index or any official '
      'index, and not financial advice.';

  /// 0 (extreme fear) to 100 (extreme greed); null when there is no data.
  final double? score;

  /// 24h change of the total market cap, in percent.
  final double? marketCapChange;

  /// Average 24h change of the top gainers, in percent.
  final double? gainersAvg;

  /// Average 24h change of the top losers, in percent.
  final double? losersAvg;

  /// Human label for a [score] ("Extreme Fear" … "Extreme Greed").
  static String labelFor(double score) => switch (score) {
    < 25 => 'Extreme Fear',
    < 45 => 'Fear',
    < 55 => 'Neutral',
    < 75 => 'Greed',
    _ => 'Extreme Greed',
  };

  static double? _averageChange(List<Coin> coins) {
    final changes = coins.map((c) => c.change24h).whereType<double>().toList();
    return changes.isEmpty ? null : changes.reduce((a, b) => a + b) / changes.length;
  }
}
