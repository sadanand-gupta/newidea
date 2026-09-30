'use strict';
// CoinGecko client with a TTL cache and normalisation into the app's own
// JSON shapes, so the Flutter app never depends on CoinGecko's raw format.
// Port of backend/lib/coingecko.dart.

const BASE = 'https://api.coingecko.com/api/v3';
const TIMEOUT_MS = 10000;

class NotFound extends Error {
  constructor(message = 'NotFound') {
    super(message);
    this.name = 'NotFound';
  }
}

class CoinGecko {
  constructor({ apiKey = null, mockOnly = false } = {}) {
    this.apiKey = apiKey ?? null;
    this.mockOnly = !!mockOnly;
    this._cache = new Map(); // key -> { at: ms, data }
  }

  /**
   * Returns { data, source } with live data (or stale cache on failure), or
   * null when unavailable so the caller can fall back to mock data.
   * Throws NotFound on 404.
   */
  async get(path, params = {}, ttlMs) {
    if (this.mockOnly) return null;
    const url = new URL(BASE + path);
    const entries = Object.entries(params || {});
    if (entries.length > 0) {
      url.search = new URLSearchParams(entries).toString();
    }
    const key = url.toString();
    const cached = this._cache.get(key);
    if (cached && Date.now() - cached.at < ttlMs) {
      return { data: cached.data, source: 'live' };
    }
    try {
      const headers = {};
      if (this.apiKey != null) headers['x-cg-demo-api-key'] = this.apiKey;
      const resp = await fetch(key, { headers, signal: AbortSignal.timeout(TIMEOUT_MS) });
      if (resp.status === 404) throw new NotFound();
      if (resp.status !== 200) throw new Error(`HTTP ${resp.status}`);
      const data = JSON.parse(await resp.text());
      this._cache.set(key, { at: Date.now(), data });
      return { data, source: 'live' };
    } catch (e) {
      if (e instanceof NotFound) throw e;
      if (cached) return { data: cached.data, source: 'cache' };
      return null;
    }
  }
}

// Dart maps yield null for missing keys; keep keys present in JSON output.
const n = (v) => (v === undefined ? null : v);
const isObj = (v) => v !== null && typeof v === 'object' && !Array.isArray(v);

function normalizeMarket(c) {
  const spark = isObj(c.sparkline_in_7d) ? c.sparkline_in_7d.price : null;
  return {
    id: n(c.id),
    symbol: c.symbol ?? '',
    name: c.name ?? '',
    image: n(c.image),
    current_price: n(c.current_price),
    market_cap: n(c.market_cap),
    market_cap_rank: n(c.market_cap_rank),
    total_volume: n(c.total_volume),
    high_24h: n(c.high_24h),
    low_24h: n(c.low_24h),
    price_change_percentage_24h:
      c.price_change_percentage_24h_in_currency ?? n(c.price_change_percentage_24h),
    price_change_percentage_7d: n(c.price_change_percentage_7d_in_currency),
    circulating_supply: n(c.circulating_supply),
    total_supply: n(c.total_supply),
    max_supply: n(c.max_supply),
    sparkline: spark ?? [],
  };
}

function normalizeDetail(c) {
  const md = isObj(c.market_data) ? c.market_data : {};
  const usd = (field) => (isObj(md[field]) ? n(md[field].usd) : null);
  const descRaw = isObj(c.description) ? c.description.en : null;
  const desc = typeof descRaw === 'string' ? descRaw : '';
  // First paragraph only, with the HTML links CoinGecko embeds stripped out.
  const plain = desc.split('\r\n\r\n')[0].replace(/<[^>]*>/g, '').trim();
  const hp = isObj(c.links) ? c.links.homepage : null;
  const homepages = Array.isArray(hp) ? hp : [];
  const homepage = homepages.find((h) => h != null && h !== '');
  const cats = Array.isArray(c.categories) ? c.categories : [];
  return {
    id: n(c.id),
    symbol: c.symbol ?? '',
    name: c.name ?? '',
    image: isObj(c.image) ? n(c.image.large) : null,
    current_price: usd('current_price'),
    market_cap: usd('market_cap'),
    market_cap_rank: n(c.market_cap_rank),
    total_volume: usd('total_volume'),
    high_24h: usd('high_24h'),
    low_24h: usd('low_24h'),
    price_change_percentage_24h: n(md.price_change_percentage_24h),
    price_change_percentage_7d: n(md.price_change_percentage_7d),
    price_change_percentage_30d: n(md.price_change_percentage_30d),
    price_change_percentage_1y: n(md.price_change_percentage_1y),
    circulating_supply: n(md.circulating_supply),
    total_supply: n(md.total_supply),
    max_supply: n(md.max_supply),
    fully_diluted_valuation: usd('fully_diluted_valuation'),
    ath: usd('ath'),
    ath_change_percentage: usd('ath_change_percentage'),
    ath_date: usd('ath_date'),
    atl: usd('atl'),
    atl_date: usd('atl_date'),
    description: plain.length > 1200 ? `${plain.substring(0, 1200)}…` : plain,
    homepage: homepage === undefined ? null : homepage,
    categories: cats.filter((x) => typeof x === 'string').slice(0, 5),
    genesis_date: n(c.genesis_date),
    sparkline: [],
  };
}

module.exports = { CoinGecko, NotFound, normalizeMarket, normalizeDetail };
