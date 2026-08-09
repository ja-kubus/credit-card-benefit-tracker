import { Router, type Response } from 'express';
import crypto from 'node:crypto';
import { z } from 'zod';
import { requireAuth, type AuthedRequest } from '../middleware/auth';
import { encryptToken } from '../crypto';
import { insertLink, getLinksForUser, deleteLink } from '../db';
import { decryptToken } from '../crypto';
import { listAccounts, TellerError } from '../teller';
import { logger } from '../logger';

/**
 * Link management + account listing.
 *
 *  POST   /link      { accessToken, enrollmentId, institution }
 *  GET    /accounts
 *  POST   /unlink    { linkId }
 *
 * All routes require a valid session (requireAuth). Access tokens are
 * encrypted immediately and never logged.
 */
export const linksRouter = Router();
linksRouter.use(requireAuth);

const linkSchema = z.object({
  accessToken: z.string().min(1),
  enrollmentId: z.string().min(1).optional(),
  institution: z.string().min(1).optional(),
});

// POST /link
linksRouter.post('/link', async (req: AuthedRequest, res: Response) => {
  const userId = req.userId!;
  const parsed = linkSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: 'invalid_request' });
    return;
  }
  const { accessToken, enrollmentId, institution } = parsed.data;

  const linkId = crypto.randomUUID();

  try {
    // 1. Encrypt and persist the token FIRST (so we never keep plaintext around
    //    longer than needed). token is encrypted at rest via AES-256-GCM.
    const encrypted = encryptToken(accessToken);
    insertLink({
      id: linkId,
      userId,
      institution: institution ?? null,
      enrollmentId: enrollmentId ?? null,
      token: encrypted,
    });

    // 2. Verify the link works by fetching accounts via Teller (mTLS).
    const accounts = await listAccounts(accessToken);

    res.json({ linkId, accounts });
  } catch (err) {
    if (err instanceof TellerError) {
      logger.warn('teller /accounts failed on link', { status: err.status });
      res.status(502).json({ error: 'upstream_error' });
      return;
    }
    logger.error('link failed', {
      reason: err instanceof Error ? err.message : 'unknown',
    });
    res.status(500).json({ error: 'internal_error' });
  }
});

// GET /accounts — fresh /accounts call per link, metadata only, no tokens.
linksRouter.get('/accounts', async (req: AuthedRequest, res: Response) => {
  const userId = req.userId!;
  const links = getLinksForUser(userId);

  try {
    const results = await Promise.all(
      links.map(async (link) => {
        const token = decryptToken(link.token);
        const accounts = await listAccounts(token);
        return accounts.map((a) => ({
          ...a,
          linkId: link.id,
          institution: link.institution,
        }));
      }),
    );
    res.json({ accounts: results.flat() });
  } catch (err) {
    if (err instanceof TellerError) {
      logger.warn('teller /accounts failed', { status: err.status });
      res.status(502).json({ error: 'upstream_error' });
      return;
    }
    logger.error('get accounts failed', {
      reason: err instanceof Error ? err.message : 'unknown',
    });
    res.status(500).json({ error: 'internal_error' });
  }
});

// POST /unlink — delete a link (and its token) if it belongs to the user.
const unlinkSchema = z.object({ linkId: z.string().min(1) });

linksRouter.post('/unlink', (req: AuthedRequest, res: Response) => {
  const userId = req.userId!;
  const parsed = unlinkSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: 'invalid_request' });
    return;
  }
  const deleted = deleteLink(parsed.data.linkId, userId);
  if (!deleted) {
    res.status(404).json({ error: 'not_found' });
    return;
  }
  res.json({ ok: true });
});
