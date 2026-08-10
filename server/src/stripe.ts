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
 * STATELESS DESIGN: this service keeps NO database. The only durable fact — which
 * Stripe Customer belongs to which app user — is stored inside Stripe as customer
 * metadata (`metadata.app_user = <apple sub>`) and looked up with customer search.
 * So Stripe is the single source of truth; there is nothing to persist or back up.
 *
 * Flow:
 *   1. getOrCreateCustomerId(appUserId)    — one Stripe Customer per app user,
 *                                            keyed by metadata.app_user.
 *   2. createLinkSession(customerId)       — FC Session -> { id, client_secret }.
 *                                            The client_secret is handed to the
 *                                            iOS SDK to present the auth sheet.
 *   3. (user connects accounts in Stripe's own sheet — we never see creds)
 *   4. retrieveSession(sessionId)          — read accounts + owning customer.
 *   5. subscribeAccount(accountId)         — enable daily transaction refresh.
 *   6. listCustomerAccounts(customerId)    — the user's linked accounts.
 *   7. listTransactions(accountId, after?) — read normalized transactions.
 *   8. disconnectAccount(accountId)        — on unlink.
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
      // Stripe error messages describe the API problem and contain no secrets,
      // so keep the message as `detail` for diagnostics (logged, never sent).
      throw new StripeClientError(err.statusCode ?? 502, err.message);
    }
    throw err;
  }
}

// ---- Customer (keyed by app-user metadata; no local DB) ----

/** Metadata key that maps a Stripe Customer to our app user (the Apple `sub`). */
const APP_USER_KEY = 'app_user';

/**
 * The Apple `sub` is embedded in a Stripe search query string, so restrict it to
 * a safe character set to prevent any query injection. Apple `sub`s are only
 * alphanumerics, dots, underscores and hyphens in practice.
 */
function assertSafeUserId(appUserId: string): void {
  if (!/^[A-Za-z0-9._-]{1,255}$/.test(appUserId)) {
    throw new StripeClientError(400, 'invalid_user_id');
  }
}

/**
 * Find the Stripe Customer id for an app user via customer search on metadata,
 * or null if none exists yet. Read-only — never creates.
 *
 * NOTE: Stripe's search index is eventually consistent (a just-created customer
 * may take up to ~a minute to appear). That's fine here because a returning
 * user's customer was created in an earlier session and is long since indexed.
 */
export async function findCustomerId(appUserId: string): Promise<string | null> {
  assertSafeUserId(appUserId);
  const res = await guard(() =>
    stripe.customers.search({
      query: `metadata['${APP_USER_KEY}']:'${appUserId}'`,
      limit: 1,
    }),
  );
  return res.data[0]?.id ?? null;
}

/**
 * Resolve (creating if needed) the Stripe Customer id for an app user. The
 * mapping is stored as customer metadata, so no local persistence is required.
 */
export async function getOrCreateCustomerId(appUserId: string): Promise<string> {
  const existing = await findCustomerId(appUserId);
  if (existing) return existing;
  const customer = await guard(() =>
    stripe.customers.create({
      metadata: { app: 'CreditCardBenefitTracker', [APP_USER_KEY]: appUserId },
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
      // Only let the user link CREDIT CARDS in the sheet. This avoids the
      // per-account connection fee on checking/savings the app can't use.
      filters: { account_subcategories: ['credit_card'] },
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

/**
 * This app only deals with CREDIT CARDS. Filtering to credit accounts here means
 * we never subscribe (and never pay the transactions fee) for a user's
 * checking/savings/investment accounts, and they never clutter the UI.
 *
 * Stripe's `category` is one of "cash" | "credit" | "investment" | "other";
 * credit cards fall under "credit" (subcategory "credit_card"). We gate on
 * `category === 'credit'` because subcategory is occasionally unset — this
 * reliably excludes deposit/investment accounts without risking a real card.
 */
function isCreditAccount(a: Stripe.FinancialConnections.Account): boolean {
  return a.category === 'credit';
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

export interface SessionResult {
  /** The customer the session was created for (for authorization checks). */
  customerId: string | null;
  accounts: AccountSummary[];
}

/**
 * Read back a completed FC Session: the accounts the user linked plus the
 * customer the session belongs to. The caller MUST verify `customerId` matches
 * the authenticated user before trusting the accounts (session ids are
 * unguessable, but we defend in depth).
 */
export async function retrieveSession(sessionId: string): Promise<SessionResult> {
  const session = await guard(() =>
    stripe.financialConnections.sessions.retrieve(sessionId, {
      expand: ['accounts'],
    }),
  );
  const holder = session.account_holder;
  const customerId =
    holder && 'customer' in holder && typeof holder.customer === 'string'
      ? holder.customer
      : null;
  const accounts = (session.accounts?.data ?? []).filter(isCreditAccount);
  return { customerId, accounts: accounts.map(normalizeAccount) };
}

/**
 * Verify a Financial Connections account belongs to a given customer. Used to
 * authorize /unlink so a user can only ever disconnect their own accounts.
 */
export async function accountBelongsToCustomer(
  accountId: string,
  customerId: string,
): Promise<boolean> {
  try {
    const a = await stripe.financialConnections.accounts.retrieve(accountId);
    const holder = a.account_holder;
    return (
      !!holder &&
      'customer' in holder &&
      typeof holder.customer === 'string' &&
      holder.customer === customerId
    );
  } catch {
    return false;
  }
}

/**
 * List the FC accounts currently linked AND active for a customer.
 *
 * Disconnecting an account doesn't remove it from `accounts.list` — Stripe keeps
 * it with status "inactive"/"disconnected". We filter to `status === 'active'`
 * so a disconnected account doesn't reappear after the user unlinks it.
 */
export async function listCustomerAccounts(
  customerId: string,
): Promise<AccountSummary[]> {
  const out: AccountSummary[] = [];
  for await (const a of stripe.financialConnections.accounts.list({
    account_holder: { customer: customerId },
    limit: 100,
  })) {
    if (a.status && a.status !== 'active') continue;
    if (!isCreditAccount(a)) continue; // credit cards only — this app's scope
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

/**
 * Full data deletion for a user ("forget me"): disconnect every active account,
 * then delete the Stripe Customer. Deleting the customer removes the
 * metadata.app_user mapping, so the user is fully forgotten server-side (a
 * future sign-in creates a fresh customer). Returns the number of accounts
 * disconnected.
 */
export async function deleteCustomerData(customerId: string): Promise<number> {
  const accounts = await listCustomerAccounts(customerId);
  let disconnected = 0;
  for (const a of accounts) {
    try {
      await disconnectAccount(a.id);
      disconnected += 1;
    } catch {
      // Best-effort: keep going so one bad account doesn't block deletion.
    }
  }
  await guard(() => stripe.customers.del(customerId));
  return disconnected;
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
  try {
    for await (const t of stripe.financialConnections.transactions.list(params)) {
      if (t.status === 'void') continue;
      out.push(normalizeTransaction(t, accountName));
    }
  } catch (err) {
    // Before a transaction refresh has succeeded, Stripe throws a 400 ("no
    // transactions to retrieve … subscribe/refresh to initiate"). That's not a
    // real error for us — it just means data isn't ready yet. Return empty.
    if (
      err instanceof Stripe.errors.StripeError &&
      /no transactions to retrieve|transaction refresh/i.test(err.message)
    ) {
      return [];
    }
    throw err;
  }
  return out;
}
