import 'package:kryptox/models/coin.dart';
import 'package:kryptox/widgets/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatPrice', () {
    test('uses 2 decimals and separators for large prices', () {
      expect(formatPrice(64250.123), '\$64,250.12');
    });
    test('uses more decimals for small prices', () {
      expect(formatPrice(0.585), '\$0.5850');
      expect(formatPrice(0.0000178), '\$0.00001780');
    });
    test('handles null', () => expect(formatPrice(null), '—'));
  });

  test('formatCompact', () {
    expect(formatCompact(1.266e12), '\$1.27T');
    expect(formatCompact(28.4e9), '\$28.40B');
    expect(formatCompact(19.74e6, currency: false), '19.74M');
    expect(formatCompact(950), '\$950.00');
  });

  test('formatPercent', () {
    expect(formatPercent(1.844), '+1.84%');
    expect(formatPercent(-0.9), '-0.90%');
  });

  test('Coin.fromJson tolerates ints, nulls and missing fields', () {
    final coin = Coin.fromJson({
      'id': 'bitcoin',
      'symbol': 'btc',
      'name': 'Bitcoin',
      'current_price': 64000,
      'market_cap': null,
      'sparkline': [1, 2.5],
    });
    expect(coin.symbol, 'BTC');
    expect(coin.price, 64000.0);
    expect(coin.marketCap, isNull);
    expect(coin.sparkline, [1.0, 2.5]);
  });
}
