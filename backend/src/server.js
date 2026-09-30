// KryptoX backend: Express server over CoinGecko with caching, mock fallback,
// server-side search/filter/sort and a persisted watchlist.
//
// Run:  npm start            (or: node src/server.js)
// Env:  PORT=8080                 port to listen on (default 8080)
//       USE_MOCK=1                always serve mock data (no network)
//       COINGECKO_API_KEY=...     optional CoinGecko demo key (higher rate limit)

const fs = require('node:fs');
const path = require('node:path');
const express = require('express');

const { CoinGecko, NotFound, normalizeMarket, normalizeDetail } = require('./coingecko');
const { mockMarkets, mockCoinDetail, mockChart, mockGlobal } = require('./mockData');
const { UserStore, toPublic } = require('./userStore');

const env = process.env;
const DATA_DIR = path.join(__dirname, '..');
const api = new CoinGecko({ apiKey: env.COINGECKO_API_KEY, mockOnly: env.USE_MOCK === '1' });
const watchlistFile = path.join(DATA_DIR, 'watchlist.json');
const userStore = new UserStore({ filePath: path.join(DATA_DIR, 'users.json') });

const SEC = 1000;
const MIN = 60 * SEC;

const sendJson = (res, body, status = 200) => res.status(status).json(body);

const envelope = (res, data, source) =>
  sendJson(res, { source, updated_at: Math.floor(Date.now() / 1000), data });

const sendError = (res, status, message) => sendJson(res, { error: message }, status);

async function markets() {
  const got = await api.get('/coins/markets', {
    vs_currency: 'usd',
    order: 'market_cap_desc',
    per_page: '100',
    page: '1',
    sparkline: 'true',
    price_change_percentage: '24h,7d',
  }, 60 * SEC);
  if (got == null) return [mockMarkets(), 'mock'];
  return [got.data.map(normalizeMarket), got.source];
}

const num = (c, field) => (typeof c[field] === 'number' ? c[field] : null);
const cmpStr = (a, b) => (a < b ? -1 : a > b ? 1 : 0);

const SORT_FIELDS = {
  market_cap: 'market_cap',
  price: 'current_price',
  volume: 'total_volume',
  change_24h: 'price_change_percentage_24h',
  change_7d: 'price_change_percentage_7d',
};

async function listCoins(req, res) {
  const q = req.query;
  const search = String(q.search ?? '').trim().toLowerCase();
  const filter = q.filter ?? 'all';
  const sort = q.sort ?? 'market_cap';
  const desc = (q.order ?? 'desc') === 'desc';
  if (sort !== 'name' && !(sort in SORT_FIELDS)) return sendError(res, 400, `Invalid sort: ${sort}`);

  let [coins, source] = await markets();

  if (search) {
    coins = coins.filter((c) =>
      c.name.toLowerCase().includes(search) || c.symbol.toLowerCase().includes(search));
  }

  const change = (c) => num(c, 'price_change_percentage_24h') ?? 0;
  switch (filter) {
    case 'gainers': coins = coins.filter((c) => change(c) > 0); break;
    case 'losers': coins = coins.filter((c) => change(c) < 0); break;
    case 'top10': coins = coins.filter((c) => (num(c, 'market_cap_rank') ?? 999) <= 10); break;
    case 'stablecoins':
      coins = coins.filter((c) => {
        const p = num(c, 'current_price');
        return p != null && p >= 0.97 && p <= 1.03 && Math.abs(change(c)) < 1;
      });
      break;
  }

  if (sort === 'name') {
    coins = [...coins].sort((a, b) => cmpStr(a.name.toLowerCase(), b.name.toLowerCase()));
    if (desc) coins.reverse();
  } else {
    // Coins missing the sort value always sink to the bottom, whatever the direction.
    const field = SORT_FIELDS[sort];
    const present = coins.filter((c) => c[field] != null);
    const missing = coins.filter((c) => c[field] == null);
    present.sort((a, b) => (desc ? b[field] - a[field] : a[field] - b[field]));
    coins = [...present, ...missing];
  }
  return envelope(res, coins, source);
}

