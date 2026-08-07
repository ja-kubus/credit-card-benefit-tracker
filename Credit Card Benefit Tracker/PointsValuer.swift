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

        // Sum every transaction at its category's multiplier. Negative rows
        // (refunds, reversals, statement credits) subtract points at the same
        // multiplier, so they net against spend the way the issuer does:
        //   • Reversed fraud charges (e.g. Vinted +/-) → net to 0 points.
        //   • A $182.72 travel credit on a 4x flight → removes ~731 pts, leaving
        //     points on the net (~533), matching the statement.
        // Total is clamped at 0 so credits can never drive points negative.
        var totalPoints = 0.0
        for statement in card.statements {
            for row in statement.rows where row.transactionDate >= since {
                totalPoints += row.amount * multiplier(forCategory: row.category, highlights: highlights)
            }
        }
        return max(0, totalPoints) * cpp / 100.0
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
