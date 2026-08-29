//
//  MerchantLearning.swift
//  Credit Card Benefit Tracker
//
//  Learns how the USER categorizes merchants and applies it everywhere. When a
//  user recategorizes a transaction (e.g. "SQ *BLUE BOTTLE" from Other →
//  Restaurants), we remember merchant → category and:
//    • re-categorize all existing transactions from that merchant, and
//    • categorize future imports from it automatically.
//
//  This shrinks the pile of "Other" transactions over time, personalized and
//  accurate (the user told us), without the app guessing and over-counting
//  points. User learning always wins over the built-in rules.
//

import Foundation
import SwiftData

/// A user-taught merchant → category mapping (on-device, per user).
@Model
final class LearnedMerchantCategory {
    @Attribute(.unique) var merchantKey: String
    var category: String
    var updatedAt: Date

    init(merchantKey: String, category: String, updatedAt: Date = Date()) {
        self.merchantKey = merchantKey
        self.category = category
        self.updatedAt = updatedAt
    }
}

enum MerchantLearning {
    /// A stable key for a merchant: the normalized merchant name reduced to its
    /// first few significant words, so location/store suffixes ("… SEATTLE WA",
    /// "#123") don't fragment the same merchant into many keys.
    static func normalizeKey(_ description: String) -> String {
        let norm = TransactionDedup.normalizedMerchant(description) // letters, lowercased, collapsed
        let tokens = norm.split(separator: " ").prefix(3)
        return tokens.joined(separator: " ")
    }

    /// Load all learned mappings into the in-memory cache that `CategoryDetector`
    /// consults during categorization. Call on launch and after any change.
    @MainActor
    static func refreshCache(modelContext: ModelContext) {
        let entries = (try? modelContext.fetch(FetchDescriptor<LearnedMerchantCategory>())) ?? []
        var map: [String: String] = [:]
        for e in entries where !e.merchantKey.isEmpty { map[e.merchantKey] = e.category }
        CategoryDetector.learnedOverrides = map
    }

    /// Record that this merchant should map to `category`, then apply it to every
    /// existing transaction from the same merchant. Returns how many rows changed.
    @MainActor
    @discardableResult
    static func learn(description: String, category: String, modelContext: ModelContext) -> Int {
        let key = normalizeKey(description)
        guard !key.isEmpty else { return 0 }

        let entries = (try? modelContext.fetch(FetchDescriptor<LearnedMerchantCategory>())) ?? []
        if let existing = entries.first(where: { $0.merchantKey == key }) {
            existing.category = category
            existing.updatedAt = Date()
        } else {
            modelContext.insert(LearnedMerchantCategory(merchantKey: key, category: category))
        }
        CategoryDetector.learnedOverrides[key] = category

        let changed = applyToMatchingRows(key: key, category: category, modelContext: modelContext)
        try? modelContext.save()
        return changed
    }

    /// Set `category` on every StatementRow whose merchant matches `key`.
    @MainActor
    @discardableResult
    static func applyToMatchingRows(key: String, category: String, modelContext: ModelContext) -> Int {
        let rows = (try? modelContext.fetch(FetchDescriptor<StatementRow>())) ?? []
        var changed = 0
        for row in rows where row.category != category && normalizeKey(row.transactionDescription) == key {
            row.category = category
            changed += 1
        }
        return changed
    }
}
