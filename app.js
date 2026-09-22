const express = require('express');
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const client = require('prom-client');

const app = express();
app.use(express.json());

const BASE_URL = process.env.BASE_URL || 'http://localhost:8080';
const DATA_FILE = process.env.DATA_FILE || path.join(__dirname, 'data', 'links.json');

const register = new client.Registry();
client.collectDefaultMetrics({ register });

const httpRequests = new client.Counter({
  name: 'shortline_http_requests_total',
  help: 'Total HTTP requests',
  labelNames: ['route', 'status'],
});
register.registerMetric(httpRequests);

function loadLinks() {
  try {
    return JSON.parse(fs.readFileSync(DATA_FILE, 'utf8'));
  } catch (err) {
    return {};
  }
}
function saveLinks(links) {
  fs.mkdirSync(path.dirname(DATA_FILE), { recursive: true });
  fs.writeFileSync(DATA_FILE, JSON.stringify(links, null, 2));
}

let links = loadLinks();

app.get('/health', (req, res) => {
  httpRequests.inc({ route: '/health', status: 200 });
  res.json({ status: 'ok', baseUrl: BASE_URL });
});

app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

app.post('/shorten', (req, res) => {
  const { url } = req.body || {};
  if (!url) {
    httpRequests.inc({ route: '/shorten', status: 400 });
    return res.status(400).json({ error: 'url is required' });
  }
  const code = crypto.randomBytes(4).toString('hex');
  links[code] = url;
  saveLinks(links);
  httpRequests.inc({ route: '/shorten', status: 200 });
  res.json({ code, shortUrl: `${BASE_URL}/${code}` });
});

app.get('/:code', (req, res) => {
  const url = links[req.params.code];
  if (!url) {
    httpRequests.inc({ route: '/:code', status: 404 });
    return res.status(404).json({ error: 'not found' });
  }
  httpRequests.inc({ route: '/:code', status: 302 });
  res.redirect(302, url);
});

module.exports = app;