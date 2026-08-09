import Stripe from 'stripe';
import { config } from './config';

/**
 * Stripe Financial Connections client.
 *
 * This is the ONLY place that talks to Stripe. Authentication is a single
 * server-side secret key (config.stripe.secretKey) — there are no per-user
 * access tokens and no mTLS client certificate. A stolen customer id or
 * account id is useless without this secret key.
 *
 * SECURITY: never log the secret key, session client secrets, or full
 * transaction payloads.
 *
 * Flow:
 *   1. getOrCreateCustomer(userId)         — one Stripe Customer per app user.
 *   2. createLinkSession(customerId)       — FC Session -> { id, client_secret }.
 *                                            The client_secret is handed to the
 *                                            iOS SDK to present the auth sheet.
 *   3. (user connects accounts in Stripe's own sheet — we never see creds)
 *   4. retrieveSession(sessionId)          — read the accounts the user linked.
 *   5. subscribeAccount(accountId)         — enable daily transaction refresh.
 *   6. listTransactions(accountId, after?) — read normalized transactions.
 *   7. disconnectAccount(accountId)        — on unlink.
 */

const stripe = new Stripe(config.stripe.secretKey, {
  apiVersion: config.stripe.apiVersion,
  // A stable app info string helps Stripe support; contains no secrets.
  appInfo: { name: 'CreditCardBenefitTracker', version: '1.0.0' },
});

export class StripeClientError extends Error {
  constructor(
    public status: number,
    public detail: string,
  ) {
    super(`Stripe API error (${status})`);
    this.name = 'StripeClientError';
  }
}

/** Wrap a Stripe call so raw Stripe errors never bubble to route handlers. */
async function guard<T>(fn: () => Promise<T>): Promise<T> {
  try {
    return await fn();
  } catch (err) {
    if (err instanceof Stripe.errors.StripeError) {
      throw new StripeClientError(err.statusCode ?? 502, err.type);
    }
    throw err;
  }
}

// ---- Customer ----

/**
 * Create a Stripe Customer to represent this app user, or return an existing
 * one. The caller is responsible for persisting the returned id against the
 * user so we don't create duplicates. `existingCustomerId` short-circuits the
 * create when we already have one on file.
 */
export async function getOrCreateCustomer(
  existingCustomerId: string | null,
): Promise<string> {
  if (existingCustomerId) return existingCustomerId;
  const customer = await guard(() =>
    stripe.customers.create({
      metadata: { app: 'CreditCardBenefitTracker' },
    }),
  );
  return customer.id;
}

// ---- Link session ----

export interface LinkSession {
  id: string;
  clientSecret: string;
}

/**
 * Create a Financial Connections Session scoped to a customer, requesting
 * ONLY the `transactions` permission (least privilege — no balances, no
 * ownership/PII, no payment_method). `prefetch` starts a transaction refresh
 * the moment the user links, minimizing the wait before data is available.
 */
export async function createLinkSession(
  customerId: string,
): Promise<LinkSession> {
  const session = await guard(() =>
    stripe.financialConnections.sessions.create({
      account_holder: { type: 'customer', customer: customerId },
      permissions: ['transactions'],
      prefetch: ['transactions'],
    }),
  );
  if (!session.client_secret) {
    throw new StripeClientError(502, 'session_missing_client_secret');
  }
  return { id: session.id, clientSecret: session.client_secret };
}

// ---- Accounts ----

export interface AccountSummary {
  id: string;
  displayName: string;
  institution: string;
  last4: string;
  category: string; // e.g. "credit", "cash"
  subcategory: string; // e.g. "credit_card", "checking"
}

function normalizeAccount(
  a: Stripe.FinancialConnections.Account,
): AccountSummary {
  return {
    id: a.id,
    displayName: a.display_name ?? '',
    institution: a.institution_name ?? '',
    last4: a.last4 ?? '',
    category: a.category ?? '',
    subcategory: a.subcategory ?? '',
  };
}

/**
 * Read back the accounts a user linked in a completed FC Session. The Session's
 * `accounts` is an expandable list; retrieve with it expanded.
 */
