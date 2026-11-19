'use strict';

import crypto from 'node:crypto';
import { Redis } from '@upstash/redis';

const TICKET_TTL_SECONDS = 15 * 60;
const RATE_WINDOW_SECONDS = 60;
let redisClient;

function redis() {
  if (!process.env.UPSTASH_REDIS_REST_URL || !process.env.UPSTASH_REDIS_REST_TOKEN) {
    throw new Error('Upstash Redis is not connected. Add the Upstash integration in Vercel.');
  }
  if (!redisClient) redisClient = Redis.fromEnv();
  return redisClient;
}

function send(res, status, data) {
  res.setHeader('Cache-Control', 'no-store');
  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  return res.status(status).json(data);
}

function bodyOf(req) {
  if (req.body && typeof req.body === 'object') return req.body;
  if (typeof req.body === 'string') {
    try { return JSON.parse(req.body); } catch { return {}; }
  }
  return {};
}

function base64url(value) {
  return Buffer.from(value).toString('base64url');
}

function sign(payload) {
  const encoded = base64url(JSON.stringify(payload));
  const signature = crypto.createHmac('sha256', process.env.SIGNING_SECRET)
    .update(encoded).digest('base64url');
  return `${encoded}.${signature}`;
}

function verify(token) {
  if (typeof token !== 'string' || token.length > 2048) return null;
  const parts = token.split('.');
  if (parts.length !== 2) return null;
  const [encoded, signatureText] = parts;
  const expected = crypto.createHmac('sha256', process.env.SIGNING_SECRET)
    .update(encoded).digest();
  let supplied;
  try { supplied = Buffer.from(signatureText, 'base64url'); } catch { return null; }
  if (supplied.length !== expected.length || !crypto.timingSafeEqual(supplied, expected)) return null;
  try { return JSON.parse(Buffer.from(encoded, 'base64url').toString('utf8')); }
  catch { return null; }
}

function getClientIp(req) {
  const forwarded = req.headers['x-forwarded-for'];
  if (typeof forwarded === 'string' && forwarded.length) return forwarded.split(',')[0].trim();
  return String(req.headers['x-real-ip'] || 'unknown');
}

async function rateLimit(req, name, limit) {
  const db = redis();
  const ipHash = crypto.createHash('sha256').update(getClientIp(req)).digest('hex').slice(0, 20);
  const key = `rate:${name}:${ipHash}`;
  await db.set(key, '0', { nx: true, ex: RATE_WINDOW_SECONDS });
  const count = await db.incr(key);
  return count <= limit;
}

function configMissing(names) {
  return names.filter(name => {
    const value = String(process.env[name] || '');
    return !value || value.startsWith('YOUR_') || value.startsWith('PASTE_') || value.startsWith('REPLACE_') || value.includes('YOUR-PROJECT');
  });
}

const ADMIN_SESSION_SECONDS = 8 * 60 * 60;
const ADMIN_KEYS_PAGE_SIZE = 200;

function safeEqualText(a, b) {
  const left = crypto.createHash('sha256').update(String(a).slice(0, 1024)).digest();
  const right = crypto.createHash('sha256').update(String(b).slice(0, 1024)).digest();
  return crypto.timingSafeEqual(left, right);
}

function adminCookieName() { return '__Host-kxy_admin'; }

function setAdminCookie(res, token, maxAge = ADMIN_SESSION_SECONDS) {
  res.setHeader('Set-Cookie', `${adminCookieName()}=${token}; HttpOnly; Secure; SameSite=Strict; Path=/; Max-Age=${maxAge}`);
}

function getCookie(req, name) {
  const cookieHeader = String(req.headers.cookie || '');
  for (const part of cookieHeader.split(';')) {
    const index = part.indexOf('=');
    if (index < 0) continue;
    if (part.slice(0, index).trim() === name) return part.slice(index + 1).trim();
  }
  return '';
}

function signAdminSession(payload) {
  const encoded = base64url(JSON.stringify(payload));
  const signature = crypto.createHmac('sha256', process.env.ADMIN_SESSION_SECRET)
    .update(encoded).digest('base64url');
  return `${encoded}.${signature}`;
}

