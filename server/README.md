# Teller Backend

Security-first Node.js + TypeScript backend for a [Teller](https://teller.io) integration.

This service is the **only** place secrets live:

- the Teller **mTLS client certificate + private key**, and
- per-user Teller **access tokens**, encrypted at rest (AES-256-GCM).

The iOS app never holds any of these. It authenticates with Sign in with Apple,
receives a short-lived session JWT from this server, and asks this server for
account and transaction data. Transactions are **never persisted** server-side —
they are fetched live from Teller, normalized, and returned to the app for
on-device storage only.

---

## Architecture

```
iOS app ──(Apple identity token)──▶ POST /auth/apple ──▶ { sessionToken }
iOS app ──(Bearer sessionToken)───▶ /link /accounts /transactions /unlink
                                          │
                                          ├─ decrypt token (AES-256-GCM, MASTER_KEY)
                                          └─ call Teller over mTLS (client cert + key)
```

### File tree

```
server/
├── package.json          # scripts: dev / build / start / typecheck
├── tsconfig.json
├── Dockerfile            # multi-stage, non-root runtime
├── .dockerignore
├── .gitignore            # ignores .env, *.pem, *.sqlite, node_modules, ...
├── .env.example          # every env var, documented
├── README.md
└── src/
    ├── index.ts          # express app: helmet, cors, rate-limit, routes
    ├── config.ts         # loads + validates all env (fails fast)
    ├── logger.ts         # structured logging with secret redaction
    ├── crypto.ts         # AES-256-GCM encrypt/decrypt helpers
    ├── db.ts             # better-sqlite3: users + links (no transactions table)
    ├── apple.ts          # Sign in with Apple identity-token verification
    ├── teller.ts         # mTLS Teller client + transaction normalization
    ├── middleware/
    │   └── auth.ts       # Bearer session JWT verify + issue
    └── routes/
        ├── auth.ts       # POST /auth/apple
        ├── links.ts      # POST /link, GET /accounts, POST /unlink
        └── transactions.ts # GET /transactions?since=YYYY-MM-DD
```

---

## Endpoints

| Method | Path | Auth | Body / Query | Returns |
| ------ | ---- | ---- | ------------ | ------- |
| GET | `/health` | none | — | `{ status: "ok" }` |
| POST | `/auth/apple` | none | `{ identityToken }` | `{ sessionToken }` |
| POST | `/link` | Bearer | `{ accessToken, enrollmentId?, institution? }` | `{ linkId, accounts: [...] }` |
| GET | `/accounts` | Bearer | — | `{ accounts: [...] }` |
| GET | `/transactions` | Bearer | `?since=YYYY-MM-DD` | `{ transactions: [...] }` |
| POST | `/unlink` | Bearer | `{ linkId }` | `{ ok: true }` |

All authenticated routes require `Authorization: Bearer <sessionToken>`.

Normalized transaction shape:

```json
{
  "id": "txn_...",
  "accountId": "acc_...",
  "accountName": "Platinum Card",
  "date": "2026-08-01",
  "description": "COFFEE SHOP",
  "amount": 4.75,
  "category": "dining"
}
```

**Sign convention:** POSITIVE = purchase/spend, NEGATIVE = credit/refund.
Teller returns `amount` as a string that is typically negative for credit-card
purchases; we negate it. This is isolated to a single line in
`src/teller.ts` (`normalizeTransaction`) and **must be verified against real
Teller sandbox data** — flip that line if the polarity is reversed.

---

## Getting the Teller certificate

1. In the [Teller dashboard](https://teller.io), download your **`teller.zip`**.
2. Unzip it — you get `certificate.pem` and `private_key.pem`.
3. Place them somewhere this server can read (e.g. `server/certs/`, which is
   gitignored), and point the env vars at them:

   ```
   TELLER_CERT_PATH=./certs/certificate.pem
   TELLER_KEY_PATH=./certs/private_key.pem
   ```

   Alternatively, supply the PEM contents directly via `TELLER_CERT_PEM` /
   `TELLER_KEY_PEM` (useful for secret managers / container platforms).

Every Teller API call presents this cert on the TLS layer (mTLS). An access
token alone is useless without it — that is the entire point.

---

## Environment variables

Copy `.env.example` to `.env` and fill in:

| Var | Required | Notes |
| --- | -------- | ----- |
| `PORT` | no (default 8080) | HTTP port |
| `NODE_ENV` | no | `development` / `production` |
| `CORS_ORIGINS` | no | Comma-separated allowed browser origins |
| `SESSION_SECRET` | **yes** | Signs our session JWTs. `openssl rand -base64 48` |
| `MASTER_KEY` | **yes** | 32 bytes base64 for AES-256-GCM. `openssl rand -base64 32` |
| `APPLE_CLIENT_ID` | **yes** | Your app bundle id / Services ID (the token `aud`) |
| `TELLER_CERT_PATH` + `TELLER_KEY_PATH` | one pair | File paths to the PEMs |
| `TELLER_CERT_PEM` + `TELLER_KEY_PEM` | one pair | OR inline PEM contents |
| `TELLER_API_BASE` | no | Defaults to `https://api.teller.io` |
| `DATABASE_PATH` | no | SQLite file path (default `./data/app.sqlite`) |

### Generate the secrets

```bash
openssl rand -base64 32   # MASTER_KEY  (must decode to exactly 32 bytes)
openssl rand -base64 48   # SESSION_SECRET
```

`APPLE_CLIENT_ID` is the audience your Sign in with Apple identity tokens are
issued for — your native app's bundle id, or the Services ID for web flows —
found in your Apple Developer account.

---

## Running locally

```bash
cd server
cp .env.example .env      # then fill in the values above
npm install
npm run dev               # tsx watch — restarts on change
```

`GET http://localhost:8080/health` should return `{ "status": "ok" }`.

The Teller-backed endpoints will error without a valid cert + real access
tokens, but the server boots and `/health` works with only the required
secrets set.

### Build & run production

```bash
npm run build
npm start
```

### Docker

```bash
docker build -t teller-backend .
docker run --rm -p 8080:8080 \
  --env-file .env \
  -v "$PWD/certs:/app/certs:ro" \
  -v "$PWD/data:/app/data" \
  teller-backend
```

---

## Security / trust model

- **Secrets live only here.** The mTLS cert/key and per-user access tokens
  never leave this server. The iOS app holds only a 30-day session JWT.
- **Tokens encrypted at rest.** Access tokens are stored as AES-256-GCM
  ciphertext + IV + auth tag, keyed by `MASTER_KEY`. A DB dump alone does not
  expose usable tokens. Plaintext tokens exist only transiently in memory
  during a request.
- **mTLS everywhere.** All Teller calls present the client certificate via a
  shared `https.Agent`. A stolen access token is useless without the cert.
- **No transaction storage.** There is no transactions table; transaction data
  is never written to disk server-side.
- **Never logged.** Tokens, cert/key, `MASTER_KEY`, `SESSION_SECRET`, and full
  transaction payloads are never logged. `src/logger.ts` additionally redacts
  known-sensitive keys as a safety net.
- **Hardening.** `helmet` security headers, `express-rate-limit` (global +
  stricter on `/auth`), CORS locked to `CORS_ORIGINS`, JSON body size capped,
  zod input validation, and generic error responses (no stack traces / internals).
- **Apple verification.** Identity tokens are verified against Apple's JWKS
  (signature, `iss`, `aud`, `exp`); only the immutable `sub` is trusted as the
  user id.

### If a secret is compromised

- **Teller cert/key leaked:** revoke/rotate the certificate in the Teller
  dashboard immediately and redeploy with the new PEMs. All old tokens become
  unusable without the old cert.
- **`MASTER_KEY` leaked:** rotate it, and re-link affected users (existing
  ciphertext can no longer be decrypted with a new key). Treat all stored
  tokens as compromised.
- **`SESSION_SECRET` leaked:** rotate it; all issued session JWTs are
  invalidated and users must re-authenticate.

---

## Notes

- Node 20+ required (uses global `fetch`/undici and `crypto.randomUUID`).
- `better-sqlite3` compiles a native addon on install (the Dockerfile installs
  the needed build tools).
