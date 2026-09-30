'use strict';

// Port of backend/lib/user.dart
const fs = require('node:fs');
const crypto = require('node:crypto');

const TOKEN_TTL_MS = 7 * 24 * 60 * 60 * 1000;

function sha256Hex(str) {
  return crypto.createHash('sha256').update(String(str), 'utf8').digest('hex');
}

function hashPassword(password) {
  return sha256Hex(password);
}

function verifyPassword(password, hash) {
  return hashPassword(password) === hash;
}

function generateToken(username) {
  const timestamp = Date.now();
  const random = crypto.randomInt(0, 1000000).toString();
  const combined = `${username}.${timestamp}.${random}`;
  const hash = sha256Hex(combined).substring(0, 16);
  return `${username}.${timestamp}.${hash}`;
}

function toPublic(user) {
  return {
    id: user.id,
    username: user.username,
    email: user.email ?? null,
    created_at: user.created_at,
  };
}

function userFromJson(json) {
  if (!json || typeof json.id !== 'string' || typeof json.username !== 'string' ||
      typeof json.password_hash !== 'string' || typeof json.created_at !== 'string') {
    throw new Error('Invalid user record');
  }
  return {
    id: json.id,
    username: json.username,
    password_hash: json.password_hash,
    email: typeof json.email === 'string' ? json.email : null,
    created_at: json.created_at, // kept verbatim (ISO-8601)
  };
}

class UserStore {
  constructor({ filePath }) {
    this.filePath = filePath;
    this.users = new Map();  // username -> user
    this.tokens = new Map(); // token -> { token, username, expiresAt (ms) }
  }

  load() {
    try {
      const content = fs.readFileSync(this.filePath, 'utf8');
      const data = JSON.parse(content);
      for (const u of data.users) {
        const user = userFromJson(u);
        this.users.set(user.username, user);
      }
    } catch (_) {
      // File doesn't exist or is invalid
    }
  }

  save() {
    const data = {
      users: [...this.users.values()].map((u) => ({
        id: u.id,
        username: u.username,
        password_hash: u.password_hash,
        email: u.email ?? null,
        created_at: u.created_at,
      })),
    };
    fs.writeFileSync(this.filePath, JSON.stringify(data));
  }

  signup(username, password, email = null) {
    if (this.users.has(username)) return null;
    if (typeof password !== 'string' || password.length < 6) return null;
    const user = {
      id: crypto.randomUUID(),
      username,
      password_hash: hashPassword(password),
      email: email ?? null,
      created_at: new Date().toISOString(),
    };
    this.users.set(username, user);
    this.save();
    return user;
  }

  login(username, password) {
    const user = this.users.get(username);
    if (!user || !verifyPassword(password, user.password_hash)) return null;
    return user;
  }

  createToken(username) {
    const token = generateToken(username);
    this.tokens.set(token, { token, username, expiresAt: Date.now() + TOKEN_TTL_MS });
    return token;
  }

  validateToken(token) {
    const auth = this.tokens.get(token);
    if (!auth || Date.now() >= auth.expiresAt) {
      this.tokens.delete(token);
      return null;
    }
    return this.users.get(auth.username) ?? null;
  }

  revokeToken(token) {
    this.tokens.delete(token);
  }
}

module.exports = { UserStore, toPublic, hashPassword, verifyPassword };
