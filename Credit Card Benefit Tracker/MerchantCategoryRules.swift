//
//  MerchantCategoryRules.swift
//  Credit Card Benefit Tracker
//
//  Code-owned overrides for how specific merchants are categorized PER ISSUER,
//  because each issuer codes the same merchant differently for earning purposes
//  (e.g. Chase counts DoorDash as Dining → 3x on the Sapphire Reserve).
//
//  ▸ These are developer-maintained rules — NOT user-editable.
//  ▸ To add a rule: put a lowercased merchant keyword and the category it should
//    map to under the issuer. Keyword match is case-insensitive "contains".
//  ▸ Category strings must match the app's category vocabulary so the points
//    multiplier picks them up: "Restaurants", "Supermarkets", "Flights",
//    "Hotels", "Gas Stations", "Streaming", "Transit", "Drugstores", "Other".
//
//  Issuer keys are matched case-insensitively and also accept common aliases
//  (e.g. "amex" == "american express").
//

import Foundation

enum MerchantCategoryRules {

    /// Rules that apply to EVERY issuer (a merchant that's always the same
    /// category regardless of card). Checked before issuer-specific rules.
    static let globalRules: [(keyword: String, category: String)] = [
        ("resy", "Restaurants"),          // Resy = restaurant reservations/dining
        ("tst*", "Restaurants"),          // Toast ("TST* <restaurant>") = dining
        ("frys", "Supermarkets"),         // Fry's Food (Kroger grocery)
        ("fry's", "Supermarkets"),
    ]

    /// issuer key -> ordered list of (merchant keyword, category). First match wins.
    static let rules: [String: [(keyword: String, category: String)]] = [
        "chase": [
            ("doordash", "Restaurants"),      // Chase codes DoorDash as dining (3x on CSR/CSP)
            ("dd doordash", "Restaurants"),
            ("caviar", "Restaurants"),        // DoorDash-owned, dining
        ],
        // Add other issuers here as their coding quirks are discovered, e.g.:
        // "american express": [ ("...", "...") ],
        // "capital one":      [ ("...", "...") ],
        // "citi":             [ ("...", "...") ],
        // "discover":         [ ("...", "...") ],
    ]

    /// Maps an issuer string (any casing / common alias) to a canonical rules key.
    private static func canonicalIssuer(_ issuer: String) -> String {
        let lower = issuer.lowercased()
        if lower.contains("amex") || lower.contains("american express") { return "american express" }
        if lower.contains("capital one") || lower.contains("capitalone") { return "capital one" }
        if lower.contains("chase") { return "chase" }
        if lower.contains("citi") { return "citi" }
        if lower.contains("discover") { return "discover" }
        return lower
    }

    /// Returns the overridden category for a merchant on the given issuer, if any.
    static func category(forMerchant merchant: String, issuer: String) -> String? {
        let m = merchant.lowercased()
        // Global rules first (apply to every issuer).
        for rule in globalRules where m.contains(rule.keyword) {
            return rule.category
        }
        // Then issuer-specific rules.
        let key = canonicalIssuer(issuer)
        if let issuerRules = rules[key] {
            for rule in issuerRules where m.contains(rule.keyword) {
                return rule.category
            }
        }
        return nil
    }
}
