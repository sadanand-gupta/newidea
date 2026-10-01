import 'package:kryptox/data/models/coin.dart';

/// Ticker-tape and trending picks derived client-side from one unfiltered
/// market list.
class MarketHighlights {
  const MarketHighlights._(this.tape, this.trending);

  /// Nothing to highlight (no market data yet).
  static const empty = MarketHighlights._([], []);

  /// Builds highlights from [coins]: the tape holds the top [tapeSize] by
  /// rank, trending the [trendingSize] biggest 24h movers in either direction.
  factory MarketHighlights.from(List<Coin> coins, {int tapeSize = 15, int trendingSize = 5}) {
    if (coins.isEmpty) return empty;
    const noRank = 1 << 30;
    final byRank = [...coins]..sort((a, b) => (a.rank ?? noRank).compareTo(b.rank ?? noRank));
    final movers = coins.where((c) => c.change24h != null).toList()
      ..sort((a, b) => b.change24h!.abs().compareTo(a.change24h!.abs()));
    return MarketHighlights._(byRank.take(tapeSize).toList(), movers.take(trendingSize).toList());
  }

  final List<Coin> tape;
  final List<Coin> trending;
}
