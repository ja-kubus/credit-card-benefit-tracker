# Deploying to Google Cloud Run

This backend is stateless (no database, no volume), so Cloud Run's scale-to-zero
model fits perfectly: an idle app costs essentially nothing and there is no
machine to manage. It deploys the existing `Dockerfile` with **no code changes**.

The Stripe secret key and session secret are stored in **Google Secret Manager**
and injected at runtime — never baked into the image, never in an env file on a
server.

---

## One-time setup

### 1. Install the gcloud CLI and sign in

```bash
brew install --cask google-cloud-sdk
gcloud auth login
```

### 2. Create (or pick) a project and set it

```bash
gcloud projects create ccbt-backend-123 --name="CCBT Backend"   # or use an existing one
gcloud config set project ccbt-backend-123
```

> A billing account must be linked to the project (Cloud Run's free tier still
> requires billing enabled). Link it in the Cloud Console → Billing.

### 3. Enable the APIs

```bash
gcloud services enable \
  run.googleapis.com \
  cloudbuild.googleapis.com \
  artifactregistry.googleapis.com \
  secretmanager.googleapis.com
```

### 4. Store the secrets in Secret Manager

```bash
# Your Stripe SECRET key (sk_live_... in production, sk_test_... to try it out):
printf '%s' 'sk_live_your_key_here' | gcloud secrets create STRIPE_SECRET_KEY --data-file=-

# A random signing secret for our own session JWTs:
openssl rand -base64 48 | tr -d '\n' | gcloud secrets create SESSION_SECRET --data-file=-
```

(To rotate later: `gcloud secrets versions add STRIPE_SECRET_KEY --data-file=-`.)

---

## Deploy

From the `server/` directory:

```bash
gcloud run deploy linking-backend \
  --source . \
  --region us-central1 \
  --allow-unauthenticated \
  --memory 256Mi \
  --min-instances 0 \
  --set-env-vars APPLE_CLIENT_ID=com.yourcompany.CreditCardBenefitTracker \
  --set-secrets STRIPE_SECRET_KEY=STRIPE_SECRET_KEY:latest,SESSION_SECRET=SESSION_SECRET:latest
```

Notes:
- `--source .` uses Cloud Build to build the `Dockerfile` for you — **no local
  Docker required**.
- `--allow-unauthenticated` is correct here: the app is public-facing and does
  its OWN auth (Sign in with Apple → our session JWT). Google IAM is not the
  gatekeeper; our `requireAuth` middleware is.
- `--min-instances 0` = scale to zero when idle (free-tier friendly). First
  request after idle has a ~1s cold start.
- **Do NOT set `PORT`** — Cloud Run injects it automatically and the app already
  reads it (`config.port`).
- The first deploy may prompt to grant the Cloud Run service account access to
  the secrets. Answer yes, or grant explicitly:

  ```bash
  PROJECT_NUMBER=$(gcloud projects describe "$(gcloud config get-value project)" --format='value(projectNumber)')
  SA="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"
  for S in STRIPE_SECRET_KEY SESSION_SECRET; do
    gcloud secrets add-iam-policy-binding "$S" \
      --member="serviceAccount:${SA}" \
      --role="roles/secretmanager.secretAccessor"
  done
  ```

On success, gcloud prints a **Service URL** like
`https://linking-backend-xxxxxxxx-uc.a.run.app`.

---

## Verify

```bash
curl https://YOUR-SERVICE-URL/health     # -> {"status":"ok"}
```

Then put that URL in the app — `Credit Card Benefit Tracker/StripeLinkConfig.swift`:

```swift
static let backendBaseURL = URL(string: "https://YOUR-SERVICE-URL")!
```

---

## Troubleshooting

### `gcloud crashed (ValueError): ZIP does not support timestamps before 1980`

This is a bug in gcloud's **bundled Python 3.14** (used by SDK ~579), not your
files: when `--source` zips the upload, gcloud stamps a synthetic entry with
epoch 0 (1970), and Python 3.14's `zipfile` rejects any timestamp before 1980
(older Pythons tolerated it). It is unrelated to your actual file timestamps.

Fix: run gcloud under an older Python (3.11 or 3.12). Install one if needed
(`brew install python@3.11`), then point gcloud at it for the deploy:

```bash
export CLOUDSDK_PYTHON="$(command -v python3.11)"
gcloud run deploy linking-backend --source . --region us-central1 ...   # same command as above
```

The `export` lasts for the current terminal session. To make it permanent, add
that line to `~/.zshrc`. Verify which interpreter gcloud uses with:

```bash
gcloud info | grep -i "python version"
```

## Redeploying

Just run the same `gcloud run deploy … --source .` command again. To change a
secret, add a new version (`gcloud secrets versions add …`) and redeploy (the
`:latest` reference picks it up).

## Cost

Cloud Run's perpetual free tier (per month, per billing account) covers roughly
2M requests, 360k GB-seconds of memory, and 180k vCPU-seconds — far beyond a
small app's usage. With `--min-instances 0`, you pay only while requests are
actually being served.
