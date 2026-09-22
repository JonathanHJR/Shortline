const express = require('express');
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

const app = express();
app.use(express.json());

const BASE_URL = process.env.BASE_URL || 'http://localhost:8080';
const DATA_FILE = process.env.DATA_FILE || path.join(__dirname, 'data', 'links.json');

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
  res.json({ status: 'ok', baseUrl: BASE_URL });
});

app.post('/shorten', (req, res) => {
  const { url } = req.body || {};
  if (!url) return res.status(400).json({ error: 'url is required' });
  const code = crypto.randomBytes(4).toString('hex');
  links[code] = url;
  saveLinks(links);
  res.json({ code, shortUrl: `${BASE_URL}/${code}` });
});

app.get('/:code', (req, res) => {
  const url = links[req.params.code];
  if (!url) return res.status(404).json({ error: 'not found' });
  res.redirect(302, url);
});

module.exports = app;