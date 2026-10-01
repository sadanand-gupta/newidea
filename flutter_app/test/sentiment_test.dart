import 'package:flutter_test/flutter_test.dart';

import 'package:kryptox/data/models/coin.dart';
import 'package:kryptox/features/stats/sentiment.dart';

Coin _coin(double? change) => Coin(id: 'c$change', symbol: 'C', name: 'Coin', change24h: change);

void main() {
  group('Sentiment.fromInputs', () {
    test('has no score without any input', () {
      expect(Sentiment.fromInputs().score, isNull);
    });

    test('is neutral 50 for a flat market with balanced movers', () {
      expect(Sentiment.fromInputs(marketCapChange: 0, gainersAvg: 10, losersAvg: -10).score, 50);
    });

    test('adds momentum (6x the market-cap change) and mover balance', () {
      // 50 + 2 * 6 + (10 - 5) / 15 * 20
      expect(
        Sentiment.fromInputs(marketCapChange: 2, gainersAvg: 10, losersAvg: -5).score,
        closeTo(50 + 12 + 20 / 3, 1e-9),
      );
    });

    test('caps momentum at ±30 and the score at 0..100', () {
      expect(Sentiment.fromInputs(marketCapChange: 50).score, 80);
      expect(Sentiment.fromInputs(marketCapChange: -50, gainersAvg: -1, losersAvg: -9).score, 0);
      expect(Sentiment.fromInputs(marketCapChange: 50, gainersAvg: 5, losersAvg: 1).score, 100);
    });
  });

  test('Sentiment.estimate averages the top movers, ignoring missing changes', () {
    final s = Sentiment.estimate(
      GlobalStats(
        marketCapChange24h: 1,
        topGainers: [_coin(8), _coin(12), _coin(null)],
        topLosers: [_coin(-4), _coin(-6)],
      ),
    );
    expect(s.gainersAvg, 10);
    expect(s.losersAvg, -5);
    expect(s.marketCapChange, 1);
    expect(s.score, closeTo(50 + 6 + 20 / 3, 1e-9));
  });

  test('Sentiment.labelFor maps score bands to labels', () {
    expect(Sentiment.labelFor(10), 'Extreme Fear');
    expect(Sentiment.labelFor(25), 'Fear');
    expect(Sentiment.labelFor(50), 'Neutral');
    expect(Sentiment.labelFor(55), 'Greed');
    expect(Sentiment.labelFor(75), 'Extreme Greed');
  });
}
