# Go-Live Checklist

Everything you need to move account-linking from **test mode** to **production**,
plus the cost model so there are no surprises.

---

## 1. Stripe: register and go live

1. **Complete Financial Connections registration.**
   [Dashboard → Settings → Financial Connections](https://dashboard.stripe.com/settings/financial-connections).
   Live mode requires this; test mode works without it.
2. **Get your live keys** from [Dashboard → API keys](https://dashboard.stripe.com/apikeys)
   (toggle to **live** mode): the secret `sk_live_…` and publishable `pk_live_…`.

## 2. Swap keys

**Backend secret key** (new secret version, then redeploy):

```bash
printf '%s' 'sk_live_your_key' | gcloud secrets versions add STRIPE_SECRET_KEY --data-file=-

cd server
export CLOUDSDK_PYTHON="$(command -v python3.11)"
gcloud run deploy linking-backend --source . --project card-concierge-505022 \
  --region us-central1 --allow-unauthenticated --memory 256Mi --min-instances 0 \
  --set-env-vars APPLE_CLIENT_ID=social.Credit-Card-Benefit-Tracker \
  --set-secrets STRIPE_SECRET_KEY=STRIPE_SECRET_KEY:latest,SESSION_SECRET=SESSION_SECRET:latest
```

**App publishable key** — in `Credit Card Benefit Tracker/StripeLinkConfig.swift`:

```swift
static let publishableKey = "pk_live_your_key"
```

## 3. Cost model (know this before real users connect)

- **Stripe Financial Connections – Transactions** is a **paid, recurring
  feature**. Because we *subscribe* each linked account to daily transaction
  refreshes, each connected account bills on a **per-account, per-month** basis
  (roughly **~$0.30/account/month** — confirm current pricing on your
  [Stripe pricing page](https://stripe.com/pricing) / dashboard). The initial
  account connection may also carry a one-time fee depending on your plan.
  - To reduce cost, you could **unsubscribe** accounts and use on-demand
    refreshes instead of daily (a code change in `subscribeAccount` →
    `accounts.refresh`). Trade-off: data is only as fresh as the last manual
    "Sync now".
- **Google Cloud Run** — with `--min-instances 0` you pay only while serving
  requests; a small app stays within the perpetual free tier (~2M requests/mo).
  Billing must still be enabled on the project.
- **Apple Developer Program** — $99/year (already required for Sign in with
  Apple).

## 4. Subscriptions (App Store Connect)

The app ships two auto-renewable subscriptions (StoreKit 2). Locally they run
against `Credit Card Benefit Tracker/Products.storekit` (select it in the
scheme: Edit Scheme → Run → Options → StoreKit Configuration). For production,
create the real products so the IDs match what the code expects:

| Tier | Product ID | Price |
| ---- | ---------- | ----- |
| Concierge Premium | `social.creditcardbenefittracker.premium.monthly` | $2.99/mo |
| Concierge Max | `social.creditcardbenefittracker.max.monthly` | $5.99/mo |

Steps:
1. [App Store Connect](https://appstoreconnect.apple.com) → your app →
   **Monetization → Subscriptions**.
2. Create a **Subscription Group** (e.g. "Concierge"). Both products go in the
   same group so upgrades/downgrades pro-rate correctly.
3. Add the two subscriptions with the **exact Product IDs above** (they must
   match `SubscriptionProduct` in `SubscriptionManager.swift`), each with a
   monthly duration and the price above; fill in display name, description, and
   a review screenshot.
4. **Enroll in the Apple Small Business Program** (if eligible, <$1M/yr) to pay
   15% instead of 30% — directly doubles your per-sub margin.
5. Submit the subscriptions for review (they review alongside the app build).

Notes:
- The **7-day trial is app-managed** (grants Premium features capped at 2 cards),
  NOT a StoreKit introductory offer — so you do **not** configure a free trial
  on these products. Leave introductory offers empty.
- There is no Ad-Free product (that tier was removed) and no ads, so there's no
  AdMob SDK, App Tracking Transparency prompt, or ad-related privacy disclosure
  to deal with.

## 5. App Store prerequisites

- [ ] **Privacy policy hosted at a public URL** (adapt `PRIVACY.md`), linked in
      App Store Connect and in-app.
- [ ] **App Privacy "nutrition labels"** in App Store Connect declare: Financial
      Info (transactions) and Identifiers (Sign in with Apple). Mark whether data
      is linked to the user and that it isn't used for tracking.
- [ ] **Sign in with Apple** works on a real device with your **paid** team, and
      the **Release** build ships the entitlement (both entitlements files now
      include `com.apple.developer.applesignin`).
- [ ] **Bundle id `social.Credit-Card-Benefit-Tracker`** matches `APPLE_CLIENT_ID`
      on the backend (currently correct).
- [ ] Confirm the transaction **sign** is correct on real data (purchases =
      positive spend); flip one line in `server/src/stripe.ts` if not.

## 6. Monitoring & ops

- **Backend logs:**
  ```bash
  gcloud run services logs read linking-backend --project card-concierge-505022 --region us-central1 --limit 50
  ```
- **Stripe Dashboard** → Financial Connections for connected-account counts and
  errors; **Developers → Logs** for API calls.
- **Rotate secrets** per `server/SECURITY.md` if anything leaks.

## 7. Deploy gotcha (already documented)

`gcloud run deploy --source` under gcloud's bundled Python 3.14 crashes with
"ZIP does not support timestamps before 1980". Prefix deploys with
`export CLOUDSDK_PYTHON="$(command -v python3.11)"`. See `server/DEPLOY.md`.

---

### Quick status of what's already done

- ✅ Backend deployed (Cloud Run), stateless, secrets in Secret Manager
- ✅ Sign in with Apple working; entitlement in both build configs
- ✅ Stripe SDK integrated; link → assign card → import → spend/points
- ✅ Disconnect + delete-all cleanup; reconnect inherits card mapping
- ✅ SECURITY.md, PRIVACY.md (draft), DEPLOY.md
- ⏳ This checklist: FC registration, live keys, App Store submission
