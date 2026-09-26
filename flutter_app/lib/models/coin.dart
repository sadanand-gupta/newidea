double? _d(Object? v) => (v as num?)?.toDouble();

DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v) : null;

/// A coin as it appears in market lists.
class Coin {
  const Coin({
    required this.id,
    required this.symbol,
    required this.name,
    this.image,
    this.rank,
    this.price,
    this.marketCap,
    this.volume,
    this.high24h,
    this.low24h,
    this.change24h,
    this.change7d,
    this.circulatingSupply,
    this.totalSupply,
    this.maxSupply,
    this.sparkline = const [],
  });

  final String id;
  final String symbol;
  final String name;
  final String? image;
  final int? rank;
  final double? price;
  final double? marketCap;
  final double? volume;
  final double? high24h;
  final double? low24h;
  final double? change24h;
  final double? change7d;
  final double? circulatingSupply;
  final double? totalSupply;
  final double? maxSupply;
  final List<double> sparkline;

  factory Coin.fromJson(Map<String, dynamic> j) => Coin(
        id: j['id'] as String,
        symbol: (j['symbol'] as String? ?? '').toUpperCase(),
        name: j['name'] as String? ?? '',
        image: j['image'] as String?,
        rank: (j['market_cap_rank'] as num?)?.toInt(),
        price: _d(j['current_price']),
        marketCap: _d(j['market_cap']),
        volume: _d(j['total_volume']),
        high24h: _d(j['high_24h']),
        low24h: _d(j['low_24h']),
        change24h: _d(j['price_change_percentage_24h']),
        change7d: _d(j['price_change_percentage_7d']),
        circulatingSupply: _d(j['circulating_supply']),
        totalSupply: _d(j['total_supply']),
        maxSupply: _d(j['max_supply']),
        sparkline: [
          for (final v in (j['sparkline'] as List? ?? const [])) if (v is num) v.toDouble(),
        ],
      );
}

/// Full research data for a single coin.
class CoinDetail {
  const CoinDetail({
    required this.coin,
    this.change30d,
    this.change1y,
    this.fullyDilutedValuation,
    this.ath,
    this.athChange,
    this.athDate,
    this.atl,
    this.atlDate,
    this.description = '',
    this.homepage,
    this.categories = const [],
  });

  final Coin coin;
  final double? change30d;
  final double? change1y;
  final double? fullyDilutedValuation;
  final double? ath;
  final double? athChange;
  final DateTime? athDate;
  final double? atl;
  final DateTime? atlDate;
  final String description;
  final String? homepage;
  final List<String> categories;

  factory CoinDetail.fromJson(Map<String, dynamic> j) => CoinDetail(
        coin: Coin.fromJson(j),
        change30d: _d(j['price_change_percentage_30d']),
        change1y: _d(j['price_change_percentage_1y']),
        fullyDilutedValuation: _d(j['fully_diluted_valuation']),
        ath: _d(j['ath']),
        athChange: _d(j['ath_change_percentage']),
        athDate: _date(j['ath_date']),
        atl: _d(j['atl']),
        atlDate: _date(j['atl_date']),
        description: j['description'] as String? ?? '',
        homepage: j['homepage'] as String?,
        categories: (j['categories'] as List? ?? const []).whereType<String>().toList(),
      );
}

class PricePoint {
  const PricePoint(this.time, this.price);

  final DateTime time;
  final double price;
}

class GlobalStats {
  const GlobalStats({
    this.totalMarketCap,
    this.totalVolume,
    this.marketCapChange24h,
    this.activeCryptocurrencies,
    this.markets,
    this.dominance = const {},
    this.topGainers = const [],
    this.topLosers = const [],
    this.topVolume = const [],
  });

  final double? totalMarketCap;
  final double? totalVolume;
  final double? marketCapChange24h;
  final int? activeCryptocurrencies;
  final int? markets;

  /// Symbol (upper case) -> share of total market cap in percent.
  final Map<String, double> dominance;
  final List<Coin> topGainers;
  final List<Coin> topLosers;
  final List<Coin> topVolume;

  factory GlobalStats.fromJson(Map<String, dynamic> j) {
    List<Coin> coins(String key) =>
        [for (final c in (j[key] as List? ?? const [])) Coin.fromJson(c as Map<String, dynamic>)];
    final dom = <String, double>{
      for (final e in (j['market_cap_percentage'] as Map? ?? const {}).entries)
        if (e.value is num) '${e.key}'.toUpperCase(): (e.value as num).toDouble(),
    };
    final sorted = dom.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return GlobalStats(
      totalMarketCap: _d(j['total_market_cap']),
      totalVolume: _d(j['total_volume']),
      marketCapChange24h: _d(j['market_cap_change_percentage_24h']),
      activeCryptocurrencies: (j['active_cryptocurrencies'] as num?)?.toInt(),
      markets: (j['markets'] as num?)?.toInt(),
      dominance: Map.fromEntries(sorted),
      topGainers: coins('top_gainers'),
      topLosers: coins('top_losers'),
      topVolume: coins('top_volume'),
    );
  }
}