function verifyAdminSession(token) {
  if (typeof token !== 'string' || token.length > 2048) return null;
  const parts = token.split('.');
  if (parts.length !== 2) return null;
  const [encoded, signatureText] = parts;
  const expected = crypto.createHmac('sha256', process.env.ADMIN_SESSION_SECRET)
    .update(encoded).digest();
  let supplied;
  try { supplied = Buffer.from(signatureText, 'base64url'); } catch { return null; }
  if (supplied.length !== expected.length || !crypto.timingSafeEqual(supplied, expected)) return null;
  try {
    const payload = JSON.parse(Buffer.from(encoded, 'base64url').toString('utf8'));
    if (payload.role !== 'admin' || !Number.isFinite(payload.exp) || payload.exp <= Math.floor(Date.now() / 1000)) return null;
    return payload;
  } catch { return null; }
}

function adminIsConfigured() {
  const password = String(process.env.ADMIN_PASSWORD || '');
  const sessionSecret = String(process.env.ADMIN_SESSION_SECRET || '');
  const placeholder = value => !value || value.startsWith('YOUR_') || value.startsWith('PASTE_') || value.startsWith('REPLACE_');
  return Boolean(
    password.length >= 12 && sessionSecret.length >= 32 &&
    !placeholder(password) && !placeholder(sessionSecret) &&
    sessionSecret !== String(process.env.SIGNING_SECRET || '')
  );
}

function requireSameOrigin(req) {
  const origin = req.headers.origin;
  if (!origin) return true;
  try {
    const originHost = new URL(origin).host.toLowerCase();
    const requestHost = String(req.headers.host || req.headers['x-forwarded-host'] || '').toLowerCase();
    return Boolean(requestHost) && originHost === requestHost;
  } catch { return false; }
}

function readJsonValue(value) {
  if (typeof value === 'string') {
    try { return JSON.parse(value); } catch { return null; }
  }
  return value && typeof value === 'object' ? value : null;
}

async function requireAdmin(req, res) {
  if (!adminIsConfigured()) {
    send(res, 503, { ok: false, error: 'Admin is not configured. Add ADMIN_PASSWORD (12+ characters) and ADMIN_SESSION_SECRET (32+ characters) in Vercel.' });
    return false;
  }
  const session = verifyAdminSession(getCookie(req, adminCookieName()));
  if (!session) {
    send(res, 401, { ok: false, error: 'Admin session expired. Sign in again.' });
    return false;
  }
  return true;
}

async function adminLogin(req, res) {
  if (!requireSameOrigin(req)) return send(res, 403, { ok: false, error: 'Cross-origin request blocked.' });
  if (!adminIsConfigured()) return send(res, 503, { ok: false, error: 'Set ADMIN_PASSWORD (12+ characters) and ADMIN_SESSION_SECRET (32+ characters) in Vercel first.' });
  if (!(await rateLimit(req, 'admin-login', 5))) return send(res, 429, { ok: false, error: 'Too many login attempts. Try again in one minute.' });
  const password = String(bodyOf(req).password || '');
  if (!safeEqualText(password, process.env.ADMIN_PASSWORD)) return send(res, 401, { ok: false, error: 'Incorrect admin password.' });
  const now = Math.floor(Date.now() / 1000);
  const token = signAdminSession({ role: 'admin', iat: now, exp: now + ADMIN_SESSION_SECONDS });
  setAdminCookie(res, token);
  return send(res, 200, { ok: true, expiresInSeconds: ADMIN_SESSION_SECONDS });
}

