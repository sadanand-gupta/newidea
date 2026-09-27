// KryptoX backend: shelf server over CoinGecko with caching, mock fallback,
// server-side search/filter/sort and a persisted watchlist.
//
// Run:  dart run bin/server.dart
// Env:  PORT=8080                 port to listen on (default 8080)
//       USE_MOCK=1                always serve mock data (no network)
//       COINGECKO_API_KEY=...     optional CoinGecko demo key (higher rate limit)

import 'dart:convert';
import 'dart:io';

import 'package:kryptox_backend/coingecko.dart';
import 'package:kryptox_backend/mock_data.dart';
import 'package:kryptox_backend/user.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';

final _env = Platform.environment;
final _api = CoinGecko(apiKey: _env['COINGECKO_API_KEY'], mockOnly: _env['USE_MOCK'] == '1');
final _watchlistFile = File('watchlist.json');
final _userStore = UserStore(file: File('users.json'));

Response _json(Object? body, {int status = 200}) => Response(
      status,
      body: jsonEncode(body),
      headers: {'content-type': 'application/json'},
    );

Response _envelope(Object? data, String source) => _json({
      'source': source,
      'updated_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'data': data,
    });

Response _error(int status, String message) => _json({'error': message}, status: status);

Future<(List<Map<String, dynamic>>, String)> _markets() async {
  final got = await _api.get('/coins/markets', {
    'vs_currency': 'usd',
    'order': 'market_cap_desc',
    'per_page': '100',
    'page': '1',
    'sparkline': 'true',
    'price_change_percentage': '24h,7d',
  }, const Duration(seconds: 60));
  if (got == null) return (mockMarkets(), 'mock');
  final list = (got.data as List).cast<Map<String, dynamic>>().map(normalizeMarket).toList();
  return (list, got.source);
}

num? _num(Map<String, dynamic> c, String field) => c[field] as num?;

const _sortFields = {
  'market_cap': 'market_cap',
  'price': 'current_price',
  'volume': 'total_volume',
  'change_24h': 'price_change_percentage_24h',
  'change_7d': 'price_change_percentage_7d',
};

Future<Response> _listCoins(Request req) async {
  final q = req.url.queryParameters;
  final search = (q['search'] ?? '').trim().toLowerCase();
  final filter = q['filter'] ?? 'all';
  final sort = q['sort'] ?? 'market_cap';
  final desc = (q['order'] ?? 'desc') == 'desc';
  if (sort != 'name' && !_sortFields.containsKey(sort)) return _error(400, 'Invalid sort: $sort');

  var (coins, source) = await _markets();

  if (search.isNotEmpty) {
    coins = coins
        .where((c) =>
            (c['name'] as String).toLowerCase().contains(search) ||
            (c['symbol'] as String).toLowerCase().contains(search))
        .toList();
  }

  double change(Map<String, dynamic> c) => (_num(c, 'price_change_percentage_24h') ?? 0).toDouble();
  coins = switch (filter) {
    'gainers' => coins.where((c) => change(c) > 0).toList(),
    'losers' => coins.where((c) => change(c) < 0).toList(),
    'top10' => coins.where((c) => (_num(c, 'market_cap_rank') ?? 999) <= 10).toList(),
    'stablecoins' => coins.where((c) {
        final p = _num(c, 'current_price');
        return p != null && p >= 0.97 && p <= 1.03 && change(c).abs() < 1;
      }).toList(),
    _ => coins,
  };

  if (sort == 'name') {
    coins.sort((a, b) => (a['name'] as String).toLowerCase().compareTo((b['name'] as String).toLowerCase()));
    if (desc) coins = coins.reversed.toList();
  } else {
    // Coins missing the sort value always sink to the bottom, whatever the direction.
    final field = _sortFields[sort]!;
    final present = coins.where((c) => c[field] != null).toList();
    final missing = coins.where((c) => c[field] == null);
    present.sort((a, b) => desc ? _num(b, field)!.compareTo(_num(a, field)!) : _num(a, field)!.compareTo(_num(b, field)!));
    coins = [...present, ...missing];
  }
  return _envelope(coins, source);
}

