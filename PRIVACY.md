# Privacy Policy (DRAFT)

> **This is a draft for you to review and adapt with a lawyer before publishing.**
> The App Store requires a publicly hosted privacy policy URL for apps that
> access financial data. Fill in the bracketed placeholders and host the final
> version somewhere public (e.g. a GitHub Pages site), then link it in App Store
> Connect and in the app.

**App:** Credit Card Benefit Tracker
**Effective date:** [DATE]
**Contact:** [YOUR EMAIL]

## Summary

- We help you track credit-card benefits and spending.
- If you choose to link an account, your bank login happens **only inside
  Stripe's secure screen** — we never see or store your banking credentials.
- Your transaction data is stored **on your device**. Our server does **not**
  store your transactions.
- We don't sell your data.
- You can delete your data at any time from within the app.

## Information we collect

**If you use manual statement upload:** the statements you import are processed
and stored **on your device only**. They are not sent to our servers.

**If you choose to link an account (optional):**

- **Sign in with Apple identifier.** When you sign in, Apple gives us a stable,
  anonymous user identifier (a "sub"). We do **not** collect your name or email
  through this flow. This identifier is used only to associate you with your
  linked-account connection.
- **Account linking via Stripe.** We use [Stripe Financial
  Connections](https://stripe.com/financial-connections) to connect your
  financial account. You enter your bank credentials **directly into Stripe's
  interface** — the app and our server never receive them. Stripe provides us
  access to your **transactions** (amount, description, date) and basic account
  metadata (institution name, last 4 digits, account type).
- **Transaction data.** Transactions retrieved via Stripe are returned to the
  app and stored **on your device**. Our server does not retain them.

**What we do NOT collect:** your bank username/password, full account numbers,
your name/email (beyond what you may enter locally), precise location, contacts,
or advertising identifiers.

## How we use information

- To display your benefits, spending, and points on your device.
- To maintain your linked-account connection (via Stripe) so transactions can be
  refreshed.
- We do **not** use your data for advertising and do **not** sell it.

## Third-party services

- **Apple – Sign in with Apple** — authentication.
  See [Apple's Privacy Policy](https://www.apple.com/legal/privacy/).
- **Stripe – Financial Connections** — securely connecting your financial
  account and providing transaction data. Stripe acts as a data processor and
  handles your banking credentials directly.
  See [Stripe's Privacy Policy](https://stripe.com/privacy).
- **Google Cloud Run** — hosts our backend, which brokers requests to Stripe.
  Our backend stores no transaction data.

## Data storage and security

- Transaction data is stored **on your device**.
- Our backend holds **no database of your data**. The only mapping it keeps
  (which Stripe customer corresponds to your app identifier) is stored within
  Stripe.
- All network communication uses encryption in transit (HTTPS).
- Access to Stripe is authenticated by a secret key held only on our server,
  never in the app.

## Data retention and deletion

- **On-device data:** removed when you delete it in the app or uninstall the app.
- **Disconnect an account:** stops syncing and removes that account's imported
  transactions from your device.
- **Delete all linked data:** from Settings → Linked Accounts → *Delete all
  linked data*. This disconnects every linked account and deletes your
  associated record on our server (via Stripe), fully forgetting you
  server-side.

## Children's privacy

The app is not directed to children under 13 (or the age required by your
jurisdiction), and we do not knowingly collect their data.

## Changes to this policy

We may update this policy; material changes will be reflected by updating the
effective date and, where appropriate, an in-app notice.

## Contact

Questions? Contact [YOUR EMAIL].
