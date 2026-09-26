/// CoinGecko client with a TTL cache and normalisation into the app's own
/// JSON shapes, so the Flutter app never depends on CoinGecko's raw format.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

class NotFound implements Exception {}

typedef Fetched = ({dynamic data, String source});

class CoinGecko {
  CoinGecko({this.apiKey, this.mockOnly = false});

  static const _base = 'https://api.coingecko.com/api/v3';
  final String? apiKey;
  final bool mockOnly;
  final _client = http.Client();
  final _cache = <String, (DateTime, dynamic)>{};

  /// Returns live data (or stale cache on failure), or null when unavailable
  /// so the caller can fall back to mock data. Throws [NotFound] on 404.
  Future<Fetched?> get(String path, Map<String, String> params, Duration ttl) async {
    if (mockOnly) return null;
    final uri = Uri.parse('$_base$path').replace(queryParameters: params.isEmpty ? null : params);
    final key = uri.toString();
    final cached = _cache[key];
    if (cached != null && DateTime.now().difference(cached.$1) < ttl) {
      return (data: cached.$2, source: 'live');
    }
    try {
      final resp = await _client
          .get(uri, headers: {if (apiKey != null) 'x-cg-demo-api-key': apiKey!})
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 404) throw NotFound();
      if (resp.statusCode != 200) throw Exception('HTTP ${resp.statusCode}');
      final data = jsonDecode(resp.body);
      _cache[key] = (DateTime.now(), data);
      return (data: data, source: 'live');
    } on NotFound {
      rethrow;
    } catch (_) {
      if (cached != null) return (data: cached.$2, source: 'cache');
      return null;
    }
  }
}

Map<String, dynamic> normalizeMarket(Map<String, dynamic> c) => {
      'id': c['id'],
      'symbol': c['symbol'] ?? '',
      'name': c['name'] ?? '',
      'image': c['image'],
      'current_price': c['current_price'],
      'market_cap': c['market_cap'],
      'market_cap_rank': c['market_cap_rank'],
      'total_volume': c['total_volume'],
      'high_24h': c['high_24h'],
      'low_24h': c['low_24h'],
      'price_change_percentage_24h':
          c['price_change_percentage_24h_in_currency'] ?? c['price_change_percentage_24h'],
      'price_change_percentage_7d': c['price_change_percentage_7d_in_currency'],
      'circulating_supply': c['circulating_supply'],
      'total_supply': c['total_supply'],
      'max_supply': c['max_supply'],
      'sparkline': (c['sparkline_in_7d'] as Map?)?['price'] ?? const [],
    };

Map<String, dynamic> normalizeDetail(Map<String, dynamic> c) {
  final md = (c['market_data'] as Map?) ?? const {};
  dynamic usd(String field) => (md[field] as Map?)?['usd'];
  final desc = ((c['description'] as Map?)?['en'] as String?) ?? '';
  // First paragraph only, with the HTML links CoinGecko embeds stripped out.
  final plain = desc.split('\r\n\r\n').first.replaceAll(RegExp(r'<[^>]*>'), '').trim();
  final homepages = ((c['links'] as Map?)?['homepage'] as List?) ?? const [];
  return {
    'id': c['id'],
    'symbol': c['symbol'] ?? '',
    'name': c['name'] ?? '',
    'image': (c['image'] as Map?)?['large'],
    'current_price': usd('current_price'),
    'market_cap': usd('market_cap'),
    'market_cap_rank': c['market_cap_rank'],
    'total_volume': usd('total_volume'),
    'high_24h': usd('high_24h'),
    'low_24h': usd('low_24h'),
    'price_change_percentage_24h': md['price_change_percentage_24h'],
    'price_change_percentage_7d': md['price_change_percentage_7d'],
    'price_change_percentage_30d': md['price_change_percentage_30d'],
    'price_change_percentage_1y': md['price_change_percentage_1y'],
    'circulating_supply': md['circulating_supply'],
    'total_supply': md['total_supply'],
    'max_supply': md['max_supply'],
    'fully_diluted_valuation': usd('fully_diluted_valuation'),
    'ath': usd('ath'),
    'ath_change_percentage': usd('ath_change_percentage'),
    'ath_date': usd('ath_date'),
    'atl': usd('atl'),
    'atl_date': usd('atl_date'),
    'description': plain.length > 1200 ? '${plain.substring(0, 1200)}…' : plain,
    'homepage': homepages.cast<String?>().firstWhere((h) => h != null && h.isNotEmpty, orElse: () => null),
    'categories': ((c['categories'] as List?) ?? const []).whereType<String>().take(5).toList(),
    'genesis_date': c['genesis_date'],
    'sparkline': const [],
  };
}
