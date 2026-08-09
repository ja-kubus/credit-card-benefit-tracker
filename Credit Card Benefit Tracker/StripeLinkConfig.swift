//
//  StripeLinkConfig.swift
//  Credit Card Benefit Tracker
//
//  Public, non-secret configuration for the Stripe Financial Connections
//  account-linking flow. NONE of these values are secrets. The app never holds
//  the Stripe SECRET key or any bank credentials — the secret key lives only on
//  the backend, and bank credentials are entered only inside Stripe's own
//  Financial Connections sheet. Safe to ship in the app binary.
//

import Foundation

enum StripeLinkConfig {
    /// Base URL of YOUR backend, which holds the Stripe secret key and does all
    /// the sensitive work. Replace with your deployed backend's URL.
    static let backendBaseURL = URL(string: "https://your-backend.example.com")!

    /// Your Stripe PUBLISHABLE key (starts with `pk_test_` / `pk_live_`).
    /// Publishable keys are NOT secret — they are meant to ship in clients.
    /// The Financial Connections sheet is authorized by the per-session
    /// client_secret from the backend; this is set on STPAPIClient only because
    /// some SDK paths expect a configured publishable key. Leave empty if unused.
    static let publishableKey = ""

    /// Custom URL scheme the Stripe sheet returns to after a bank's app-to-app
    /// or OAuth flow (e.g. "ccbt://stripe-redirect"). Register the scheme in
    /// Info.plist (URL Types) if you set this. Leave nil to omit.
    static let returnURL: String? = nil
}
