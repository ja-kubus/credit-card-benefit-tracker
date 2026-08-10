//
//  LinkSyncService.swift
//  Credit Card Benefit Tracker
//
//  Pulls linked transactions from the backend and inserts them into SwiftData as
//  Statement/StatementRow, so linked data lives alongside uploaded statements and
//  is categorized identically (same CategoryDetector + MerchantCategoryRules).
//
//  Linked transactions only become visible once the user maps the linked account
//  to one of their wallet cards (LinkedAccountMap). Until then the data is stored
//  in a standalone statement (cardID "linked_<accountId>") that no card shows;
//  assigning a card re-parents that statement so the transactions appear.
//

import Foundation
import SwiftData

enum LinkSyncService {
    /// Fetch transactions and merge them into SwiftData.
    /// - Returns: number of new StatementRows inserted.
    @discardableResult
    @MainActor
    static func sync(since: Date? = nil, modelContext: ModelContext) async throws -> Int {
        let sinceDate = since ?? Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
        let transactions = try await LinkBackendClient.shared.transactions(since: sinceDate)
        return merge(transactions: transactions, modelContext: modelContext)
    }

    /// Insert the given remote transactions, deduping against existing rows and
    /// attaching each account's statement to its mapped card (if one is assigned).
    @MainActor
    static func merge(transactions: [RemoteTransaction], modelContext: ModelContext) -> Int {
        guard !transactions.isEmpty else { return 0 }

        // Import posted transactions only (pending ones churn before settling).
        let posted = transactions.filter { $0.status.isEmpty || $0.status == "posted" }
        guard !posted.isEmpty else { return 0 }

        let existingRows = (try? modelContext.fetch(FetchDescriptor<StatementRow>())) ?? []
        let userCards = (try? modelContext.fetch(FetchDescriptor<UserCard>())) ?? []
        let existingStatements = (try? modelContext.fetch(FetchDescriptor<Statement>())) ?? []
        let maps = (try? modelContext.fetch(FetchDescriptor<LinkedAccountMap>())) ?? []

        var seen = Set<String>()
        for row in existingRows {
            seen.insert(dedupeKey(date: row.transactionDate,
                                  description: row.transactionDescription,
                                  amount: row.amount))
        }

        let grouped = Dictionary(grouping: posted, by: { $0.accountId })
        var inserted = 0

        for (accountId, txns) in grouped {
            let accountName = txns.first?.accountName ?? "Account"
            let statementFileName = "Linked · \(accountName)"

            // The card this account is mapped to, if any.
            let mappedCatalogID = maps.first(where: { $0.accountId == accountId })?.catalogCardID
            let targetCard = mappedCatalogID.flatMap { id in
                userCards.first(where: { $0.catalogCardID == id })
            }
            let issuerForCategorization = targetCard?.issuer ?? accountName

            // Find-or-create one Statement per linked account. Match by the stable
            // linkedAccountId, falling back to the legacy fileName match so
            // statements imported before this field existed aren't duplicated.
            let statement: Statement
            if let existing = existingStatements.first(where: {
                $0.linkedAccountId == accountId ||
                ($0.linkedAccountId == nil && $0.fileName == statementFileName)
            }) {
                statement = existing
            } else {
                statement = Statement(
                    cardID: targetCard?.catalogCardID ?? "linked_\(accountId)",
                    fileName: statementFileName,
                    issuer: issuerForCategorization
                )
                modelContext.insert(statement)
            }
            statement.linkedAccountId = accountId

            // Ensure the statement is parented to the mapped card (or standalone).
            reparent(statement: statement, to: targetCard, userCards: userCards)

            if let latest = txns.map(\.date).max() {
                statement.statementMonth = latest
            }

            for txn in txns {
                let key = dedupeKey(date: txn.date, description: txn.description, amount: txn.amount)
                if seen.contains(key) { continue }
                seen.insert(key)

                let category = CategoryDetector.detect(merchant: txn.description, issuer: issuerForCategorization)
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

    /// Assign a linked account to a card: upsert the mapping and immediately
    /// re-parent any already-imported statement for that account to the card, so
    /// its transactions show up without waiting for another sync.
    @MainActor
    static func assign(accountId: String,
                       to card: UserCard,
                       accountDisplayName: String,
                       institution: String,
                       lastFour: String,
                       modelContext: ModelContext) {
        let maps = (try? modelContext.fetch(FetchDescriptor<LinkedAccountMap>())) ?? []
        if let existing = maps.first(where: { $0.accountId == accountId }) {
            existing.catalogCardID = card.catalogCardID
            existing.accountDisplayName = accountDisplayName
            existing.institution = institution
            existing.lastFour = lastFour
        } else {
            modelContext.insert(LinkedAccountMap(
                accountId: accountId,
                catalogCardID: card.catalogCardID,
                accountDisplayName: accountDisplayName,
                institution: institution,
                lastFour: lastFour
            ))
        }

        let userCards = (try? modelContext.fetch(FetchDescriptor<UserCard>())) ?? []
        let statements = (try? modelContext.fetch(FetchDescriptor<Statement>())) ?? []
        for statement in statements where statement.linkedAccountId == accountId {
            reparent(statement: statement, to: card, userCards: userCards)
        }
        try? modelContext.save()
    }

    /// The card a linked account is currently mapped to, if any.
    @MainActor
    static func mappedCard(for accountId: String, modelContext: ModelContext) -> UserCard? {
        let maps = (try? modelContext.fetch(FetchDescriptor<LinkedAccountMap>())) ?? []
        guard let catalogID = maps.first(where: { $0.accountId == accountId })?.catalogCardID else { return nil }
        let userCards = (try? modelContext.fetch(FetchDescriptor<UserCard>())) ?? []
        return userCards.first(where: { $0.catalogCardID == catalogID })
    }

    /// Move a statement onto `card` (or detach to standalone when nil). Removes it
    /// from any other card's statements first so it lives under exactly one card.
    @MainActor
    private static func reparent(statement: Statement, to card: UserCard?, userCards: [UserCard]) {
        // Remove from any card that currently holds it.
        for c in userCards {
            c.statements.removeAll { $0.persistentModelID == statement.persistentModelID }
        }
        if let card {
            statement.cardID = card.catalogCardID
            if !card.statements.contains(where: { $0.persistentModelID == statement.persistentModelID }) {
                card.statements.append(statement)
            }
        } else {
            // Standalone (unmapped): keep a distinct cardID so it isn't confused
            // with any real card.
            if let acct = statement.linkedAccountId {
                statement.cardID = "linked_\(acct)"
            }
        }
    }

    private static func dedupeKey(date: Date, description: String, amount: Double) -> String {
        let day = RemoteTransaction.dayFormatter.string(from: date)
        let desc = description.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let amt = String(format: "%.2f", amount)
        return "\(day)|\(desc)|\(amt)"
    }
}
