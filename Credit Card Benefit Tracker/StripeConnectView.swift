//
//  StripeConnectView.swift
//  Credit Card Benefit Tracker
//
//  The ONLY place account linking happens. Presents Stripe's Financial
//  Connections sheet, where the user picks their bank and authenticates on the
//  bank's own page INSIDE Stripe's UI. This app never sees bank credentials and
//  never holds any Stripe secret — the sheet is authorized entirely by the
//  per-session `client_secret` fetched from the backend.
//
//  The Stripe iOS SDK is an optional dependency: everything here is guarded by
//  `#if canImport(StripeFinancialConnections)` so the app still compiles before
//  the package is added. To enable it in Xcode:
//    File ▸ Add Package Dependencies… ▸ https://github.com/stripe/stripe-ios
//    ▸ add the "StripeFinancialConnections" product to the app target.
//

import UIKit

/// Result of presenting the Stripe Financial Connections sheet.
enum StripeLinkOutcome {
    case completed          // user finished linking; proceed to /link/complete
    case canceled           // user dismissed the sheet
    case failed(String)     // an error occurred (message is safe to display)
}

@MainActor
enum StripeConnect {
    /// Present the Financial Connections sheet for the given session client
    /// secret. Returns when the user finishes, cancels, or an error occurs.
    static func present(clientSecret: String) async -> StripeLinkOutcome {
        #if canImport(StripeFinancialConnections)
        guard let presenter = topViewController() else {
            return .failed("Could not present the linking screen.")
        }
        return await StripeConnectImpl.present(clientSecret: clientSecret, from: presenter)
        #else
        return .failed(
            "Account linking needs the Stripe SDK. Add the Swift package "
            + "github.com/stripe/stripe-ios (StripeFinancialConnections) to the app target."
        )
        #endif
    }

    /// Find the top-most view controller to present from.
    static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first { $0.activationState == .foregroundActive } as? UIWindowScene
            ?? scenes.first as? UIWindowScene
        guard let root = windowScene?.windows.first(where: { $0.isKeyWindow })?.rootViewController
            ?? windowScene?.windows.first?.rootViewController else { return nil }

        var top = root
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }
}

#if canImport(StripeFinancialConnections)
import StripeFinancialConnections
import StripeCore

@MainActor
private enum StripeConnectImpl {
    static func present(clientSecret: String, from presenter: UIViewController) async -> StripeLinkOutcome {
        // Configure the publishable key if one was provided. Publishable keys
        // are non-secret. The session client_secret is what actually authorizes
        // this specific linking attempt.
        if !StripeLinkConfig.publishableKey.isEmpty {
            STPAPIClient.shared.publishableKey = StripeLinkConfig.publishableKey
        }

        let returnURL = StripeLinkConfig.returnURL
        let sheet = FinancialConnectionsSheet(
            financialConnectionsSessionClientSecret: clientSecret,
            returnURL: returnURL
        )

        return await withCheckedContinuation { continuation in
            // The sheet must be retained until its completion fires; capture it
            // in the closure so it lives for the duration of presentation.
            sheet.present(from: presenter) { result in
                switch result {
                case .completed:
                    continuation.resume(returning: .completed)
                case .canceled:
                    continuation.resume(returning: .canceled)
                case .failed(let error):
                    continuation.resume(returning: .failed(error.localizedDescription))
                }
                _ = sheet // keep a reference alive until here
            }
        }
    }
}
#endif
