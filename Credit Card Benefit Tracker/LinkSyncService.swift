//
//  LinkSyncService.swift
//  Credit Card Benefit Tracker
//
//  Pulls linked transactions from the backend and inserts them into SwiftData as
//  Statement/StatementRow, so linked data lives alongside uploaded statements and
//  is categorized identically (same CategoryDetector + MerchantCategoryRules).
//

import Foundation
import SwiftData

enum LinkSyncService {
    /// Fetch transactions and merge them into SwiftData.
    /// - Parameters:
    ///   - since: earliest transaction date to import (default: one year ago).
    ///   - modelContext: the SwiftData context to insert into.
    /// - Returns: number of new StatementRows inserted.
    @discardableResult
    @MainActor
    static func sync(since: Date? = nil, modelContext: ModelContext) async throws -> Int {
        let sinceDate = since ?? Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
        let transactions = try await LinkBackendClient.shared.transactions(since: sinceDate)
        return merge(transactions: transactions, modelContext: modelContext)
    }

    /// Insert the given remote transactions, deduping against existing rows.
    @MainActor
    static func merge(transactions: [RemoteTransaction], modelContext: ModelContext) -> Int {
        guard !transactions.isEmpty else { return 0 }

        // Skip pending transactions — they can change amount/description before
        // posting and would create dedupe churn. Import posted only.
        let posted = transactions.filter { $0.status.isEmpty || $0.status == "posted" }
        guard !posted.isEmpty else { return 0 }

        // Existing rows (for dedupe) and user cards (to attach statements by issuer).
        let existingRows = (try? modelContext.fetch(FetchDescriptor<StatementRow>())) ?? []
        let userCards = (try? modelContext.fetch(FetchDescriptor<UserCard>())) ?? []
        let existingStatements = (try? modelContext.fetch(FetchDescriptor<Statement>())) ?? []

        // Build a dedupe key set from existing rows: (date, description-lowercased, amount).
        var seen = Set<String>()
        for row in existingRows {
            seen.insert(dedupeKey(date: row.transactionDate,
                                  description: row.transactionDescription,
                                  amount: row.amount))
        }

        // Group by account.
        let grouped = Dictionary(grouping: posted, by: { $0.accountId })
        var inserted = 0

        for (accountId, txns) in grouped {
            let accountName = txns.first?.accountName ?? "Account"
            let institution = accountName
            let statementFileName = "Linked · \(accountName)"

            // Find-or-create one Statement per linked account.
            let statement: Statement
            if let existing = existingStatements.first(where: { $0.fileName == statementFileName }) {
                statement = existing
            } else {
                // Attach to a UserCard whose issuer best matches the institution, else standalone.
                let matchCard = userCards.first { card in
                    let issuer = card.issuer.lowercased()
                    let inst = institution.lowercased()
                    return !issuer.isEmpty && (inst.contains(issuer) || issuer.contains(inst))
                }
                let cardID = matchCard?.catalogCardID ?? "linked_\(accountId)"
                statement = Statement(cardID: cardID, fileName: statementFileName, issuer: institution)
                if let matchCard {
                    matchCard.statements.append(statement)
                }
                modelContext.insert(statement)
            }

            // Keep statementMonth pointed at the latest transaction month.
            if let latest = txns.map(\.date).max() {
                statement.statementMonth = latest
            }

            for txn in txns {
                let key = dedupeKey(date: txn.date, description: txn.description, amount: txn.amount)
                if seen.contains(key) { continue }
                seen.insert(key)

                let category = CategoryDetector.detect(merchant: txn.description, issuer: institution)
                let row = StatementRow(
                    transactionDate: txn.date,
                    category: category,
                    amount: txn.amount,
                    transactionDescription: txn.description
                )
                statement.rows.append(row)
                modelContext.insert(row)
                inserted += 1
            }
        }

        try? modelContext.save()
        return inserted
    }

    private static func dedupeKey(date: Date, description: String, amount: Double) -> String {
        let day = RemoteTransaction.dayFormatter.string(from: date)
        let desc = description.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let amt = String(format: "%.2f", amount)
        return "\(day)|\(desc)|\(amt)"
    }
}