Future<Response> _coinDetail(Request req, String id) async {
  try {
    final got = await _api.get('/coins/$id', {
      'localization': 'false',
      'tickers': 'false',
      'community_data': 'false',
      'developer_data': 'false',
      'sparkline': 'false',
    }, const Duration(minutes: 2));
    if (got != null) return _envelope(normalizeDetail(got.data as Map<String, dynamic>), got.source);
  } on NotFound {
    return _error(404, 'Coin not found');
  }
  final detail = mockCoinDetail(id);
  return detail == null ? _error(404, 'Coin not found (mock mode)') : _envelope(detail, 'mock');
}

Future<Response> _coinChart(Request req, String id) async {
  final days = req.url.queryParameters['days'] ?? '7';
  if (!const ['1', '7', '30', '90', '365'].contains(days)) return _error(400, 'days must be 1, 7, 30, 90 or 365');
  try {
    final got = await _api.get('/coins/$id/market_chart', {'vs_currency': 'usd', 'days': days}, const Duration(minutes: 5));
    if (got != null) {
      return _envelope({'days': int.parse(days), 'prices': (got.data as Map)['prices'] ?? []}, got.source);
    }
  } on NotFound {
    return _error(404, 'Coin not found');
  }
  final prices = mockChart(id, int.parse(days));
  return prices == null
      ? _error(404, 'Coin not found (mock mode)')
      : _envelope({'days': int.parse(days), 'prices': prices}, 'mock');
}

Future<Response> _globalStats(Request req) async {
  final got = await _api.get('/global', {}, const Duration(minutes: 2));
  Map<String, dynamic> stats;
  String source;
  if (got != null) {
    final g = (got.data as Map)['data'] as Map;
    stats = {
      'active_cryptocurrencies': g['active_cryptocurrencies'],
      'markets': g['markets'],
      'total_market_cap': (g['total_market_cap'] as Map?)?['usd'],
      'total_volume': (g['total_volume'] as Map?)?['usd'],
      'market_cap_change_percentage_24h': g['market_cap_change_percentage_24h_usd'],
      'market_cap_percentage': g['market_cap_percentage'] ?? {},
    };
    source = got.source;
  } else {
    stats = mockGlobal();
    source = 'mock';
  }

  final (coins, coinsSource) = await _markets();
  if (coinsSource == 'mock') source = 'mock';
  final ranked = coins.where((c) => c['price_change_percentage_24h'] != null).toList()
    ..sort((a, b) => _num(b, 'price_change_percentage_24h')!.compareTo(_num(a, 'price_change_percentage_24h')!));
  final byVolume = [...coins]..sort((a, b) => (_num(b, 'total_volume') ?? 0).compareTo(_num(a, 'total_volume') ?? 0));
  stats['top_gainers'] = ranked.take(5).toList();
  stats['top_losers'] = ranked.reversed.take(5).toList();
  stats['top_volume'] = byVolume.take(5).toList();
  return _envelope(stats, source);
}

// --- Watchlist (persisted to watchlist.json) -------------------------------

List<String> _loadWatchlist() {
  try {
    return (jsonDecode(_watchlistFile.readAsStringSync()) as List).cast<String>();
  } catch (_) {
    return [];
  }
}

void _saveWatchlist(List<String> ids) => _watchlistFile.writeAsStringSync(jsonEncode(ids));

Future<Response> _watchlist(Request req) async {
  final ids = _loadWatchlist();
  final (coins, source) = await _markets();
  final byId = {for (final c in coins) c['id']: c};
  return _envelope([for (final id in ids) if (byId[id] != null) byId[id]], source);
}

Response _addToWatchlist(Request req, String id) {
  final ids = _loadWatchlist();
  if (!ids.contains(id)) {
    ids.add(id);
    _saveWatchlist(ids);
  }
  return _json({'ids': ids});
}

Response _removeFromWatchlist(Request req, String id) {
  final ids = _loadWatchlist()..remove(id);
  _saveWatchlist(ids);
  return _json({'ids': ids});
}

