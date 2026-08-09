import type { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { config } from '../config';

/**
 * Auth middleware: requires `Authorization: Bearer <our session JWT>`.
 * Verifies the JWT (HS256, SESSION_SECRET) and attaches userId to the request.
 *
 * Returns generic 401s — never reveal WHY verification failed.
 */

export interface AuthedRequest extends Request {
  userId?: string;
}

interface SessionClaims {
  sub: string;
}

export function signSession(userId: string): string {
  return jwt.sign({}, config.sessionSecret, {
    subject: userId,
    expiresIn: config.sessionExpiry,
    issuer: config.sessionIssuer,
  });
}

export function requireAuth(
  req: AuthedRequest,
  res: Response,
  next: NextFunction,
): void {
  const header = req.header('authorization') ?? '';
  const match = /^Bearer\s+(.+)$/i.exec(header);
  if (!match || !match[1]) {
    res.status(401).json({ error: 'unauthorized' });
    return;
  }

  try {
    const decoded = jwt.verify(match[1], config.sessionSecret, {
      issuer: config.sessionIssuer,
    }) as unknown as SessionClaims;
    if (!decoded.sub) {
      res.status(401).json({ error: 'unauthorized' });
      return;
    }
    req.userId = decoded.sub;
    next();
  } catch {
    res.status(401).json({ error: 'unauthorized' });
  }
}
