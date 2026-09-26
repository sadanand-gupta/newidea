/// Offline mock data, served when the live API is unreachable or rate-limited.
library;

import 'dart:math';

// id, symbol, name, price, marketCap, volume, change24h, change7d, circulating, total, max
const _coins = <List<Object?>>[
  ['bitcoin', 'btc', 'Bitcoin', 64250.12, 1266e9, 28.4e9, 1.84, 4.12, 19.74e6, 21e6, 21e6],
  ['ethereum', 'eth', 'Ethereum', 3120.55, 375e9, 14.2e9, -0.92, 2.35, 120.2e6, 120.2e6, null],
  ['tether', 'usdt', 'Tether', 1.0, 118e9, 52e9, 0.01, -0.02, 118e9, 118e9, null],
  ['binancecoin', 'bnb', 'BNB', 585.30, 85.4e9, 1.8e9, 0.44, -1.20, 145.9e6, 145.9e6, 200e6],
  ['solana', 'sol', 'Solana', 148.20, 69.3e9, 3.1e9, 4.71, 11.02, 467.6e6, 580e6, null],
  ['usd-coin', 'usdc', 'USDC', 1.0, 34.1e9, 6.4e9, -0.01, 0.00, 34.1e9, 34.1e9, null],
  ['ripple', 'xrp', 'XRP', 0.585, 32.8e9, 1.25e9, -2.15, -4.80, 56e9, 99.99e9, 100e9],
  ['dogecoin', 'doge', 'Dogecoin', 0.1215, 17.7e9, 890e6, 6.32, 9.45, 145.5e9, 145.5e9, null],
  ['cardano', 'ada', 'Cardano', 0.382, 13.6e9, 310e6, -1.05, -3.10, 35.7e9, 45e9, 45e9],
  ['tron', 'trx', 'TRON', 0.158, 13.8e9, 420e6, 0.75, 2.05, 86.9e9, 86.9e9, null],
  ['avalanche-2', 'avax', 'Avalanche', 27.40, 11.1e9, 380e6, 3.12, 7.60, 405e6, 446e6, 720e6],
  ['chainlink', 'link', 'Chainlink', 12.85, 7.8e9, 290e6, -3.40, 1.10, 608e6, 1e9, 1e9],
  ['polkadot', 'dot', 'Polkadot', 4.62, 6.7e9, 170e6, -0.35, -6.25, 1.45e9, 1.5e9, null],
  ['litecoin', 'ltc', 'Litecoin', 68.90, 5.17e9, 360e6, 1.25, 0.40, 75e6, 84e6, 84e6],
  ['shiba-inu', 'shib', 'Shiba Inu', 0.0000178, 10.5e9, 320e6, 8.90, 15.30, 589e12, 589.5e12, null],
  ['uniswap', 'uni', 'Uniswap', 7.35, 4.4e9, 120e6, -4.60, -8.10, 600e6, 1e9, 1e9],
  ['near', 'near', 'NEAR Protocol', 4.95, 5.4e9, 260e6, 2.20, 5.75, 1.09e9, 1.21e9, null],
  ['aptos', 'apt', 'Aptos', 6.80, 3.3e9, 110e6, -2.80, -1.90, 485e6, 1.1e9, null],
  ['stellar', 'xlm', 'Stellar', 0.094, 2.75e9, 60e6, 0.15, -2.40, 29.3e9, 50e9, 50e9],
  ['monero', 'xmr', 'Monero', 165.40, 3.05e9, 70e6, 1.65, 3.30, 18.44e6, 18.44e6, null],
];

const _descriptions = {
  'bitcoin': 'Bitcoin is the first decentralized cryptocurrency, created in 2009 by Satoshi Nakamoto. '
      'It uses proof-of-work and has a fixed supply of 21 million coins.',
  'ethereum': 'Ethereum is a programmable blockchain that runs smart contracts. It moved to '
      'proof-of-stake in 2022 and hosts most DeFi and NFT activity.',
  'solana': 'Solana is a high-throughput layer-1 blockchain that combines proof-of-stake with '
      'proof-of-history to reach fast, low-cost transactions.',
};

/// Stable string hash (FNV-1a) so every coin gets the same mock chart each run.
int _seed(String s) {
  var h = 0x811c9dc5;
  for (final c in s.codeUnits) {
    h = ((h ^ c) * 0x01000193) & 0xffffffff;
  }
  return h;
}