async function adminCreateKey(req, res) {
  if (!requireSameOrigin(req)) return send(res, 403, { ok: false, error: 'Cross-origin request blocked.' });
  if (configMissing(['SIGNING_SECRET']).length) return send(res, 503, { ok: false, error: 'SIGNING_SECRET is missing in Vercel Environment Variables.' });
  if (!(await requireAdmin(req, res))) return;
  const input = bodyOf(req);
  const userId = String(input.userId || '').trim();
  const label = String(input.label || '').trim().slice(0, 48);
  if (!/^\d{1,20}$/.test(userId)) return send(res, 400, { ok: false, error: 'Enter a valid Roblox UserId (numbers only).' });

  const mode = String(input.mode || 'duration');
  let expiresAt = null;
  let ttlSeconds = null;
  let durationLabel = 'Permanent';
  if (mode !== 'permanent') {
    const duration = Number(input.duration);
    const unit = String(input.unit || 'hours');
    const unitSeconds = { minutes: 60, hours: 3600, days: 86400, months: 2592000, years: 31536000 };
    if (!Number.isSafeInteger(duration) || duration < 1 || !unitSeconds[unit]) {
      return send(res, 400, { ok: false, error: 'Choose a valid duration and unit.' });
    }
    ttlSeconds = duration * unitSeconds[unit];
    if (!Number.isSafeInteger(ttlSeconds) || ttlSeconds > 10 * 365 * 86400) {
      return send(res, 400, { ok: false, error: 'Maximum custom key lifetime is 10 years. Choose Permanent for no expiry.' });
    }
    expiresAt = Math.floor(Date.now() / 1000) + ttlSeconds;
    durationLabel = `${duration} ${unit}`;
  }

  const now = Math.floor(Date.now() / 1000);
  const jti = crypto.randomBytes(16).toString('hex');
  const payload = { sub: userId, iat: now, exp: expiresAt, jti };
  const token = sign(payload);
  const db = redis();
  if (ttlSeconds === null) await db.set(`license:${jti}`, userId);
  else await db.set(`license:${jti}`, userId, { ex: ttlSeconds });
  const metadata = {
    jti, userId, label, key: token, createdAt: now, expiresAt,
    durationLabel, source: 'admin', revokedAt: null
  };
  await db.set(`keymeta:${jti}`, JSON.stringify(metadata));
  await db.zadd('admin:keys', { score: now, member: jti });
  return send(res, 200, { ok: true, key: token, userId, expiresAt, durationLabel, jti });
}

async function adminListKeys(req, res) {
  if (!(await requireAdmin(req, res))) return;
  const db = redis();
  const ids = await db.zrange('admin:keys', 0, ADMIN_KEYS_PAGE_SIZE - 1, { rev: true });
  const now = Math.floor(Date.now() / 1000);
  const jtis = (ids || []).map(String);
  const [metadataValues, licenseValues] = jtis.length
    ? await Promise.all([
        db.mget(...jtis.map(jti => `keymeta:${jti}`)),
        db.mget(...jtis.map(jti => `license:${jti}`))
      ])
    : [[], []];
  const keys = jtis.map((jti, index) => {
    const meta = readJsonValue(metadataValues[index]);
    if (!meta) return null;
    let status = 'active';
    if (meta.revokedAt) status = 'revoked';
    else if (meta.expiresAt !== null && Number(meta.expiresAt) <= now) status = 'expired';
    else if (!licenseValues[index]) status = 'inactive';
    return {
      jti: meta.jti, userId: meta.userId, label: meta.label || '', key: meta.key,
      createdAt: meta.createdAt, expiresAt: meta.expiresAt,
      durationLabel: meta.durationLabel || (meta.expiresAt === null ? 'Permanent' : 'Timed'),
      source: meta.source || 'unknown', status
    };
  });
  return send(res, 200, { ok: true, keys: keys.filter(Boolean) });
}

async function adminRevokeKey(req, res) {
  if (!requireSameOrigin(req)) return send(res, 403, { ok: false, error: 'Cross-origin request blocked.' });
  if (!(await requireAdmin(req, res))) return;
  const jti = String(bodyOf(req).jti || '');
  if (!/^[a-f0-9]{32}$/.test(jti)) return send(res, 400, { ok: false, error: 'Invalid key ID.' });
  const db = redis();
  const rawMeta = await db.get(`keymeta:${jti}`);
  const meta = readJsonValue(rawMeta);
  if (!meta) return send(res, 404, { ok: false, error: 'Key not found in the management list.' });
  if (meta.revokedAt) return send(res, 200, { ok: true, alreadyRevoked: true });
  await db.del(`license:${jti}`);
  meta.revokedAt = Math.floor(Date.now() / 1000);
  await db.set(`keymeta:${jti}`, JSON.stringify(meta));
  return send(res, 200, { ok: true });
}


// Separate Kxy admin website -> GET KEY backend authentication.
// This is a server-to-server API. The shared token must never reach a browser.
function remoteAdminAuthorized(req, res) {
  const configured = String(process.env.KEY_ADMIN_API_TOKEN || '');
  if (configured.length < 32 || configured.startsWith('REPLACE_') || configured.startsWith('PASTE_')) {
    send(res, 503, { ok: false, error: 'KEY_ADMIN_API_TOKEN is not configured on the GET KEY project.' });
    return false;
  }
  const header = String(req.headers.authorization || '');
  const supplied = header.startsWith('Bearer ') ? header.slice(7) : '';
  if (!supplied || !safeEqualText(supplied, configured)) {
    send(res, 401, { ok: false, error: 'Admin bridge authentication failed.' });
    return false;
  }
  return true;
}

