import https from 'node:https';
import { config } from './config';

/**
 * Teller API client.
 *
 * Two layers of authentication are required on every request:
 *  1. mTLS: the TLS handshake presents our client certificate + private key
 *     (config.teller.cert/key) via a shared https.Agent. Without this cert,
 *     an access token is useless — this is the core of Teller's security model.
 *  2. HTTP Basic: username = the user's access token, password = "" (empty).
 *
 * SECURITY: access tokens are only ever held in memory for the duration of a
 * request. Never log the token, the Authorization header, or the cert/key.
 */

// Single shared agent carries the client cert/key for mTLS. keepAlive reuses
// TLS connections across requests.
const agent = new https.Agent({
  cert: config.teller.cert,
  key: config.teller.key,
  keepAlive: true,
});

function basicAuthHeader(accessToken: string): string {
  // Teller: username = access token, password = empty.
  const encoded = Buffer.from(`${accessToken}:`).toString('base64');
  return `Basic ${encoded}`;
}

/**
 * Perform a GET against the Teller API using the `https` module directly.
 *
 * We deliberately do NOT use global `fetch` (undici) here: undici does not
 * honor the classic `agent` option, so the client certificate would be
 * silently dropped. Using https.request with our mTLS `agent` guarantees the
 * client cert is presented on every call.
 */
function tellerGet<T>(accessToken: string, pathname: string): Promise<T> {
  const url = new URL(`${config.teller.apiBase}${pathname}`);
  return new Promise<T>((resolve, reject) => {
    const req = https.request(
      {
        agent, // carries the mTLS client cert + key
        method: 'GET',
        hostname: url.hostname,
        port: url.port || 443,
        path: url.pathname + url.search,
        headers: {
          Authorization: basicAuthHeader(accessToken),
          Accept: 'application/json',
        },
      },
      (res) => {
        const chunks: Buffer[] = [];
        res.on('data', (c: Buffer) => chunks.push(c));
        res.on('end', () => {
          const status = res.statusCode ?? 0;
          const body = Buffer.concat(chunks).toString('utf8');
          if (status < 200 || status >= 300) {
            // Body kept for internal diagnostics only — never surfaced to clients.
            reject(new TellerError(status, body.slice(0, 500)));
            return;
          }
          try {
            resolve(JSON.parse(body) as T);
          } catch {
            reject(new TellerError(status, 'invalid_json'));
          }
        });
      },
    );
    req.on('error', reject);
    req.end();
  });
}

export class TellerError extends Error {
  constructor(
    public status: number,
    public detail: string,
  ) {
    super(`Teller API error (${status})`);
    this.name = 'TellerError';
  }
}

// ---- Raw Teller response shapes (subset we use) ----

interface TellerAccount {
  id: string;
  name?: string;
  last_four?: string;
  type?: string;
  subtype?: string;
  institution?: { name?: string };
}

interface TellerTransaction {
  id: string;
  account_id: string;
  date: string; // YYYY-MM-DD
  description?: string;
  amount: string; // Teller returns amount as a string
  details?: { category?: string | null };
}

// ---- Normalized shapes returned to the app ----

export interface AccountSummary {
  id: string;
  name: string;
  lastFour: string;
  type: string;
  subtype: string;
}

export interface NormalizedTransaction {
  id: string;
  accountId: string;
  accountName: string;
  date: string; // YYYY-MM-DD
  description: string;
  amount: number;
  category: string;
}

// ---- API methods ----

export async function listAccounts(
  accessToken: string,
): Promise<AccountSummary[]> {
  const accounts = await tellerGet<TellerAccount[]>(accessToken, '/accounts');
  return accounts.map(normalizeAccount);
}

export async function listTransactions(
  accessToken: string,
  accountId: string,
): Promise<TellerTransaction[]> {
  return tellerGet<TellerTransaction[]>(
    accessToken,
    `/accounts/${encodeURIComponent(accountId)}/transactions`,
  );
}

function normalizeAccount(a: TellerAccount): AccountSummary {
  return {
    id: a.id,
    name: a.name ?? '',
    lastFour: a.last_four ?? '',
    type: a.type ?? '',
    subtype: a.subtype ?? '',
  };
}

/**
 * Normalize a Teller transaction to the app's convention.
 *
 * SIGN CONVENTION (IMPORTANT — VERIFY AGAINST REAL TELLER SANDBOX DATA):
 *   The iOS app treats POSITIVE = purchase/spend and NEGATIVE = credit/refund.
 *   For credit-card accounts, Teller typically returns `amount` as a NEGATIVE
 *   string for purchases (money leaving the account) and POSITIVE for
 *   payments/refunds. So we NEGATE Teller's sign to match the app.
 *
 *   If sandbox testing shows the opposite polarity, flip the single line below
 *   (remove the negation, or make it conditional on account type). This is the
 *   ONLY place the sign is decided — intentionally isolated so it's easy to flip.
 */
export function normalizeTransaction(
  t: TellerTransaction,
  accountName: string,
): NormalizedTransaction {
  const tellerAmount = parseFloat(t.amount);
  const amount = Number.isFinite(tellerAmount) ? -tellerAmount : 0; // <-- flip point

  return {
    id: t.id,
    accountId: t.account_id,
    accountName,
    date: t.date,
    description: t.description ?? '',
    amount,
    category: t.details?.category ?? 'Other',
  };
}
