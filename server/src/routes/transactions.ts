import { Router, type Response } from 'express';
import { z } from 'zod';
import { requireAuth, type AuthedRequest } from '../middleware/auth';
import { decryptToken } from '../crypto';
import { getLinksForUser } from '../db';
import {
  listAccounts,
  listTransactions,
  normalizeTransaction,
  TellerError,
  type NormalizedTransaction,
} from '../teller';
import { logger } from '../logger';

/**
 * GET /transactions?since=YYYY-MM-DD
 *
 * For each link: decrypt token, list accounts, list transactions per account,
 * filter by `since`, normalize to the app's shape. Transactions are NEVER
 * persisted here — they are returned to the app for on-device storage only.
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

  const links = getLinksForUser(userId);

  try {
    const all: NormalizedTransaction[] = [];

    for (const link of links) {
      const token = decryptToken(link.token);
      const accounts = await listAccounts(token);

      for (const account of accounts) {
        const raw = await listTransactions(token, account.id);
        for (const t of raw) {
          if (since && t.date < since) continue; // lexical compare is valid for YYYY-MM-DD
          all.push(normalizeTransaction(t, account.name));
        }
      }
    }

    // Sort newest first for convenience.
    all.sort((a, b) => (a.date < b.date ? 1 : a.date > b.date ? -1 : 0));

    res.json({ transactions: all });
  } catch (err) {
    if (err instanceof TellerError) {
      logger.warn('teller transactions failed', { status: err.status });
      res.status(502).json({ error: 'upstream_error' });
      return;
    }
    logger.error('get transactions failed', {
      reason: err instanceof Error ? err.message : 'unknown',
    });
    res.status(500).json({ error: 'internal_error' });
  }
});
