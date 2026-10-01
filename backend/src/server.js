// KryptoX backend: Express server over CoinGecko with caching, mock fallback,
// server-side search/filter/sort and a persisted watchlist.
//
// Run:  npm start            (or: node src/server.js)
// Env:  PORT=8080                 port to listen on (default 8080)
//       USE_MOCK=1                always serve mock data (no network)
//       COINGECKO_API_KEY=...     optional CoinGecko demo key (higher rate limit)

const path = require('node:path');
const { createApp } = require('./app');
const { CoinGecko } = require('./services/coingecko');
const { MarketService } = require('./services/marketService');
const { WatchlistStore } = require('./services/watchlistStore');

const env = process.env;
const mockOnly = env.USE_MOCK === '1';
const api = new CoinGecko({ apiKey: env.COINGECKO_API_KEY, mockOnly });

const app = createApp({
  market: new MarketService(api),
  watchlist: new WatchlistStore(path.join(__dirname, '..', 'watchlist.json')),
  mockOnly,
});

const port = Number.parseInt(env.PORT ?? '', 10) || 8080;
app.listen(port, '0.0.0.0', () => {
  console.log(`KryptoX backend on http://localhost:${port}  (mock only: ${mockOnly})`);
});
