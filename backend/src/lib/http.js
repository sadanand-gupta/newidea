// Response helpers and middleware shared by every route.

/** Wraps market data as `{ source, updated_at, data }`. */
const envelope = (res, data, source) =>
  res.json({ source, updated_at: Math.floor(Date.now() / 1000), data });

const sendError = (res, status, message) => res.status(status).json({ error: message });

/** Lets an async handler's rejection reach Express's error handler. */
const asyncRoute = (handler) => (req, res, next) => Promise.resolve(handler(req, res, next)).catch(next);

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
    'Access-Control-Allow-Headers': 'Content-Type',
  });
  if (req.method === 'OPTIONS') return res.status(200).send('');
  next();
}

function notFound(req, res) {
  res.status(404).type('text').send('Route not found');
}

// eslint-disable-next-line no-unused-vars
function errorHandler(err, req, res, next) {
  console.error(err);
  sendError(res, 500, 'Internal server error');
}

module.exports = { envelope, sendError, asyncRoute, logRequests, cors, notFound, errorHandler };
