//
//  PointsValuer.swift
//  Credit Card Benefit Tracker
//
//  Shared helper for converting a card's uploaded statement spend into an
//  estimated dollar value of points earned. Used by the card-detail fee
//  tracker and the Portfolio overview so both agree on the number.
//

import Foundation

enum PointsValuer {

    /// Estimated dollar value of points earned from a card's statement
    /// transactions on/after `since`, using the card's rewards program
    /// cents-per-point and its category earning multipliers.
    static func dollarValue(for card: UserCard, since: Date) -> Double {
        let cpp = CardRecommendationEngine.programs[card.catalogCardID]?.cpp ?? 1.0
        let catalog = CreditCardCatalog.all.first { $0.id == card.catalogCardID }
        let highlights = catalog.map { CreditCardCatalog.earningHighlights(for: $0) } ?? []

        // Net spend per merchant. A refund/reversal (negative) nets against that
        // merchant's purchases, so points earned on a reversed charge are removed
        // (e.g. fraudulent Vinted charges that were all reversed → net 0 → no
        // points). A benefit STATEMENT CREDIT is a separate "merchant" whose net
        // is negative on its own; we clamp per-merchant net at 0, so it never
        // subtracts points from your real purchases (the $150 dining credit does
        // NOT erase the points from the $250 dinner).
        struct Bucket { var net: Double = 0; var category: String = "Other" }
        var buckets: [String: Bucket] = [:]
        for statement in card.statements {
            for row in statement.rows where row.transactionDate >= since {
                let key = normalizedMerchant(row.transactionDescription)
                var b = buckets[key] ?? Bucket()
                b.net += row.amount
                if row.amount > 0 { b.category = row.category }  // category from an actual charge
                buckets[key] = b
            }
        }

        var totalPoints = 0.0
        for (_, b) in buckets {
            guard b.net > 0 else { continue }   // fully refunded or standalone credit → no points
            totalPoints += b.net * multiplier(forCategory: b.category, highlights: highlights)
        }
        return totalPoints * cpp / 100.0
    }

    /// Earning multiplier for a category given the card's earning highlights.
    private static func multiplier(forCategory category: String, highlights: [String]) -> Double {
        let cat = category.lowercased()
        var multiplier = 1.0
        for highlight in highlights {
            let h = highlight.lowercased()
            let matches: Bool
            switch cat {
            case let c where c.contains("restaurant") || c.contains("dining"):
                matches = h.contains("restaurant") || h.contains("dining")
            case let c where c.contains("supermarket") || c.contains("grocery"):
                matches = h.contains("supermarket") || h.contains("grocery")
            case let c where c.contains("flight") || c.contains("airline"):
                matches = h.contains("flight") || h.contains("airline")
            case let c where c.contains("hotel") || c.contains("resort"):
                matches = h.contains("hotel") || h.contains("resort")
            case let c where c.contains("gas") || c.contains("fuel"):
                matches = h.contains("gas station") || h.contains("fuel")
            case let c where c.contains("transit") || c.contains("rideshare"):
                matches = h.contains("transit") || h.contains("rideshare")
            case let c where c.contains("streaming"):
                matches = h.contains("streaming")
            case let c where c.contains("drugstore") || c.contains("pharmacy"):
                matches = h.contains("drugstore") || h.contains("pharmacy")
            default:
                matches = false
            }
            if matches, let m = extractMultiplier(from: highlight), m > multiplier {
                multiplier = m
            }
        }
        return multiplier
    }

    /// Normalize a merchant so a purchase and its refund/reversal bucket together
    /// (strips store/reference numbers, refund words, and punctuation).
    private static func normalizedMerchant(_ description: String) -> String {
        var t = description.lowercased()
        t = t.replacingOccurrences(of: "#\\s*\\d+", with: " ", options: .regularExpression)
        t = t.replacingOccurrences(of: "\\b\\d{3,}\\b", with: " ", options: .regularExpression)
        t = t.replacingOccurrences(of: "\\b(refund|reversal|reversed|return|returned|credit|adjustment)\\b", with: " ", options: .regularExpression)
        t = t.replacingOccurrences(of: "[*#.,/\\-]", with: " ", options: .regularExpression)
        t = t.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return t.trimmingCharacters(in: .whitespaces)
    }

    /// Convenience: points value over the last 12 months.
    static func dollarValueLast12Months(for card: UserCard) -> Double {
        let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
        return dollarValue(for: card, since: oneYearAgo)
    }

    /// Pulls a multiplier out of an earning-highlight string, e.g. "4x" or "6%".
    static func extractMultiplier(from highlight: String) -> Double? {
        let lower = highlight.lowercased()
        if let range = lower.range(of: #"(\d+(?:\.\d+)?)x"#, options: .regularExpression) {
            return Double(String(lower[range]).replacingOccurrences(of: "x", with: ""))
        }
        if let range = lower.range(of: #"(\d+(?:\.\d+)?)%"#, options: .regularExpression) {
            return Double(String(lower[range]).replacingOccurrences(of: "%", with: ""))
        }
        return nil
    }
}
