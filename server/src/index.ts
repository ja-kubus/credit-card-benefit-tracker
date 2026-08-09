import express, { type Request, type Response, type NextFunction } from 'express';
import helmet from 'helmet';
import cors from 'cors';
import rateLimit from 'express-rate-limit';
import { config } from './config';
import { logger } from './logger';
import { authRouter } from './routes/auth';
import { linksRouter } from './routes/links';
import { transactionsRouter } from './routes/transactions';

/**
 * App entrypoint. Wires security middleware, rate limiting, CORS, and routes.
 * Importing ./config first validates all secrets and fails fast if misconfigured.
 */

const app = express();

// Behind a proxy/load balancer in production so rate-limit sees real client IPs.
app.set('trust proxy', 1);

// Security headers.
app.use(helmet());

// CORS locked to configured origins. Requests with no Origin header (e.g. a
// native iOS app or curl) are allowed through; browser origins must match.
app.use(
  cors({
    origin(origin, callback) {
      if (!origin || config.corsOrigins.includes(origin)) {
        callback(null, true);
      } else {
        callback(new Error('origin_not_allowed'));
      }
    },
  }),
);

app.use(express.json({ limit: '64kb' }));

// Global rate limit — coarse protection against abuse.
const globalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 min
  max: 300,
  standardHeaders: true,
  legacyHeaders: false,
});
app.use(globalLimiter);

// Stricter limit on the auth endpoint (unauthenticated, more sensitive).
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 30,
  standardHeaders: true,
  legacyHeaders: false,
});

// Health check — no auth, no secrets.
app.get('/health', (_req: Request, res: Response) => {
  res.json({ status: 'ok' });
});

// Routes.
app.use('/auth', authLimiter, authRouter);
app.use('/', linksRouter); // /link, /accounts, /unlink
app.use('/', transactionsRouter); // /transactions

// 404.
app.use((_req: Request, res: Response) => {
  res.status(404).json({ error: 'not_found' });
});

// Generic error handler — never leak internals or stack traces to clients.
// eslint-disable-next-line @typescript-eslint/no-unused-vars
app.use((err: unknown, _req: Request, res: Response, _next: NextFunction) => {
  logger.error('unhandled error', {
    reason: err instanceof Error ? err.message : 'unknown',
  });
  if (res.headersSent) return;
  res.status(500).json({ error: 'internal_error' });
});

app.listen(config.port, () => {
  logger.info('server listening', {
    port: config.port,
    env: config.nodeEnv,
    corsOrigins: config.corsOrigins,
  });
});
