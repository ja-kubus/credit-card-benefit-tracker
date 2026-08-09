import 'dotenv/config';
import fs from 'node:fs';

/**
 * Centralized, validated configuration.
 *
 * Loads and validates every environment variable ONCE at boot. If a required
 * secret is missing or malformed, we fail fast with a clear (non-leaking)
 * message rather than starting in an insecure/half-configured state.
 *
 * SECURITY: nothing in here is ever logged. Do not add console.log of secrets.
 */

function required(name: string): string {
  const v = process.env[name];
  if (!v || v.trim() === '') {
    throw new Error(`Missing required env var: ${name}`);
  }
  return v;
}

function optional(name: string, fallback = ''): string {
  const v = process.env[name];
  return v && v.trim() !== '' ? v : fallback;
}

/**
 * Resolve the Teller client cert + key from EITHER inline PEM env vars OR file
 * paths. Inline PEM takes precedence if both are set. Never logs contents.
 */
function loadTellerCredentials(): { cert: string; key: string } {
  const certPem = optional('TELLER_CERT_PEM');
  const keyPem = optional('TELLER_KEY_PEM');

  if (certPem && keyPem) {
    return { cert: certPem, key: keyPem };
  }

  const certPath = optional('TELLER_CERT_PATH');
  const keyPath = optional('TELLER_KEY_PATH');

  if (certPath && keyPath) {
    try {
      const cert = fs.readFileSync(certPath, 'utf8');
      const key = fs.readFileSync(keyPath, 'utf8');
      return { cert, key };
    } catch {
      // Do NOT include the raw fs error (could leak paths/contents in some setups).
      throw new Error(
        'Failed to read Teller cert/key from TELLER_CERT_PATH / TELLER_KEY_PATH',
      );
    }
  }

  throw new Error(
    'Teller mTLS credentials not configured. Set TELLER_CERT_PEM + TELLER_KEY_PEM ' +
      'or TELLER_CERT_PATH + TELLER_KEY_PATH.',
  );
}

/**
 * Decode and validate the 32-byte AES-256 master key from base64.
 */
function loadMasterKey(): Buffer {
  const raw = required('MASTER_KEY');
  let key: Buffer;
  try {
    key = Buffer.from(raw, 'base64');
  } catch {
    throw new Error('MASTER_KEY is not valid base64');
  }
  if (key.length !== 32) {
    throw new Error(
      `MASTER_KEY must decode to exactly 32 bytes (got ${key.length}). ` +
        'Generate with: openssl rand -base64 32',
    );
  }
  return key;
}

function parseOrigins(): string[] {
  return optional('CORS_ORIGINS')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
}

const tellerCreds = loadTellerCredentials();

export const config = {
  port: parseInt(optional('PORT', '8080'), 10),
  nodeEnv: optional('NODE_ENV', 'development'),
  isProd: optional('NODE_ENV', 'development') === 'production',

  corsOrigins: parseOrigins(),

  sessionSecret: required('SESSION_SECRET'),
  sessionExpiry: '30d' as const,

  masterKey: loadMasterKey(),

  appleClientId: required('APPLE_CLIENT_ID'),
  appleIssuer: 'https://appleid.apple.com',
  appleKeysUrl: 'https://appleid.apple.com/auth/keys',

  teller: {
    apiBase: optional('TELLER_API_BASE', 'https://api.teller.io'),
    cert: tellerCreds.cert,
    key: tellerCreds.key,
  },

  databasePath: optional('DATABASE_PATH', './data/app.sqlite'),
} as const;

export type Config = typeof config;
