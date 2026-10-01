// Builds the Express app; server.js only reads config and listens.
const express = require('express');
const { logRequests, cors, notFound, errorHandler } = require('./lib/http');
const { coinsRouter } = require('./routes/coins');
const { watchlistRouter } = require('./routes/watchlist');

function createApp({ market, watchlist, mockOnly }) {
  const app = express();
  app.disable('x-powered-by');
  app.use(logRequests);
  app.use(cors);

  app.get('/api/health', (req, res) => res.json({ status: 'ok', mock_mode: mockOnly }));
  app.use('/api', coinsRouter(market));
  app.use('/api/watchlist', watchlistRouter(market, watchlist));

  app.use(notFound);
  app.use(errorHandler);
  return app;
}

module.exports = { createApp };
