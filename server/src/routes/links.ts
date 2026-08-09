import { Router, type Response } from 'express';
import { z } from 'zod';
import { requireAuth, type AuthedRequest } from '../middleware/auth';
import {
  upsertUser,
  getUser,
  setCustomerId,
  upsertAccount,
  getAccountsForUser,
  deleteAccount,
  userOwnsAccount,
} from '../db';
import {
  getOrCreateCustomer,
  createLinkSession,
  retrieveSessionAccounts,
  subscribeAccount,
  listCustomerAccounts,
  disconnectAccount,
  StripeClientError,
} from '../stripe';
import { logger } from '../logger';

/**
 * Account linking via Stripe Financial Connections.
 *
 *  POST   /link/session            -> { clientSecret, sessionId }
 *  POST   /link/complete  { sessionId } -> { accounts }
 *  GET    /accounts                -> { accounts }
 *  POST   /unlink        { accountId }  -> { ok }
 *
 * All routes require a valid session (requireAuth). No provider secrets pass
 * through here; the client only ever receives a Stripe Session client_secret,
 * which is scoped to a single linking attempt.
 */
export const linksRouter = Router();
linksRouter.use(requireAuth);

/** Resolve (creating if needed) the Stripe customer id for this app user. */
async function ensureCustomerId(userId: string): Promise<string> {
  upsertUser(userId);
  const existing = getUser(userId)?.stripeCustomerId ?? null;
  const customerId = await getOrCreateCustomer(existing);
  if (customerId !== existing) {
    setCustomerId(userId, customerId);
  }
  return customerId;
}

function handleError(res: Response, context: string, err: unknown): void {
  if (err instanceof StripeClientError) {
    logger.warn(`stripe error: ${context}`, { status: err.status });
    res.status(502).json({ error: 'upstream_error' });
    return;
  }
  logger.error(`${context} failed`, {
    reason: err instanceof Error ? err.message : 'unknown',
  });
  res.status(500).json({ error: 'internal_error' });
}

// POST /link/session — create a Financial Connections Session for the SDK.
linksRouter.post('/link/session', async (req: AuthedRequest, res: Response) => {
  const userId = req.userId!;
  try {
    const customerId = await ensureCustomerId(userId);
    const session = await createLinkSession(customerId);
    // The client_secret is scoped to this one linking attempt; safe to hand to
    // the app for the Stripe SDK. Never log it.
    res.json({ clientSecret: session.clientSecret, sessionId: session.id });
  } catch (err) {
    handleError(res, 'link/session', err);
  }
});

// POST /link/complete — after the user finishes Stripe's sheet, read the linked
// accounts, persist them, and subscribe each to daily transaction refreshes.
const completeSchema = z.object({ sessionId: z.string().min(1) });

linksRouter.post('/link/complete', async (req: AuthedRequest, res: Response) => {
  const userId = req.userId!;
  const parsed = completeSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: 'invalid_request' });
    return;
  }

  try {
    const accounts = await retrieveSessionAccounts(parsed.data.sessionId);

    for (const a of accounts) {
      upsertAccount({
        id: a.id,
        userId,
        institution: a.institution || null,
        displayName: a.displayName || null,
        last4: a.last4 || null,
      });
      // Enable transactions + kick off the first refresh. Non-fatal per account.
      try {
        await subscribeAccount(a.id);
      } catch (err) {
        logger.warn('subscribe failed for account', {
          reason: err instanceof Error ? err.message : 'unknown',
        });
      }
    }

    res.json({ accounts });
  } catch (err) {
    handleError(res, 'link/complete', err);
  }
});

// GET /accounts — the accounts currently linked to this user (metadata only).
linksRouter.get('/accounts', async (req: AuthedRequest, res: Response) => {
  const userId = req.userId!;
  try {
    const user = getUser(userId);
    if (!user?.stripeCustomerId) {
      res.json({ accounts: [] });
      return;
    }
    const accounts = await listCustomerAccounts(user.stripeCustomerId);
    // Keep our local mirror fresh so /transactions and /unlink stay consistent.
    for (const a of accounts) {
      upsertAccount({
        id: a.id,
        userId,
        institution: a.institution || null,
        displayName: a.displayName || null,
        last4: a.last4 || null,
      });
    }
    res.json({ accounts });
  } catch (err) {
    handleError(res, 'accounts', err);
  }
});

// POST /unlink — disconnect an account if it belongs to the user.
const unlinkSchema = z.object({ accountId: z.string().min(1) });

linksRouter.post('/unlink', async (req: AuthedRequest, res: Response) => {
  const userId = req.userId!;
  const parsed = unlinkSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: 'invalid_request' });
    return;
  }
  const { accountId } = parsed.data;

  // Authorize against our own records BEFORE calling Stripe, so a user can only
  // ever disconnect their own accounts.
  if (!userOwnsAccount(accountId, userId)) {
    res.status(404).json({ error: 'not_found' });
    return;
  }

  try {
    await disconnectAccount(accountId);
    deleteAccount(accountId, userId);
    res.json({ ok: true });
  } catch (err) {
    handleError(res, 'unlink', err);
  }
});