// --- Auth endpoints ---------------------------------------------------------

Future<Response> _signup(Request req) async {
  if (req.method != 'POST') return _error(405, 'Method not allowed');

  final body = await req.readAsString();
  late Map<String, dynamic> data;
  try {
    data = jsonDecode(body) as Map<String, dynamic>;
  } catch (_) {
    return _error(400, 'Invalid JSON');
  }

  final username = data['username'] as String?;
  final password = data['password'] as String?;
  final email = data['email'] as String?;

  if (username == null || username.isEmpty) return _error(400, 'Username required');
  if (username.length < 3) return _error(400, 'Username must be 3+ characters');
  if (password == null || password.isEmpty) return _error(400, 'Password required');
  if (password.length < 6) return _error(400, 'Password must be 6+ characters');

  final user = _userStore.signup(username, password, email);
  if (user == null) return _error(400, 'Username already taken');

  final token = _userStore.createToken(username);
  return _json({'user': user.toPublic(), 'token': token});
}

Future<Response> _login(Request req) async {
  if (req.method != 'POST') return _error(405, 'Method not allowed');

  final body = await req.readAsString();
  late Map<String, dynamic> data;
  try {
    data = jsonDecode(body) as Map<String, dynamic>;
  } catch (_) {
    return _error(400, 'Invalid JSON');
  }

  final username = data['username'] as String?;
  final password = data['password'] as String?;

  if (username == null || username.isEmpty) return _error(400, 'Username required');
  if (password == null || password.isEmpty) return _error(400, 'Password required');

  final user = _userStore.login(username, password);
  if (user == null) return _error(401, 'Invalid credentials');

  final token = _userStore.createToken(username);
  return _json({'user': user.toPublic(), 'token': token});
}

Future<Response> _profile(Request req) async {
  final auth = req.headers['authorization'];
  if (auth == null || !auth.startsWith('Bearer ')) return _error(401, 'Missing or invalid token');

  final token = auth.substring(7);
  final user = _userStore.validateToken(token);
  if (user == null) return _error(401, 'Invalid or expired token');

  return _json({'user': user.toPublic()});
}

Future<Response> _logout(Request req) async {
  final auth = req.headers['authorization'];
  if (auth == null || !auth.startsWith('Bearer ')) return _error(401, 'Missing or invalid token');

  final token = auth.substring(7);
  _userStore.revokeToken(token);
  return _json({'success': true});
}

// --- Wiring ------------------------------------------------------------------

Middleware _cors() {
  const headers = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
  };
  return (inner) => (req) async {
        if (req.method == 'OPTIONS') return Response.ok('', headers: headers);
        final resp = await inner(req);
        return resp.change(headers: headers);
      };
}

Future<void> main() async {
  _userStore.load();

  final router = Router()
    ..get('/api/health', (Request _) => _json({'status': 'ok', 'mock_mode': _api.mockOnly}))
    // Auth routes
    ..post('/api/auth/signup', _signup)
    ..post('/api/auth/login', _login)
    ..get('/api/auth/profile', _profile)
    ..post('/api/auth/logout', _logout)
    // Crypto routes
    ..get('/api/coins', _listCoins)
    ..get('/api/coins/<id>', _coinDetail)
    ..get('/api/coins/<id>/chart', _coinChart)
    ..get('/api/global', _globalStats)
    ..get('/api/watchlist/ids', (Request _) => _json({'ids': _loadWatchlist()}))
    ..get('/api/watchlist', _watchlist)
    ..post('/api/watchlist/<id>', _addToWatchlist)
    ..delete('/api/watchlist/<id>', _removeFromWatchlist);

  final handler = const Pipeline().addMiddleware(logRequests()).addMiddleware(_cors()).addHandler(router.call);

  final port = int.tryParse(_env['PORT'] ?? '') ?? 8080;
  final server = await io.serve(handler, InternetAddress.anyIPv4, port);
  print('KryptoX backend on http://localhost:${server.port}  (mock only: ${_api.mockOnly})');
}
