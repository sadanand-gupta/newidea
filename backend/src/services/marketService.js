// Market data with mock fallback: every function resolves to
// `[data, source]` where source is 'live' | 'cache' | 'mock'.
const { NotFound, normalizeMarket, normalizeDetail } = require('./coingecko');
const { mockMarkets, mockCoinDetail, mockChart, mockGlobal } = require('../data/mockData');

const SEC = 1000;
const MIN = 60 * SEC;
const CHART_DAYS = ['1', '7', '30', '90', '365'];

class MarketService {
  constructor(api) {
    this.api = api;
  }

  /** Top 100 coins by market cap. */
  async markets() {
    const got = await this.api.get('/coins/markets', {
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

  /** Coin detail, or `null` data when the coin doesn't exist. */
  async detail(id) {
    try {
      const got = await this.api.get(`/coins/${id}`, {
        localization: 'false',
        tickers: 'false',
        community_data: 'false',
        developer_data: 'false',
        sparkline: 'false',
      }, 2 * MIN);
      if (got != null) return [normalizeDetail(got.data), got.source];
    } catch (e) {
      if (e instanceof NotFound) return [null, 'live'];
      throw e;
    }
    return [mockCoinDetail(id), 'mock'];
  }

  /** Price history as [[ms, price], ...], or `null` data when the coin doesn't exist. */
  async chart(id, days) {
    try {
      const got = await this.api.get(`/coins/${id}/market_chart`, { vs_currency: 'usd', days }, 5 * MIN);
      if (got != null) return [got.data.prices ?? [], got.source];
    } catch (e) {
      if (e instanceof NotFound) return [null, 'live'];
      throw e;
    }
    return [mockChart(id, Number(days)), 'mock'];
  }

  /** Global stats plus top gainers, losers and volume from the market list. */
  async global() {
    const got = await this.api.get('/global', {}, 2 * MIN);
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

    const [coins, coinsSource] = await this.markets();
    if (coinsSource === 'mock') source = 'mock';
    const ranked = coins
      .filter((c) => c.price_change_percentage_24h != null)
      .sort((a, b) => b.price_change_percentage_24h - a.price_change_percentage_24h);
    const byVolume = [...coins].sort((a, b) => (b.total_volume ?? 0) - (a.total_volume ?? 0));
    stats.top_gainers = ranked.slice(0, 5);
    stats.top_losers = [...ranked].reverse().slice(0, 5);
    stats.top_volume = byVolume.slice(0, 5);
    return [stats, source];
  }
}

module.exports = { MarketService, CHART_DAYS };
