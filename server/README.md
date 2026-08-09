# Linking Backend (Stripe Financial Connections)

Security-first Node.js + TypeScript backend for a [Stripe Financial
Connections](https://docs.stripe.com/financial-connections) integration.

This service is the **only** place a provider secret lives — the Stripe
**secret key** (`sk_...`), held in env and never on the device. There are **no
per-user access tokens and no mTLS certificate** (unlike a Teller design):
Stripe FC authenticates every call with the one server-side secret key, so the
database holds nothing sensitive — only a non-secret Apple-user → Stripe-customer
mapping and the linked account ids.

The iOS app authenticates with Sign in with Apple, receives a short-lived
session JWT, and asks this server for account and transaction data. The user
enters bank credentials only inside Stripe's own `FinancialConnectionsSheet` —
this server and the app never see them. Transactions are **never persisted**
server-side; they are fetched live from Stripe, normalized, and returned to the
app for **on-device storage only**.

---

## Architecture

```
iOS app ──(Apple identity token)──▶ POST /auth/apple ──▶ { sessionToken }

iOS app ──(Bearer sessionToken)──▶ POST /link/session ──▶ { clientSecret }
                                        │  creates Stripe Customer + FC Session
                                        ▼
iOS app presents Stripe FinancialConnectionsSheet(clientSecret)
  (user picks bank + authenticates INSIDE Stripe's UI — creds never touch us)
                                        │
iOS app ──(Bearer)──▶ POST /link/complete { sessionId }
                                        │  reads linked accounts, subscribes
                                        ▼
iOS app ──(Bearer)──▶ GET /transactions?since=YYYY-MM-DD
                                        │  lists via Stripe secret key
                                        └─▶ normalized txns (NOT stored here)
```

### File tree

```
server/
├── package.json          # scripts: dev / build / start / typecheck
├── tsconfig.json
├── Dockerfile            # multi-stage, non-root runtime
├── .dockerignore
├── .gitignore
├── .env.example          # every env var, documented
├── README.md
└── src/
    ├── index.ts          # express app: helmet, cors, rate-limit, routes
    ├── config.ts         # loads + validates all env (fails fast)
    ├── logger.ts         # structured logging with secret redaction
    ├── db.ts             # better-sqlite3: users + accounts (no txn table)
    ├── apple.ts          # Sign in with Apple identity-token verification
    ├── stripe.ts         # Stripe Financial Connections client + normalization
    ├── middleware/
    │   └── auth.ts       # Bearer session JWT verify + issue
    └── routes/
        ├── auth.ts       # POST /auth/apple
        ├── links.ts      # POST /link/session, /link/complete, GET /accounts, POST /unlink
        └── transactions.ts # GET /transactions?since=YYYY-MM-DD
```

---

## Endpoints

| Method | Path | Auth | Body / Query | Returns |
| ------ | ---- | ---- | ------------ | ------- |
| GET | `/health` | none | — | `{ status: "ok" }` |
| POST | `/auth/apple` | none | `{ identityToken }` | `{ sessionToken }` |
| POST | `/link/session` | Bearer | — | `{ clientSecret, sessionId }` |
| POST | `/link/complete` | Bearer | `{ sessionId }` | `{ accounts: [...] }` |
| GET | `/accounts` | Bearer | — | `{ accounts: [...] }` |
| GET | `/transactions` | Bearer | `?since=YYYY-MM-DD` | `{ transactions: [...] }` |
| POST | `/unlink` | Bearer | `{ accountId }` | `{ ok: true }` |

All authenticated routes require `Authorization: Bearer <sessionToken>`.

Normalized transaction shape:

```json
{
  "id": "fctxn_...",
  "accountId": "fca_...",
  "accountName": "Sapphire Reserve",
  "date": "2026-08-01",
  "description": "COFFEE SHOP",
  "amount": 4.75,
  "status": "posted",
  "category": "Other"
}
```

**Sign / unit convention:** POSITIVE = purchase/spend, NEGATIVE = credit/refund,
in whole dollars. Stripe returns `amount` as an integer in cents that is
typically **negative** for a purchase; we negate and divide by 100. This is
isolated to a single line in `src/stripe.ts` (`normalizeTransaction`) and
**should be verified against real data** — flip it if the polarity is reversed.
`category` is always `"Other"`; the iOS app categorizes on-device with its own
merchant rules.

---

## Stripe setup

1. In the [Stripe Dashboard](https://dashboard.stripe.com), complete the
   [Financial Connections registration](https://dashboard.stripe.com/settings/financial-connections)
   (required for **live** mode; **test** data works immediately).
2. Copy your **secret key** (`sk_test_...` for development) from
   [API keys](https://dashboard.stripe.com/apikeys) into `STRIPE_SECRET_KEY`.
3. (Optional) To use incremental sync via webhooks, create a webhook for
   `financial_connections.account.refreshed_transactions` and put its signing
   secret (`whsec_...`) in `STRIPE_WEBHOOK_SECRET`. Not required for the basic
   pull-on-demand flow.

Only the `transactions` permission is requested (least privilege) — no
balances, ownership/PII, or payment-method data.

---

## Environment variables

Copy `.env.example` to `.env` and fill in:

| Var | Required | Notes |
| --- | -------- | ----- |
| `PORT` | no (default 8080) | HTTP port |
| `NODE_ENV` | no | `development` / `production` |
| `CORS_ORIGINS` | no | Comma-separated allowed browser origins |
| `SESSION_SECRET` | **yes** | Signs our session JWTs. `openssl rand -base64 48` |
| `APPLE_CLIENT_ID` | **yes** | Your app bundle id / Services ID (the token `aud`) |
| `STRIPE_SECRET_KEY` | **yes** | Stripe **secret** key (`sk_test_` / `sk_live_`) |
| `STRIPE_WEBHOOK_SECRET` | no | `whsec_...`, only for webhook-based sync |
| `DATABASE_PATH` | no | SQLite file path (default `./data/app.sqlite`) |

```bash
openssl rand -base64 48   # SESSION_SECRET
```

---

## Running locally

```bash
cd server
cp .env.example .env      # then fill in the values above
npm install
npm run dev               # tsx watch — restarts on change
```

`GET http://localhost:8080/health` should return `{ "status": "ok" }`.

### Build & run production

```bash
npm run build
npm start
```

### Docker

```bash
docker build -t linking-backend .
docker run --rm -p 8080:8080 \
  --env-file .env \
  -v "$PWD/data:/app/data" \
  linking-backend
```

---

## Security / trust model

- **One secret, server-only.** The Stripe secret key is the sole provider
  credential and lives only in this server's env. The app holds only a 30-day
  session JWT.
- **No per-user secrets at rest.** The database stores just an Apple-user →
  Stripe-customer id mapping and linked account ids — all useless without the
  secret key. There is no token-encryption layer because there are no tokens to
  encrypt.
- **Credentials never touch us.** Bank authentication happens entirely inside
  Stripe's `FinancialConnectionsSheet`. Neither the app nor this server sees
  usernames, passwords, or MFA codes.
- **Least privilege.** FC Sessions request only the `transactions` permission.
- **No transaction storage.** There is no transactions table; transaction data
  is never written to disk server-side.
- **Never logged.** The secret key, session `client_secret`s, `SESSION_SECRET`,
  and full transaction payloads are never logged. `src/logger.ts` additionally
  redacts known-sensitive keys as a safety net.
- **Hardening.** `helmet` security headers, `express-rate-limit` (global +
  stricter on `/auth`), CORS locked to `CORS_ORIGINS`, JSON body size capped,
  zod input validation, generic error responses (no stack traces / internals).
- **Ownership checks.** `/unlink` verifies the account belongs to the
  requesting user against our own records before calling Stripe.
- **Apple verification.** Identity tokens are verified against Apple's JWKS
  (signature, `iss`, `aud`, `exp`); only the immutable `sub` is trusted as the
  user id.

### If a secret is compromised

- **`STRIPE_SECRET_KEY` leaked:** roll it in the Stripe Dashboard immediately;
  the old key stops working at once. No stored user data is exposed by the DB
  alone.
- **`SESSION_SECRET` leaked:** rotate it; all issued session JWTs are
  invalidated and users must re-authenticate.

---

## Notes

- Node 20+ required.
- `better-sqlite3` compiles a native addon on install (the Dockerfile installs
  the needed build tools).
- The official `stripe` SDK is used for all Financial Connections calls.
