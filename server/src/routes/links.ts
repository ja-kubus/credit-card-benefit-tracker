import { Router, type Response } from 'express';
import { z } from 'zod';
import { requireAuth, type AuthedRequest } from '../middleware/auth';
import {
  getOrCreateCustomerId,
  findCustomerId,
  createLinkSession,
  retrieveSession,
  subscribeAccount,
  listCustomerAccounts,
  accountBelongsToCustomer,
  disconnectAccount,
  deleteCustomerData,
  StripeClientError,
} from '../stripe';
import { logger } from '../logger';

/**
 * Account linking via Stripe Financial Connections. STATELESS — no database:
 * the app-user -> Stripe-customer mapping lives in Stripe customer metadata, and
 * the linked accounts are read from Stripe on demand.
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

function handleError(res: Response, context: string, err: unknown): void {
  if (err instanceof StripeClientError) {
    logger.warn(`stripe error: ${context}`, { status: err.status, reason: err.detail });
    res.status(err.status === 400 ? 400 : 502).json({
      error: err.status === 400 ? 'invalid_request' : 'upstream_error',
    });
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
    const customerId = await getOrCreateCustomerId(userId);
    const session = await createLinkSession(customerId);
    // The client_secret is scoped to this one linking attempt; safe to hand to
    // the app for the Stripe SDK. Never log it.
    res.json({ clientSecret: session.clientSecret, sessionId: session.id });
  } catch (err) {
    handleError(res, 'link/session', err);
  }
});

// POST /link/complete — after the user finishes Stripe's sheet, read the linked
// accounts and subscribe each to daily transaction refreshes.
const completeSchema = z.object({ sessionId: z.string().min(1) });

linksRouter.post('/link/complete', async (req: AuthedRequest, res: Response) => {
  const userId = req.userId!;
  const parsed = completeSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: 'invalid_request' });
    return;
  }

  try {
    const { customerId, accounts } = await retrieveSession(parsed.data.sessionId);

    // Defense in depth: the session must belong to THIS user's customer.
    const ourCustomer = await findCustomerId(userId);
    if (!customerId || !ourCustomer || customerId !== ourCustomer) {
      res.status(403).json({ error: 'forbidden' });
      return;
    }

    for (const a of accounts) {
      // Enable transactions + kick off the first refresh. Non-fatal per account.
      try {
        await subscribeAccount(a.id);
      } catch (err) {
        logger.warn('subscribe failed for account', {
          accountId: a.id,
          category: a.category,
          subcategory: a.subcategory,
          reason:
            err instanceof StripeClientError
              ? err.detail
              : err instanceof Error
                ? err.message
                : 'unknown',
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
    const customerId = await findCustomerId(userId);
    if (!customerId) {
      res.json({ accounts: [] });
      return;
    }
    const accounts = await listCustomerAccounts(customerId);
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

  try {
    // Authorize against Stripe BEFORE disconnecting: the account must belong to
    // this user's customer, so a user can only ever disconnect their own.
    const customerId = await findCustomerId(userId);
    if (!customerId || !(await accountBelongsToCustomer(accountId, customerId))) {
      res.status(404).json({ error: 'not_found' });
      return;
    }
    await disconnectAccount(accountId);
    res.json({ ok: true });
  } catch (err) {
    handleError(res, 'unlink', err);
  }
});

// POST /delete-my-data — disconnect every account and delete the Stripe
// customer, fully forgetting the user server-side. Idempotent: a user with no
// customer yet just gets { ok: true }.
linksRouter.post('/delete-my-data', async (req: AuthedRequest, res: Response) => {
  const userId = req.userId!;
  try {
    const customerId = await findCustomerId(userId);
    if (!customerId) {
      res.json({ ok: true, disconnected: 0 });
      return;
    }
    const disconnected = await deleteCustomerData(customerId);
    res.json({ ok: true, disconnected });
  } catch (err) {
    handleError(res, 'delete-my-data', err);
  }
});
