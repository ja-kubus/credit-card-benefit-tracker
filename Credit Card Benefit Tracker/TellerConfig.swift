//
//  TellerConfig.swift
//  Credit Card Benefit Tracker
//
//  Public, non-secret configuration for the Teller account-linking flow.
//  NONE of these values are secrets. The app never holds a Teller API key or
//  any bank credentials — those live only on the backend and inside Teller
//  Connect (the bank's own login page). Safe to ship in the app binary.
//

import Foundation

struct TellerConfig {
    /// The Teller Connect application id. This is PUBLIC (it is embedded in the
    /// Teller Connect widget in the browser). Paste your Teller `application_id`
    /// here from the Teller dashboard (https://teller.io/settings/application).
    static let applicationId = "REPLACE_WITH_TELLER_APP_ID"

    /// Teller Connect environment: "sandbox", "development", or "production".
    /// Defaults to sandbox for safe testing.
    static let environment = "sandbox"

    /// Base URL of YOUR backend, which holds the Teller access tokens and does
    /// all the sensitive work. Replace with your deployed backend's URL.
    static let backendBaseURL = URL(string: "https://your-backend.example.com")!
}
