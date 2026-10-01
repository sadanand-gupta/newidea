import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:kryptox/core/config.dart';
import 'package:kryptox/data/models/coin.dart';

class ApiException implements Exception {
  ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Where the data came from: 'live', 'cache' (stale, upstream failed) or 'mock'.
class ApiResult<T> {
  const ApiResult(this.data, this.source, this.updatedAt);

  final T data;
  final String source;
  final DateTime updatedAt;
}

enum CoinSort { marketCap, price, volume, change24h, change7d, name }

enum CoinFilter { all, top10, gainers, losers, stablecoins }

extension CoinSortX on CoinSort {
  String get apiValue => switch (this) {
    CoinSort.marketCap => 'market_cap',
    CoinSort.price => 'price',
    CoinSort.volume => 'volume',
    CoinSort.change24h => 'change_24h',
    CoinSort.change7d => 'change_7d',
    CoinSort.name => 'name',
  };

  String get label => switch (this) {
    CoinSort.marketCap => 'Market cap',
    CoinSort.price => 'Price',
    CoinSort.volume => '24h volume',
    CoinSort.change24h => '24h change',
    CoinSort.change7d => '7d change',
    CoinSort.name => 'Name',
  };
}

extension CoinFilterX on CoinFilter {
  String get label => switch (this) {
    CoinFilter.all => 'All',
    CoinFilter.top10 => 'Top 10',
    CoinFilter.gainers => 'Gainers',
    CoinFilter.losers => 'Losers',
    CoinFilter.stablecoins => 'Stablecoins',
  };
}

class ApiService {
  ApiService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      baseUrl = baseUrl ?? AppConfig.baseUrl;

  final http.Client _client;
  final String baseUrl;

  Future<dynamic> _send(String method, String path, [Map<String, String>? query]) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    const headers = {'Content-Type': 'application/json'};
    final http.Response resp;
    try {
      final request = switch (method) {
        'POST' => _client.post(uri, headers: headers),
        'DELETE' => _client.delete(uri, headers: headers),
        _ => _client.get(uri, headers: headers),
      };
      resp = await request.timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw ApiException('The server took too long to respond. Please try again.');
    } catch (_) {
      throw ApiException('Could not reach the server at $baseUrl.\nMake sure the backend is running.');
    }

    dynamic body;
    try {
      body = resp.body.isEmpty ? null : jsonDecode(resp.body);
    } on FormatException {
      throw ApiException('The server sent an invalid response (${resp.statusCode}).');
    }
    if (resp.statusCode >= 400) {
      final message = body is Map ? body['error'] : null;
      throw ApiException(message is String ? message : 'Server error (${resp.statusCode}).');
    }
    return body;
  }

  ApiResult<T> _wrap<T>(dynamic body, T Function(dynamic data) parse) {
    if (body is! Map) throw ApiException('The server sent an unexpected response.');
    final updated = (body['updated_at'] as num?)?.toInt();
    return ApiResult(
      parse(body['data']),
      body['source'] as String? ?? 'live',
      updated == null ? DateTime.now() : DateTime.fromMillisecondsSinceEpoch(updated * 1000),
    );
  }

  static List<Coin> _coins(dynamic data) => [for (final c in data as List) Coin.fromJson(c as Map<String, dynamic>)];

  Future<ApiResult<List<Coin>>> getCoins({
    String search = '',
    CoinFilter filter = CoinFilter.all,
    CoinSort sort = CoinSort.marketCap,
    bool descending = true,
  }) async {
    final body = await _send('GET', '/api/coins', {
      if (search.trim().isNotEmpty) 'search': search.trim(),
      'filter': filter.name,
      'sort': sort.apiValue,
      'order': descending ? 'desc' : 'asc',
    });
    return _wrap(body, _coins);
  }

  Future<ApiResult<CoinDetail>> getCoinDetail(String id) async {
    final body = await _send('GET', '/api/coins/${Uri.encodeComponent(id)}');
    return _wrap(body, (d) => CoinDetail.fromJson(d as Map<String, dynamic>));
  }

  Future<ApiResult<List<PricePoint>>> getChart(String id, int days) async {
    final body = await _send('GET', '/api/coins/${Uri.encodeComponent(id)}/chart', {'days': '$days'});
    return _wrap(body, (d) {
      final prices = (d as Map)['prices'] as List;
      return [
        for (final p in prices)
          PricePoint(DateTime.fromMillisecondsSinceEpoch((p[0] as num).toInt()), (p[1] as num).toDouble()),
      ];
    });
  }

  Future<ApiResult<GlobalStats>> getGlobalStats() async {
    final body = await _send('GET', '/api/global');
    return _wrap(body, (d) => GlobalStats.fromJson(d as Map<String, dynamic>));
  }

  Future<ApiResult<List<Coin>>> getWatchlist() async {
    final body = await _send('GET', '/api/watchlist');
    return _wrap(body, _coins);
  }

  static List<String> _ids(dynamic body) {
    final ids = body is Map ? body['ids'] : null;
    if (ids is! List) throw ApiException('The server sent an unexpected response.');
    return ids.whereType<String>().toList();
  }

  Future<List<String>> getWatchlistIds() async {
    final body = await _send('GET', '/api/watchlist/ids');
    return _ids(body);
  }

  Future<List<String>> addToWatchlist(String id) async {
    final body = await _send('POST', '/api/watchlist/${Uri.encodeComponent(id)}');
    return _ids(body);
  }

  Future<List<String>> removeFromWatchlist(String id) async {
    final body = await _send('DELETE', '/api/watchlist/${Uri.encodeComponent(id)}');
    return _ids(body);
  }
}
