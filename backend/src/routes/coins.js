// /api/coins and /api/global: server-side search, filter and sort.
const express = require('express');
const { envelope, sendError, asyncRoute } = require('../lib/http');
const { CHART_DAYS } = require('../services/marketService');

const SORT_FIELDS = {
  market_cap: 'market_cap',
  price: 'current_price',
  volume: 'total_volume',
  change_24h: 'price_change_percentage_24h',
  change_7d: 'price_change_percentage_7d',
};

const num = (c, field) => (typeof c[field] === 'number' ? c[field] : null);
const change24h = (c) => num(c, 'price_change_percentage_24h') ?? 0;

const FILTERS = {
  gainers: (c) => change24h(c) > 0,
  losers: (c) => change24h(c) < 0,
  top10: (c) => (num(c, 'market_cap_rank') ?? 999) <= 10,
  stablecoins: (c) => {
    const p = num(c, 'current_price');
    return p != null && p >= 0.97 && p <= 1.03 && Math.abs(change24h(c)) < 1;
  },
};

function sortCoins(coins, sort, desc) {
  if (sort === 'name') {
    const byName = [...coins].sort((a, b) => {
      const x = a.name.toLowerCase();
      const y = b.name.toLowerCase();
      return x < y ? -1 : x > y ? 1 : 0;
    });
    return desc ? byName.reverse() : byName;
  }
  // Coins missing the sort value always sink to the bottom, whatever the direction.
  const field = SORT_FIELDS[sort];
  const present = coins.filter((c) => c[field] != null);
  const missing = coins.filter((c) => c[field] == null);
  present.sort((a, b) => (desc ? b[field] - a[field] : a[field] - b[field]));
  return [...present, ...missing];
}

function coinsRouter(market) {
  const router = express.Router();

  router.get('/coins', asyncRoute(async (req, res) => {
    const search = String(req.query.search ?? '').trim().toLowerCase();
    const filter = Object.hasOwn(FILTERS, req.query.filter ?? '') ? FILTERS[req.query.filter] : null;
    const sort = req.query.sort ?? 'market_cap';
    const desc = (req.query.order ?? 'desc') === 'desc';
    if (sort !== 'name' && !Object.hasOwn(SORT_FIELDS, sort)) return sendError(res, 400, `Invalid sort: ${sort}`);

    let [coins, source] = await market.markets();
    if (search) {
      coins = coins.filter((c) =>
        c.name.toLowerCase().includes(search) || c.symbol.toLowerCase().includes(search));
    }
    if (filter) coins = coins.filter(filter);
    return envelope(res, sortCoins(coins, sort, desc), source);
  }));

  router.get('/coins/:id', asyncRoute(async (req, res) => {
    const [detail, source] = await market.detail(req.params.id);
    if (detail == null) return sendError(res, 404, source === 'mock' ? 'Coin not found (mock mode)' : 'Coin not found');
    return envelope(res, detail, source);
  }));

  router.get('/coins/:id/chart', asyncRoute(async (req, res) => {
    const days = String(req.query.days ?? '7');
    if (!CHART_DAYS.includes(days)) return sendError(res, 400, 'days must be 1, 7, 30, 90 or 365');
    const [prices, source] = await market.chart(req.params.id, days);
    if (prices == null) return sendError(res, 404, source === 'mock' ? 'Coin not found (mock mode)' : 'Coin not found');
    return envelope(res, { days: Number(days), prices }, source);
  }));

  router.get('/global', asyncRoute(async (req, res) => {
    const [stats, source] = await market.global();
    return envelope(res, stats, source);
  }));

  return router;
}

module.exports = { coinsRouter };