async function remoteAdminListKeys(req, res) {
  if (!remoteAdminAuthorized(req, res)) return;
  const db = redis();
  const ids = await db.zrange('admin:keys', 0, ADMIN_KEYS_PAGE_SIZE - 1, { rev: true });
  const now = Math.floor(Date.now() / 1000);
  const jtis = (ids || []).map(String);
  const [metadataValues, licenseValues] = jtis.length
    ? await Promise.all([
        db.mget(...jtis.map(jti => `keymeta:${jti}`)),
        db.mget(...jtis.map(jti => `license:${jti}`))
      ])
    : [[], []];
  const keys = jtis.map((jti, index) => {
    const meta = readJsonValue(metadataValues[index]);
    if (!meta) return null;
    let status = 'active';
    if (meta.revokedAt) status = 'revoked';
    else if (meta.expiresAt !== null && Number(meta.expiresAt) <= now) status = 'expired';
    else if (!licenseValues[index]) status = 'inactive';
    return {
      jti: meta.jti, userId: meta.userId, label: meta.label || '', key: meta.key,
      createdAt: meta.createdAt, expiresAt: meta.expiresAt,
      durationLabel: meta.durationLabel || (meta.expiresAt === null ? 'Permanent' : 'Timed'),
      source: meta.source || 'unknown', status
    };
  });
  return send(res, 200, { ok: true, keys: keys.filter(Boolean) });
}

async function remoteAdminCreateKey(req, res) {
  if (!remoteAdminAuthorized(req, res)) return;
  if (configMissing(['SIGNING_SECRET']).length) return send(res, 503, { ok: false, error: 'SIGNING_SECRET is missing in GET KEY Environment Variables.' });
  const input = bodyOf(req);
  const userId = String(input.userId || '').trim();
  const label = String(input.label || '').trim().slice(0, 48);
  if (!/^\d{1,20}$/.test(userId)) return send(res, 400, { ok: false, error: 'Enter a valid Roblox UserId (numbers only).' });

  const mode = String(input.mode || 'duration');
  let expiresAt = null;
  let ttlSeconds = null;
  let durationLabel = 'Permanent';
  if (mode !== 'permanent') {
    const duration = Number(input.duration);
    const unit = String(input.unit || 'hours');
    const unitSeconds = { minutes: 60, hours: 3600, days: 86400, months: 2592000, years: 31536000 };
    if (!Number.isSafeInteger(duration) || duration < 1 || !unitSeconds[unit]) {
      return send(res, 400, { ok: false, error: 'Choose a valid duration and unit.' });
    }
    ttlSeconds = duration * unitSeconds[unit];
    if (!Number.isSafeInteger(ttlSeconds) || ttlSeconds > 10 * 365 * 86400) {
      return send(res, 400, { ok: false, error: 'Maximum custom key lifetime is 10 years. Choose Permanent for no expiry.' });
    }
    expiresAt = Math.floor(Date.now() / 1000) + ttlSeconds;
    durationLabel = `${duration} ${unit}`;
  }

  const now = Math.floor(Date.now() / 1000);
  const jti = crypto.randomBytes(16).toString('hex');
  const token = sign({ sub: userId, iat: now, exp: expiresAt, jti });
  const db = redis();
  if (ttlSeconds === null) await db.set(`license:${jti}`, userId);
  else await db.set(`license:${jti}`, userId, { ex: ttlSeconds });
  const metadata = {
    jti, userId, label, key: token, createdAt: now, expiresAt,
    durationLabel, source: 'separate-admin-panel', revokedAt: null
  };
  await db.set(`keymeta:${jti}`, JSON.stringify(metadata));
  await db.zadd('admin:keys', { score: now, member: jti });
  return send(res, 200, { ok: true, key: token, userId, expiresAt, durationLabel, jti });
}

async function remoteAdminRevokeKey(req, res) {
  if (!remoteAdminAuthorized(req, res)) return;
  const jti = String(bodyOf(req).jti || '');
  if (!/^[a-f0-9]{32}$/.test(jti)) return send(res, 400, { ok: false, error: 'Invalid key ID.' });
  const db = redis();
  const rawMeta = await db.get(`keymeta:${jti}`);
  const meta = readJsonValue(rawMeta);
  if (!meta) return send(res, 404, { ok: false, error: 'Key not found in the management list.' });
  if (meta.revokedAt) return send(res, 200, { ok: true, alreadyRevoked: true });
  await db.del(`license:${jti}`);
  meta.revokedAt = Math.floor(Date.now() / 1000);
  await db.set(`keymeta:${jti}`, JSON.stringify(meta));
  return send(res, 200, { ok: true });
}

