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

        var totalPoints = 0.0
        for statement in card.statements {
            for row in statement.rows where row.transactionDate >= since {
                let cat = row.category.lowercased()
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
                totalPoints += row.amount * multiplier
            }
        }
        return totalPoints * cpp / 100.0
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
