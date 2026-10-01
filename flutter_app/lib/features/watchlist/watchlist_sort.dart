import 'package:kryptox/data/models/coin.dart';

/// Orderings offered by the watchlist's sort bar.
///
/// Every order except [none] is descending with missing values last;
/// [none] keeps the server's order.
enum WatchlistSort {
  none('Default'),
  price('Price'),
  change('24h %'),
  marketCap('Market cap');

  const WatchlistSort(this.label);

  /// Chip label shown in the sort bar.
  final String label;

  /// Returns a new list with [coins] in this order.
  List<Coin> apply(Iterable<Coin> coins) {
    final sorted = coins.toList();
    final key = _key;
    if (key != null) sorted.sort((a, b) => _descendingNullsLast(key(a), key(b)));
    return sorted;
  }

  double? Function(Coin)? get _key => switch (this) {
    none => null,
    price => (c) => c.price,
    change => (c) => c.change24h,
    marketCap => (c) => c.marketCap,
  };

  static int _descendingNullsLast(double? a, double? b) {
    if (a == null) return b == null ? 0 : 1;
    if (b == null) return -1;
    return b.compareTo(a);
  }
}