export async function retrieveSessionAccounts(
  sessionId: string,
): Promise<AccountSummary[]> {
  const session = await guard(() =>
    stripe.financialConnections.sessions.retrieve(sessionId, {
      expand: ['accounts'],
    }),
  );
  const accounts = session.accounts?.data ?? [];
  return accounts.map(normalizeAccount);
}

/** List every FC account currently linked to a customer. */
export async function listCustomerAccounts(
  customerId: string,
): Promise<AccountSummary[]> {
  const out: AccountSummary[] = [];
  for await (const a of stripe.financialConnections.accounts.list({
    account_holder: { customer: customerId },
    limit: 100,
  })) {
    out.push(normalizeAccount(a));
  }
  return out;
}

/**
 * Subscribe an account to daily transaction refreshes. This also kicks off an
 * immediate refresh so data becomes available without waiting for the nightly
 * cycle. Safe to call repeatedly (idempotent from our perspective).
 */
export async function subscribeAccount(accountId: string): Promise<void> {
  await guard(() =>
    stripe.financialConnections.accounts.subscribe(accountId, {
      features: ['transactions'],
    }),
  );
}

/**
 * Disconnect an account (Stripe stops refreshing it and it's removed from the
 * customer). Used on unlink. Ignores "already disconnected" style errors so
 * unlink is idempotent.
 */
export async function disconnectAccount(accountId: string): Promise<void> {
  try {
    await stripe.financialConnections.accounts.disconnect(accountId);
  } catch (err) {
    if (err instanceof Stripe.errors.StripeError) {
      // Treat a not-found / already-disconnected account as success.
      if (err.statusCode === 404) return;
      throw new StripeClientError(err.statusCode ?? 502, err.type);
    }
    throw err;
  }
}

// ---- Transactions ----

export interface NormalizedTransaction {
  id: string;
  accountId: string;
  accountName: string;
  date: string; // YYYY-MM-DD (UTC)
  description: string;
  amount: number; // dollars; POSITIVE = purchase/spend, NEGATIVE = credit/refund
  status: string; // "posted" | "pending" | "void"
  category: string; // always "Other" — the app categorizes on-device
}

/**
 * SIGN + UNIT CONVENTION (verified against Stripe docs; re-verify with real data):
 *   Stripe returns `amount` as an INTEGER in the account currency's minor unit
 *   (cents) and, for a purchase/outflow, as a NEGATIVE number
 *   (e.g. -1000 = $10.00 spent, description "Rocket Rides").
 *
 *   The iOS app's convention is the opposite: POSITIVE = purchase/spend,
 *   NEGATIVE = credit/refund, in whole dollars. So we NEGATE and divide by 100.
 *   This is the ONLY place the sign/unit is decided — intentionally isolated so
 *   it's trivial to flip if real data shows a different polarity.
 */
function normalizeTransaction(
  t: Stripe.FinancialConnections.Transaction,
  accountName: string,
): NormalizedTransaction {
  const cents = typeof t.amount === 'number' ? t.amount : 0;
  const amount = -cents / 100; // <-- flip point (sign + cents->dollars)

  // transacted_at is a unix timestamp (seconds, UTC). Fall back gracefully.
  const secs = t.transacted_at ?? t.status_transitions?.posted_at ?? 0;
  const date = secs
    ? new Date(secs * 1000).toISOString().slice(0, 10)
    : '';

  return {
    id: t.id,
    accountId: typeof t.account === 'string' ? t.account : '',
    accountName,
    date,
    description: t.description ?? '',
    amount,
    status: t.status ?? '',
    category: 'Other',
  };
}

/**
 * List transactions for an account. Optionally only those from refreshes after
 * a given transaction_refresh cursor (for incremental sync). Excludes `void`
 * transactions. Returns up to Stripe's ~180-day window.
 */
export async function listTransactions(
  accountId: string,
  accountName: string,
  afterRefresh?: string | null,
): Promise<NormalizedTransaction[]> {
  const params: Stripe.FinancialConnections.TransactionListParams = {
    account: accountId,
    limit: 100,
  };
  if (afterRefresh) {
    params.transaction_refresh = { after: afterRefresh };
  }

  const out: NormalizedTransaction[] = [];
  for await (const t of stripe.financialConnections.transactions.list(params)) {
    if (t.status === 'void') continue;
    out.push(normalizeTransaction(t, accountName));
  }
  return out;
}
