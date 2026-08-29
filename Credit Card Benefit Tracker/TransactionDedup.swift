//
//  TransactionDedup.swift
//  Credit Card Benefit Tracker
//
//  Shared duplicate detection used by BOTH linked-account import (LinkSyncService)
//  and manual statement upload (StatementUploadSheet), so the same transaction
//  imported from two sources isn't double-counted.
//
//  Cross-source matching can't rely on exact description text: the same purchase
//  reads differently from Stripe ("TST* JOE'S COFFEE") than from an Amex PDF
//  ("TST* JOE'S COFFEE SEATTLE WA"), and the date can differ by a day or two.
//  So a match requires: the SAME amount, a date within a few days, and one
//  normalized merchant string containing the other.
//

import Foundation

enum TransactionDedup {
    /// Max day gap for two records to be considered the same transaction.
    private static let dayTolerance: TimeInterval = 3 * 24 * 60 * 60

    /// Merchant text reduced to lowercase letter-words (drops digits, store
    /// numbers, and punctuation) so source-specific suffixes don't block a match.
    static func normalizedMerchant(_ s: String) -> String {
        let mapped = s.lowercased().map { ($0.isLetter || $0 == " ") ? $0 : " " }
        return String(mapped).split(separator: " ").joined(separator: " ")
    }

    /// Whether two transactions are very likely the same real-world charge.
    static func isSameTransaction(
        dateA: Date, descA: String, amountA: Double,
        dateB: Date, descB: String, amountB: Double
    ) -> Bool {
        isSameTransaction(
            dateA: dateA, normA: normalizedMerchant(descA), amountA: amountA,
            dateB: dateB, normB: normalizedMerchant(descB), amountB: amountB
        )
    }

    /// Same as above but taking pre-normalized merchant strings, so callers that
    /// compare many rows can normalize once instead of on every comparison.
    static func isSameTransaction(
        dateA: Date, normA: String, amountA: Double,
        dateB: Date, normB: String, amountB: Double
    ) -> Bool {
        guard abs(amountA - amountB) < 0.005 else { return false }
        guard abs(dateA.timeIntervalSince(dateB)) <= dayTolerance else { return false }
        if normA.isEmpty || normB.isEmpty { return normA == normB }
        return normA == normB || normA.contains(normB) || normB.contains(normA)
    }

    /// True if `candidate` matches any row in `existing`.
    static func isDuplicate(
        date: Date, description: String, amount: Double,
        against existing: [StatementRow]
    ) -> Bool {
        existing.contains { row in
            isSameTransaction(
                dateA: date, descA: description, amountA: amount,
                dateB: row.transactionDate, descB: row.transactionDescription, amountB: row.amount
            )
        }
    }
}