async function createLink4m(destination) {
  if (!process.env.LINK4M_API_KEY) throw new Error('LINK4M_API_KEY is missing in Vercel Environment Variables.');
  const endpoint = new URL('https://link4m.co/api-shorten/v2');
  endpoint.searchParams.set('api', process.env.LINK4M_API_KEY);
  endpoint.searchParams.set('url', destination);
  const response = await fetch(endpoint, { method: 'GET', signal: AbortSignal.timeout(12000) });
  const data = await response.json().catch(() => ({}));
  if (!response.ok || data.status !== 'success' || typeof data.shortenedUrl !== 'string') {
    throw new Error(data.message || `Link4m returned HTTP ${response.status}.`);
  }
  return data.shortenedUrl;
}

async function verifyHCaptcha(token, req) {
  if (!token || !process.env.HCAPTCHA_SECRET || !process.env.HCAPTCHA_SITEKEY) return false;
  const form = new URLSearchParams({
    secret: process.env.HCAPTCHA_SECRET,
    response: token,
    sitekey: process.env.HCAPTCHA_SITEKEY
  });
  const ip = getClientIp(req);
  if (ip !== 'unknown') form.set('remoteip', ip);
  const response = await fetch('https://api.hcaptcha.com/siteverify', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: form,
    signal: AbortSignal.timeout(10000)
  });
  if (!response.ok) return false;
  const result = await response.json().catch(() => ({}));
  return result.success === true;
}

async function start(req, res) {
  const missing = configMissing(['BASE_URL', 'LINK4M_API_KEY', 'SIGNING_SECRET']);
  if (missing.length) return send(res, 503, { ok: false, error: `Missing Vercel settings: ${missing.join(', ')}` });
  if (!(await rateLimit(req, 'start', 8))) return send(res, 429, { ok: false, error: 'Too many requests. Try again in one minute.' });

  const userId = String(bodyOf(req).userId || '');
  if (!/^\d{1,20}$/.test(userId)) return send(res, 400, { ok: false, error: 'Invalid Roblox UserId.' });

  const ticketId = crypto.randomBytes(24).toString('hex');
  const db = redis();
  const ticketData = { userId, createdAt: Date.now() };
  await db.set(`ticket:${ticketId}`, JSON.stringify(ticketData), { ex: TICKET_TTL_SECONDS });

  let base;
  try { base = new URL(process.env.BASE_URL); } catch { return send(res, 503, { ok: false, error: 'BASE_URL must be your deployed HTTPS Vercel URL.' }); }
  if (base.protocol !== 'https:') return send(res, 503, { ok: false, error: 'BASE_URL must use HTTPS.' });
  const baseUrl = base.toString().replace(/\/+$/, '');
  const claimUrl = `${baseUrl}/claim.html?ticket=${encodeURIComponent(ticketId)}`;
  try {
    const shortUrl = await createLink4m(claimUrl);
    return send(res, 200, { ok: true, shortUrl });
  } catch (error) {
    await db.del(`ticket:${ticketId}`);
    return send(res, 502, { ok: false, error: error.message || 'Could not create Link4m URL.' });
  }
}

