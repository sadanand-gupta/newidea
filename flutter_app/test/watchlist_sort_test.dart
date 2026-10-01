import 'package:flutter_test/flutter_test.dart';
import 'package:kryptox/data/models/coin.dart';
import 'package:kryptox/features/watchlist/watchlist_sort.dart';

Coin _coin(String id, {double? price, double? change, double? cap}) =>
    Coin(id: id, symbol: id.toUpperCase(), name: id, price: price, change24h: change, marketCap: cap);

List<String> _ids(List<Coin> coins) => [for (final c in coins) c.id];

void main() {
  final coins = [
    _coin('a', price: 2, change: -1.5, cap: 300),
    _coin('b', price: null, change: 4.2, cap: null),
    _coin('c', price: 10, change: null, cap: 100),
    _coin('d', price: 5, change: 0.3, cap: 900),
  ];

  test('none keeps the original order', () {
    expect(_ids(WatchlistSort.none.apply(coins)), ['a', 'b', 'c', 'd']);
  });

  test('price sorts descending with nulls last', () {
    expect(_ids(WatchlistSort.price.apply(coins)), ['c', 'd', 'a', 'b']);
  });

  test('change sorts descending with nulls last', () {
    expect(_ids(WatchlistSort.change.apply(coins)), ['b', 'd', 'a', 'c']);
  });

  test('market cap sorts descending with nulls last', () {
    expect(_ids(WatchlistSort.marketCap.apply(coins)), ['d', 'a', 'c', 'b']);
  });

  test('returns a new list and leaves the input untouched', () {
    final sorted = WatchlistSort.price.apply(coins);
    expect(identical(sorted, coins), isFalse);
    expect(_ids(coins), ['a', 'b', 'c', 'd']);
  });
}