async function coinDetail(req, res) {
  const { id } = req.params;
  try {
    const got = await api.get(`/coins/${id}`, {
      localization: 'false',
      tickers: 'false',
      community_data: 'false',
      developer_data: 'false',
      sparkline: 'false',
    }, 2 * MIN);
    if (got != null) return envelope(res, normalizeDetail(got.data), got.source);
  } catch (e) {
    if (e instanceof NotFound) return sendError(res, 404, 'Coin not found');
    throw e;
  }
  const detail = mockCoinDetail(id);
  return detail == null ? sendError(res, 404, 'Coin not found (mock mode)') : envelope(res, detail, 'mock');
}

async function coinChart(req, res) {
  const { id } = req.params;
  const days = String(req.query.days ?? '7');
  if (!['1', '7', '30', '90', '365'].includes(days)) return sendError(res, 400, 'days must be 1, 7, 30, 90 or 365');
  try {
    const got = await api.get(`/coins/${id}/market_chart`, { vs_currency: 'usd', days }, 5 * MIN);
    if (got != null) return envelope(res, { days: Number(days), prices: got.data.prices ?? [] }, got.source);
  } catch (e) {
    if (e instanceof NotFound) return sendError(res, 404, 'Coin not found');
    throw e;
  }
  const prices = mockChart(id, Number(days));
  return prices == null
    ? sendError(res, 404, 'Coin not found (mock mode)')
    : envelope(res, { days: Number(days), prices }, 'mock');
}

async function globalStats(req, res) {
  const got = await api.get('/global', {}, 2 * MIN);
  let stats;
  let source;
  if (got != null) {
    const g = got.data.data;
    stats = {
      active_cryptocurrencies: g.active_cryptocurrencies,
      markets: g.markets,
      total_market_cap: g.total_market_cap?.usd,
      total_volume: g.total_volume?.usd,
      market_cap_change_percentage_24h: g.market_cap_change_percentage_24h_usd,
      market_cap_percentage: g.market_cap_percentage ?? {},
    };
    source = got.source;
  } else {
    stats = mockGlobal();
    source = 'mock';
  }

  const [coins, coinsSource] = await markets();
  if (coinsSource === 'mock') source = 'mock';
  const ranked = coins
    .filter((c) => c.price_change_percentage_24h != null)
    .sort((a, b) => b.price_change_percentage_24h - a.price_change_percentage_24h);
  const byVolume = [...coins].sort((a, b) => (num(b, 'total_volume') ?? 0) - (num(a, 'total_volume') ?? 0));
  stats.top_gainers = ranked.slice(0, 5);
  stats.top_losers = [...ranked].reverse().slice(0, 5);
  stats.top_volume = byVolume.slice(0, 5);
  return envelope(res, stats, source);
}

// --- Watchlist (persisted to watchlist.json) -------------------------------

function loadWatchlist() {
  try {
    const ids = JSON.parse(fs.readFileSync(watchlistFile, 'utf8'));
    return Array.isArray(ids) ? ids.filter((x) => typeof x === 'string') : [];
  } catch {
    return [];
  }
}

const saveWatchlist = (ids) => fs.writeFileSync(watchlistFile, JSON.stringify(ids));

async function watchlist(req, res) {
  const ids = loadWatchlist();
  const [coins, source] = await markets();
  const byId = new Map(coins.map((c) => [c.id, c]));
  return envelope(res, ids.filter((id) => byId.has(id)).map((id) => byId.get(id)), source);
}

function addToWatchlist(req, res) {
  const ids = loadWatchlist();
  if (!ids.includes(req.params.id)) {
    ids.push(req.params.id);
    saveWatchlist(ids);
  }
  return sendJson(res, { ids });
}

function removeFromWatchlist(req, res) {
  const ids = loadWatchlist();
  const i = ids.indexOf(req.params.id);
  if (i !== -1) ids.splice(i, 1);
  saveWatchlist(ids);
  return sendJson(res, { ids });
}

// --- Auth endpoints ---------------------------------------------------------

