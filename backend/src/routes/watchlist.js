// /api/watchlist: the saved coin ids and their market rows.
const express = require('express');
const { envelope, asyncRoute } = require('../lib/http');

function watchlistRouter(market, store) {
  const router = express.Router();

  router.get('/', asyncRoute(async (req, res) => {
    const ids = store.ids();
    const [coins, source] = await market.markets();
    const byId = new Map(coins.map((c) => [c.id, c]));
    return envelope(res, ids.filter((id) => byId.has(id)).map((id) => byId.get(id)), source);
  }));

  router.get('/ids', (req, res) => res.json({ ids: store.ids() }));
  router.post('/:id', (req, res) => res.json({ ids: store.add(req.params.id) }));
  router.delete('/:id', (req, res) => res.json({ ids: store.remove(req.params.id) }));

  return router;
}

module.exports = { watchlistRouter };
