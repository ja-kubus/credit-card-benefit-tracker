/**
 * Minimal structured logger with redaction.
 *
 * SECURITY: never pass tokens, cert/key material, MASTER_KEY, or full
 * transaction payloads to the logger. The redact() helper is a best-effort
 * safety net for known-sensitive keys, but the primary rule is "don't log
 * secrets in the first place".
 */

const SENSITIVE_KEYS = new Set([
  'accesstoken',
  'access_token',
  'token',
  'token_ciphertext',
  'token_iv',
  'token_tag',
  'identitytoken',
  'identity_token',
  'sessiontoken',
  'session_token',
  'client_secret',
  'clientsecret',
  'stripe_secret_key',
  'secretkey',
  'secret_key',
  'authorization',
  'password',
  'masterkey',
  'master_key',
  'cert',
  'key',
  'privatekey',
  'private_key',
]);

function redactValue(): string {
  return '[REDACTED]';
}

export function redact(obj: unknown): unknown {
  if (obj === null || typeof obj !== 'object') return obj;
  if (Array.isArray(obj)) return obj.map(redact);
  const out: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(obj as Record<string, unknown>)) {
    if (SENSITIVE_KEYS.has(k.toLowerCase())) {
      out[k] = redactValue();
    } else {
      out[k] = redact(v);
    }
  }
  return out;
}

function line(level: string, msg: string, meta?: Record<string, unknown>): void {
  const entry: Record<string, unknown> = {
    ts: new Date().toISOString(),
    level,
    msg,
  };
  if (meta) Object.assign(entry, redact(meta) as Record<string, unknown>);
  // eslint-disable-next-line no-console
  console.log(JSON.stringify(entry));
}

export const logger = {
  info: (msg: string, meta?: Record<string, unknown>) => line('info', msg, meta),
  warn: (msg: string, meta?: Record<string, unknown>) => line('warn', msg, meta),
  error: (msg: string, meta?: Record<string, unknown>) => line('error', msg, meta),
};