// Body arrives as raw text (any content type) so bad JSON gets our own error message.
function parseBody(req) {
  try {
    const data = JSON.parse(req.body);
    return data !== null && typeof data === 'object' && !Array.isArray(data) ? data : null;
  } catch {
    return null;
  }
}

const str = (v) => (typeof v === 'string' ? v : null);

function signup(req, res) {
  const data = parseBody(req);
  if (data == null) return sendError(res, 400, 'Invalid JSON');

  const username = str(data.username);
  const password = str(data.password);
  const email = str(data.email);

  if (!username) return sendError(res, 400, 'Username required');
  if (username.length < 3) return sendError(res, 400, 'Username must be 3+ characters');
  if (!password) return sendError(res, 400, 'Password required');
  if (password.length < 6) return sendError(res, 400, 'Password must be 6+ characters');

  const user = userStore.signup(username, password, email);
  if (user == null) return sendError(res, 400, 'Username already taken');

  return sendJson(res, { user: toPublic(user), token: userStore.createToken(username) });
}

function login(req, res) {
  const data = parseBody(req);
  if (data == null) return sendError(res, 400, 'Invalid JSON');

  const username = str(data.username);
  const password = str(data.password);

  if (!username) return sendError(res, 400, 'Username required');
  if (!password) return sendError(res, 400, 'Password required');

  const user = userStore.login(username, password);
  if (user == null) return sendError(res, 401, 'Invalid credentials');

  return sendJson(res, { user: toPublic(user), token: userStore.createToken(username) });
}

function bearerToken(req) {
  const auth = req.get('authorization');
  return auth && auth.startsWith('Bearer ') ? auth.slice(7) : null;
}

function profile(req, res) {
  const token = bearerToken(req);
  if (token == null) return sendError(res, 401, 'Missing or invalid token');

  const user = userStore.validateToken(token);
  if (user == null) return sendError(res, 401, 'Invalid or expired token');

  return sendJson(res, { user: toPublic(user) });
}

function logout(req, res) {
  const token = bearerToken(req);
  if (token == null) return sendError(res, 401, 'Missing or invalid token');

  userStore.revokeToken(token);
  return sendJson(res, { success: true });
}

// --- Wiring ------------------------------------------------------------------

function logRequests(req, res, next) {
  const start = process.hrtime.bigint();
  res.on('finish', () => {
    const ms = Number(process.hrtime.bigint() - start) / 1e6;
    console.log(`${new Date().toISOString()}  ${req.method.padEnd(6)} [${res.statusCode}] ${req.originalUrl}  ${ms.toFixed(1)}ms`);
  });
  next();
}

function cors(req, res, next) {
  res.set({
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  });
  if (req.method === 'OPTIONS') return res.status(200).send('');
  next();
}

userStore.load();

const app = express();
app.disable('x-powered-by');
app.use(logRequests);
app.use(cors);

const rawBody = express.text({ type: () => true });

app.get('/api/health', (req, res) => sendJson(res, { status: 'ok', mock_mode: api.mockOnly }));
// Auth routes
app.post('/api/auth/signup', rawBody, signup);
app.post('/api/auth/login', rawBody, login);
app.get('/api/auth/profile', profile);
app.post('/api/auth/logout', logout);
// Crypto routes
app.get('/api/coins', listCoins);
app.get('/api/coins/:id', coinDetail);
app.get('/api/coins/:id/chart', coinChart);
app.get('/api/global', globalStats);
app.get('/api/watchlist/ids', (req, res) => sendJson(res, { ids: loadWatchlist() }));
app.get('/api/watchlist', watchlist);
app.post('/api/watchlist/:id', addToWatchlist);
app.delete('/api/watchlist/:id', removeFromWatchlist);

app.use((req, res) => res.status(404).type('text').send('Route not found'));
// eslint-disable-next-line no-unused-vars
app.use((err, req, res, next) => {
  console.error(err);
  sendError(res, 500, 'Internal server error');
});

const port = Number.parseInt(env.PORT ?? '', 10) || 8080;
app.listen(port, '0.0.0.0', () => {
  console.log(`KryptoX backend on http://localhost:${port}  (mock only: ${api.mockOnly})`);
});