async function claim(req, res) {
  const missing = configMissing(['SIGNING_SECRET', 'HCAPTCHA_SECRET', 'HCAPTCHA_SITEKEY']);
  if (missing.length) return send(res, 503, { ok: false, error: `Missing Vercel settings: ${missing.join(', ')}` });
  if (!(await rateLimit(req, 'claim', 12))) return send(res, 429, { ok: false, error: 'Too many attempts. Try again in one minute.' });

  const { ticket: ticketId, captchaToken } = bodyOf(req);
  if (typeof ticketId !== 'string' || !/^[a-f0-9]{48}$/.test(ticketId)) {
    return send(res, 400, { ok: false, error: 'Invalid claim ticket. Start again in Roblox.' });
  }

  const db = redis();
  const rawTicket = await db.get(`ticket:${ticketId}`);
  if (!rawTicket) return send(res, 400, { ok: false, error: 'This claim link expired or was already used. Get a new link in Roblox.' });
  const ticket = typeof rawTicket === 'string' ? JSON.parse(rawTicket) : rawTicket;

  // Acquire a short lock so two simultaneous requests cannot claim one ticket.
  const lock = await db.set(`ticket-lock:${ticketId}`, '1', { nx: true, ex: TICKET_TTL_SECONDS });
  if (lock !== 'OK') return send(res, 409, { ok: false, error: 'This claim is already being processed. Refresh in a moment.' });

  let issued = false;
  try {
    const captchaOK = await verifyHCaptcha(String(captchaToken || ''), req);
    if (!captchaOK) return send(res, 403, { ok: false, error: 'Robot verification failed. Complete hCaptcha and try again.' });

    const requestedHours = Number(process.env.KEY_HOURS || 24);
    const hours = Number.isFinite(requestedHours) ? Math.max(1, Math.min(168, requestedHours)) : 24;
    const now = Math.floor(Date.now() / 1000);
    const jti = crypto.randomBytes(16).toString('hex');
    const expiresAt = now + hours * 3600;
    const token = sign({ sub: String(ticket.userId), iat: now, exp: expiresAt, jti });
    await db.set(`license:${jti}`, String(ticket.userId), { ex: hours * 3600 });
    const metadata = {
      jti, userId: String(ticket.userId), label: '', key: token, createdAt: now,
      expiresAt, durationLabel: `${hours} hours`, source: 'claim', revokedAt: null
    };
    await db.set(`keymeta:${jti}`, JSON.stringify(metadata));
    await db.zadd('admin:keys', { score: now, member: jti });
    await db.del(`ticket:${ticketId}`);
    issued = true;
    return send(res, 200, { ok: true, key: token, expiresInHours: hours, expiresAt });
  } finally {
    if (!issued) await db.del(`ticket-lock:${ticketId}`);
    else await db.set(`ticket-used:${ticketId}`, '1', { ex: TICKET_TTL_SECONDS });
  }
}

async function validate(req, res) {
  if (configMissing(['SIGNING_SECRET']).length) return send(res, 503, { ok: false, error: 'SIGNING_SECRET is missing in Vercel Environment Variables.' });
  const { userId, key } = bodyOf(req);
  const payload = verify(String(key || ''));
  const now = Math.floor(Date.now() / 1000);
  const expiryInvalid = payload && payload.exp !== null && (!Number.isFinite(payload.exp) || payload.exp <= now);
  if (!payload || String(payload.sub) !== String(userId || '') || expiryInvalid || typeof payload.jti !== 'string') {
    return send(res, 403, { ok: false, error: 'Invalid key, wrong Roblox account, or expired key.' });
  }
  const storedUserId = await redis().get(`license:${payload.jti}`);
  if (!storedUserId || String(storedUserId) !== String(userId)) {
    return send(res, 403, { ok: false, error: 'This key is no longer active. Get a new key.' });
  }
  return send(res, 200, { ok: true, expiresAt: payload.exp });
}

export default async function handler(req, res) {
  try {
    const pathname = new URL(req.url, 'https://vercel.invalid').pathname;
    const action = pathname.replace(/^\/api\/?/, '').replace(/\/$/, '');

    if (action === 'health' && req.method === 'GET') {
      await redis().ping();
      return send(res, 200, { ok: true, storage: 'connected' });
    }
    if (action === 'config' && req.method === 'GET') {
      return send(res, 200, {
        ok: true,
        sitekey: process.env.HCAPTCHA_SITEKEY || '',
        keyHours: Number.isFinite(Number(process.env.KEY_HOURS || 24)) ? Math.max(1, Math.min(168, Number(process.env.KEY_HOURS || 24))) : 24
      });
    }
    if (action === 'admin/remote/keys' && req.method === 'GET') return await remoteAdminListKeys(req, res);
    if (action === 'admin/remote/keys' && req.method === 'POST') return await remoteAdminCreateKey(req, res);
    if (action === 'admin/remote/revoke' && req.method === 'POST') return await remoteAdminRevokeKey(req, res);
    if (action === 'start' && req.method === 'POST') return await start(req, res);
    if (action === 'claim' && req.method === 'POST') return await claim(req, res);
    if (action === 'validate' && req.method === 'POST') return await validate(req, res);
    return send(res, 404, { ok: false, error: 'API route not found.' });
  } catch (error) {
    console.error('[key-portal]', error && error.message ? error.message : 'Unknown error');
    const message = error && error.message && error.message.includes('Upstash Redis')
      ? error.message
      : 'The key server is temporarily unavailable. Check Vercel settings and try again.';
    return send(res, 500, { ok: false, error: message });
  }
};
