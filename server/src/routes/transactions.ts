import { Router, type Response } from 'express';
import { z } from 'zod';
import { requireAuth, type AuthedRequest } from '../middleware/auth';
import {
  findCustomerId,
  listCustomerAccounts,
  listTransactions,
  StripeClientError,
  type NormalizedTransaction,
} from '../stripe';
import { logger } from '../logger';

/**
 * GET /transactions?since=YYYY-MM-DD
 *
 * For each of the user's linked accounts, list transactions from Stripe,
 * optionally filtered to on/after `since`, normalized to the app's shape.
 * Transactions are NEVER persisted here — they are returned to the app for
 * on-device storage only.
 */
export const transactionsRouter = Router();
transactionsRouter.use(requireAuth);

const querySchema = z.object({
  since: z
    .string()
    .regex(/^\d{4}-\d{2}-\d{2}$/, 'since must be YYYY-MM-DD')
    .optional(),
});

transactionsRouter.get('/transactions', async (req: AuthedRequest, res: Response) => {
  const userId = req.userId!;
  const parsed = querySchema.safeParse(req.query);
  if (!parsed.success) {
    res.status(400).json({ error: 'invalid_request' });
    return;
  }
  const since = parsed.data.since;

  try {
    const customerId = await findCustomerId(userId);
    if (!customerId) {
      res.json({ transactions: [] });
      return;
    }
    const accounts = await listCustomerAccounts(customerId);

    const all: NormalizedTransaction[] = [];

    for (const account of accounts) {
      const name = account.displayName || account.institution || 'Account';
      const raw = await listTransactions(account.id, name);
      for (const t of raw) {
        if (since && t.date && t.date < since) continue; // lexical compare valid for YYYY-MM-DD
        all.push(t);
      }
    }

    // Sort newest first for convenience.
    all.sort((a, b) => (a.date < b.date ? 1 : a.date > b.date ? -1 : 0));

    res.json({ transactions: all });
  } catch (err) {
    if (err instanceof StripeClientError) {
      logger.warn('stripe transactions failed', { status: err.status });
      res.status(502).json({ error: 'upstream_error' });
      return;
    }
    logger.error('get transactions failed', {
      reason: err instanceof Error ? err.message : 'unknown',
    });
    res.status(500).json({ error: 'internal_error' });
  }
});