double _gauss(Random r) => sqrt(-2 * log(1 - r.nextDouble())) * cos(2 * pi * r.nextDouble());

/// Random walk that ends exactly at [endPrice].
List<double> _randomWalk(String seed, double endPrice, int points, double volatility) {
  final r = Random(_seed(seed));
  final values = <double>[1.0];
  for (var i = 1; i < points; i++) {
    values.add(values.last * (1 + _gauss(r) * volatility));
  }
  final scale = endPrice / values.last;
  return [for (final v in values) v * scale];
}

String _icon(String symbol) =>
    'https://cdn.jsdelivr.net/gh/spothq/cryptocurrency-icons@master/128/color/$symbol.png';

List<Map<String, dynamic>> mockMarkets() {
  return [
    for (var i = 0; i < _coins.length; i++) _marketFromRow(_coins[i], i + 1),
  ];
}

Map<String, dynamic> _marketFromRow(List<Object?> row, int rank) {
  final id = row[0] as String, symbol = row[1] as String;
  final price = (row[3] as num).toDouble();
  final change24h = (row[6] as num).toDouble();
  return {
    'id': id,
    'symbol': symbol,
    'name': row[2],
    'image': _icon(symbol),
    'current_price': price,
    'market_cap': row[4],
    'market_cap_rank': rank,
    'total_volume': row[5],
    'high_24h': price * (1 + change24h.abs() / 100 + 0.01),
    'low_24h': price * (1 - change24h.abs() / 100 - 0.01),
    'price_change_percentage_24h': change24h,
    'price_change_percentage_7d': row[7],
    'circulating_supply': row[8],
    'total_supply': row[9],
    'max_supply': row[10],
    'sparkline': _randomWalk('$id-spark', price, 168, 0.006),
  };
}

Map<String, dynamic>? _findCoin(String id) {
  for (final c in mockMarkets()) {
    if (c['id'] == id) return c;
  }
  return null;
}

Map<String, dynamic>? mockCoinDetail(String id) {
  final coin = _findCoin(id);
  if (coin == null) return null;
  final price = coin['current_price'] as double;
  final change7d = (coin['price_change_percentage_7d'] as num).toDouble();
  final supply = (coin['max_supply'] ?? coin['total_supply'] ?? coin['circulating_supply']) as num;
  return {
    ...coin,
    'description': _descriptions[id] ??
        '${coin['name']} (${(coin['symbol'] as String).toUpperCase()}) is a cryptocurrency. '
            'This is mock data shown because the live API is unavailable.',
    'homepage': null,
    'categories': ['Cryptocurrency'],
    'genesis_date': null,
    'ath': price * 1.45,
    'ath_change_percentage': -31.0,
    'ath_date': '2024-03-14T00:00:00Z',
    'atl': price * 0.02,
    'atl_date': '2015-01-14T00:00:00Z',
    'fully_diluted_valuation': price * supply,
    'price_change_percentage_30d': change7d * 1.8,
    'price_change_percentage_1y': change7d * 9.5,
  };
}

List<List<num>>? mockChart(String id, int days) {
  final coin = _findCoin(id);
  if (coin == null) return null;
  final points = days <= 1 ? 288 : (days <= 30 ? min(days * 24, 400) : min(days, 400));
  final volatility = days <= 1 ? 0.003 : (days <= 30 ? 0.008 : 0.025);
  final prices = _randomWalk('$id-$days', coin['current_price'] as double, points, volatility);
  final now = DateTime.now().millisecondsSinceEpoch;
  final step = days * 86400000 / (points - 1);
  return [
    for (var i = 0; i < points; i++) [now - (points - 1 - i) * step, prices[i]],
  ];
}

Map<String, dynamic> mockGlobal() {
  final coins = mockMarkets();
  final totalCap = coins.fold<num>(0, (s, c) => s + (c['market_cap'] as num)) / 0.92;
  final totalVol = coins.fold<num>(0, (s, c) => s + (c['total_volume'] as num)) / 0.9;
  return {
    'active_cryptocurrencies': 14872,
    'markets': 1183,
    'total_market_cap': totalCap,
    'total_volume': totalVol,
    'market_cap_change_percentage_24h': 1.37,
    'market_cap_percentage': {
      for (final c in coins.take(8)) c['symbol']: (c['market_cap'] as num) / totalCap * 100,
    },
  };
}
