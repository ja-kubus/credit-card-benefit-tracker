import { Router, type Request, type Response } from 'express';
import { z } from 'zod';
import { verifyAppleIdentityToken } from '../apple';
import { signSession } from '../middleware/auth';
import { logger } from '../logger';

/**
 * POST /auth/apple
 *   { identityToken } -> verify with Apple -> { sessionToken }
 *
 * Stateless: no user record is created here. A user's Stripe Customer is created
 * lazily on first link (keyed by the Apple `sub` in customer metadata).
 */
export const authRouter = Router();

const bodySchema = z.object({
  identityToken: z.string().min(1),
});

authRouter.post('/apple', async (req: Request, res: Response) => {
  const parsed = bodySchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: 'invalid_request' });
    return;
  }

  try {
    const { sub } = await verifyAppleIdentityToken(parsed.data.identityToken);
    const sessionToken = signSession(sub);
    res.json({ sessionToken });
  } catch (err) {
    // Log the failure WITHOUT the token.
    logger.warn('apple auth failed', {
      reason: err instanceof Error ? err.message : 'unknown',
    });
    res.status(401).json({ error: 'authentication_failed' });
  }
});
