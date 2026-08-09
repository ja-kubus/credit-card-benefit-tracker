import 'dotenv/config';

/**
 * Centralized, validated configuration.
 *
 * Loads and validates every environment variable ONCE at boot. If a required
 * secret is missing or malformed, we fail fast with a clear (non-leaking)
 * message rather than starting in an insecure/half-configured state.
 *
 * SECURITY: nothing in here is ever logged. Do not add console.log of secrets.
 *
 * The ONLY provider secret this service holds is STRIPE_SECRET_KEY. There are
 * no per-user access tokens and no mTLS client certificate (unlike the prior
 * Teller design) — Stripe Financial Connections uses a single server-side
 * secret key for all API calls. That means there is nothing sensitive stored
 * per user: the database holds only a non-secret Stripe customer id mapping.
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

function parseOrigins(): string[] {
  return optional('CORS_ORIGINS')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
}

function loadStripeSecretKey(): string {
  const key = required('STRIPE_SECRET_KEY');
  // Sanity check the shape without logging the value. Stripe secret keys start
  // with sk_live_ or sk_test_. A publishable key (pk_) here would be a
  // dangerous misconfiguration, so reject it loudly.
  if (!/^sk_(live|test)_/.test(key)) {
    throw new Error(
      'STRIPE_SECRET_KEY must be a Stripe SECRET key (starts with sk_live_ or sk_test_). ' +
        'Do not use a publishable (pk_) key here.',
    );
  }
  return key;
}

export const config = {
  port: parseInt(optional('PORT', '8080'), 10),
  nodeEnv: optional('NODE_ENV', 'development'),
  isProd: optional('NODE_ENV', 'development') === 'production',

  corsOrigins: parseOrigins(),

  sessionSecret: required('SESSION_SECRET'),
  sessionExpiry: '30d' as const,
  sessionIssuer: 'linking-backend' as const,

  appleClientId: required('APPLE_CLIENT_ID'),
  appleIssuer: 'https://appleid.apple.com',
  appleKeysUrl: 'https://appleid.apple.com/auth/keys',

  stripe: {
    secretKey: loadStripeSecretKey(),
    // Optional: only needed if you enable the webhook endpoint for
    // financial_connections.account.refreshed_transactions events.
    webhookSecret: optional('STRIPE_WEBHOOK_SECRET'),
    apiVersion: '2025-02-24.acacia' as const,
  },

  databasePath: optional('DATABASE_PATH', './data/app.sqlite'),
} as const;

export type Config = typeof config;
