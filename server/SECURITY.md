# Security

This document describes the trust model, secret handling, and incident response
for the linking backend (Stripe Financial Connections).

## Trust model in one paragraph

The iOS app holds **no secrets** — only a 30-day session JWT. The **only**
provider secret is `STRIPE_SECRET_KEY`, held in the server's environment
(injected from a secret manager at runtime, never in the image or in git). The
service is **stateless**: no database, no disk. The only durable fact — which
Stripe Customer maps to which app user — lives in Stripe as customer metadata
(`metadata.app_user = <Apple sub>`). Bank credentials are entered **only** inside
Stripe's own Financial Connections sheet; neither the app nor this server ever
sees them. Transactions are fetched live from Stripe, returned to the app, and
stored **on-device only** — never persisted server-side.

## Secrets inventory

| Secret | Where it lives | If leaked |
| ------ | -------------- | --------- |
| `STRIPE_SECRET_KEY` | Server env only (Secret Manager) | Roll immediately in Stripe Dashboard; old key dies at once. No local datastore to expose. |
| `SESSION_SECRET` | Server env only (Secret Manager) | Rotate; all session JWTs invalidate, users re-authenticate. |
| Stripe **publishable** key (`pk_`) | Ships in the app (non-secret) | Not sensitive; publishable keys are designed to be public. |
| Apple session JWT | On device (Keychain) | Scoped, 30-day expiry; rotate `SESSION_SECRET` to mass-invalidate. |

There are **no** per-user access tokens and **no** mTLS certificate to manage.

## Handling rules

- **Never commit secrets.** `.env`, `*.pem`, `*.key`, `certs/` are gitignored.
  Verify before your first push:

  ```bash
  cd server && git check-ignore .env    # must print ".env"
  ```

- **Test vs live.** Use `sk_test_` / `pk_test_` in development. Put the live
  `sk_live_` key only in the deployed environment's secret manager — never on a
  laptop, never in a file committed anywhere.

- **Never log secrets.** `src/logger.ts` redacts known-sensitive keys
  (`authorization`, `client_secret`, `secret_key`, session tokens, …) as a
  safety net, but the primary rule is: don't pass them to the logger. Stripe
  *error messages* are safe to log (no secrets) and are kept as diagnostics.

- **Least privilege.** Financial Connections sessions request only the
  `transactions` permission — no balances, ownership/PII, or payment-method data.

## Endpoint authorization

- All linking/transaction routes require `Authorization: Bearer <session JWT>`
  (`requireAuth`), verified with `SESSION_SECRET` (HS256, issuer check).
- Apple identity tokens are verified against Apple's JWKS (signature, `iss`,
  `aud = APPLE_CLIENT_ID`, `exp`); only the immutable `sub` is trusted.
- `/link/complete` verifies the session's customer matches the caller.
- `/unlink` verifies (via Stripe) the account belongs to the caller's customer
  before disconnecting.
- The Apple `sub` is charset-validated before being embedded in a Stripe
  customer-search query (no query injection).
- Hardening: `helmet`, `express-rate-limit` (global + stricter `/auth`), CORS
  locked to `CORS_ORIGINS`, 64 KB JSON body cap, zod validation, generic error
  responses (no stack traces / internals leaked).

## Data deletion

- `POST /unlink { accountId }` disconnects one account. The app also deletes that
  account's on-device transactions + mapping.
- `POST /delete-my-data` disconnects every account and **deletes the Stripe
  customer**, removing the `app_user` mapping entirely (full "forget me"). The
  app clears all on-device linked data alongside it.

## Incident response

1. **`STRIPE_SECRET_KEY` suspected leaked**
   - Roll it in the [Stripe Dashboard → API keys](https://dashboard.stripe.com/apikeys).
   - Add the new value as a new secret version and redeploy.
   - Review recent Stripe API logs for unexpected calls.
2. **`SESSION_SECRET` suspected leaked**
   - Rotate it and redeploy; all issued session JWTs immediately invalidate and
     users must sign in again.
3. **A secret was committed to git**
   - Roll the secret first (assume it's compromised the moment it's pushed).
   - Then remove it from history (`git filter-repo` / BFG) and force-push.

## Reporting

Found a vulnerability? Email the maintainer rather than opening a public issue,
and allow reasonable time to remediate before disclosure.
