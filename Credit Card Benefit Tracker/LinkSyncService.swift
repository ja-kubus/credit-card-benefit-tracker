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

            // Find (and consolidate any duplicates of) this account's statement,
            // or create one. Matching is robust to the legacy naming/id schemes so
            // we never orphan the original rows or leave empty duplicate shells.
            let candidates = linkedStatements(for: accountId, fileName: statementFileName, in: existingStatements)
            let statement: Statement
            if let primary = consolidate(candidates, modelContext: modelContext) {
                statement = primary
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

        cleanupEmptyLinkedStatements(modelContext: modelContext)
        try? modelContext.save()
        return inserted
    }

    /// Remove ALL on-device data for a linked account: its statement(s), their
    /// rows (cascade), and the account->card mapping. The wallet card itself is
    /// kept — it may hold manual statements, benefits, and other linked accounts.
    /// Called when the user disconnects an account. Returns rows removed.
    @MainActor
    @discardableResult
    static func removeData(forAccountId accountId: String, modelContext: ModelContext) -> Int {
        let statements = (try? modelContext.fetch(FetchDescriptor<Statement>())) ?? []
        let userCards = (try? modelContext.fetch(FetchDescriptor<UserCard>())) ?? []
        let maps = (try? modelContext.fetch(FetchDescriptor<LinkedAccountMap>())) ?? []

        var removedRows = 0
        for statement in statements where linkedAccountId(of: statement) == accountId {
            removedRows += statement.rows.count
            for c in userCards {
                c.statements.removeAll { $0.persistentModelID == statement.persistentModelID }
            }
            modelContext.delete(statement) // cascade-deletes rows
        }
        for map in maps where map.accountId == accountId {
            modelContext.delete(map)
        }
        try? modelContext.save()
        return removedRows
    }

    /// Remove on-device linked data whose account is no longer in the active set
    /// (e.g. disconnected in a previous session, or from another device). Only
    /// call with an AUTHORITATIVE active-account list from a successful fetch —
    /// never on error, or it could wipe still-valid data. Returns statements removed.
    @MainActor
    @discardableResult
    static func reconcile(activeAccountIds: Set<String>, modelContext: ModelContext) -> Int {
        let statements = (try? modelContext.fetch(FetchDescriptor<Statement>())) ?? []
        let userCards = (try? modelContext.fetch(FetchDescriptor<UserCard>())) ?? []
        let maps = (try? modelContext.fetch(FetchDescriptor<LinkedAccountMap>())) ?? []

        var removed = 0
        for statement in statements {
            guard let acct = linkedAccountId(of: statement) else { continue } // linked only
            if !activeAccountIds.contains(acct) {
                for c in userCards {
                    c.statements.removeAll { $0.persistentModelID == statement.persistentModelID }
                }
                modelContext.delete(statement)
                removed += 1
            }
        }
        for map in maps where !activeAccountIds.contains(map.accountId) {
            modelContext.delete(map)
        }
        if removed > 0 || !maps.isEmpty { try? modelContext.save() }
        return removed
    }

    /// The linked account id a statement belongs to, if any (handles the legacy
    /// standalone cardID scheme as a fallback).
    private static func linkedAccountId(of statement: Statement) -> String? {
        if let id = statement.linkedAccountId { return id }
        if statement.cardID.hasPrefix("linked_") {
            return String(statement.cardID.dropFirst("linked_".count))
        }
        return nil
    }

    /// Delete linked statements that have no transactions. These accumulate when
    /// an account is reconnected (Stripe issues a new account id) and its
    /// transactions all dedupe against a prior import, leaving an empty shell.
    /// Only linked statements are touched — manual uploads are never deleted.
    @MainActor
    @discardableResult
    static func cleanupEmptyLinkedStatements(modelContext: ModelContext) -> Int {
        let statements = (try? modelContext.fetch(FetchDescriptor<Statement>())) ?? []
        let userCards = (try? modelContext.fetch(FetchDescriptor<UserCard>())) ?? []
        var removed = 0
        for statement in statements {
            let isLinked = statement.linkedAccountId != nil || statement.cardID.hasPrefix("linked_")
            guard isLinked, statement.rows.isEmpty else { continue }
            for c in userCards {
                c.statements.removeAll { $0.persistentModelID == statement.persistentModelID }
            }
            modelContext.delete(statement)
            removed += 1
        }
        if removed > 0 { try? modelContext.save() }
        return removed
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
        let fileName = "Linked · \(accountDisplayName)"
        let candidates = linkedStatements(for: accountId, fileName: fileName, in: statements)
        if let primary = consolidate(candidates, modelContext: modelContext) {
            primary.linkedAccountId = accountId
            reparent(statement: primary, to: card, userCards: userCards)
        }
        cleanupEmptyLinkedStatements(modelContext: modelContext)
        try? modelContext.save()
    }

    /// All statements that belong to a linked account, across the current and
    /// legacy identification schemes (stable id, standalone cardID, legacy name).
    @MainActor
    private static func linkedStatements(for accountId: String, fileName: String, in statements: [Statement]) -> [Statement] {
        statements.filter {
            $0.linkedAccountId == accountId ||
            $0.cardID == "linked_\(accountId)" ||
            ($0.linkedAccountId == nil && $0.fileName == fileName)
        }
    }

    /// Collapse duplicate statements for one account into a single statement:
    /// keep the one with the most rows, move any rows from the others into it
    /// (deduped), and delete the now-empty duplicates. Returns the survivor.
    @MainActor
    private static func consolidate(_ candidates: [Statement], modelContext: ModelContext) -> Statement? {
        guard let primary = candidates.max(by: { $0.rows.count < $1.rows.count }) else { return nil }
        var seen = Set(primary.rows.map { dedupeKey(date: $0.transactionDate, description: $0.transactionDescription, amount: $0.amount) })
        for other in candidates where other.persistentModelID != primary.persistentModelID {
            for row in other.rows {
                let key = dedupeKey(date: row.transactionDate, description: row.transactionDescription, amount: row.amount)
                if seen.contains(key) { continue }
                seen.insert(key)
                let copy = StatementRow(
                    transactionDate: row.transactionDate,
                    category: row.category,
                    amount: row.amount,
                    transactionDescription: row.transactionDescription
                )
                primary.rows.append(copy)
                modelContext.insert(copy)
            }
            modelContext.delete(other) // cascade-deletes its (now-copied) rows
        }
        return primary
    }

    /// When an account is (re)connected, inherit the card assignment from a prior
    /// mapping for the SAME institution + last-4. Stripe issues a new account id
    /// on each reconnect, so without this the user would have to reassign the card
    /// every time. No-op if the account is already mapped or has no last-4.
    @MainActor
    static func inheritMappingIfPossible(accountId: String,
                                         institution: String,
                                         lastFour: String,
                                         accountDisplayName: String,
                                         modelContext: ModelContext) {
        let maps = (try? modelContext.fetch(FetchDescriptor<LinkedAccountMap>())) ?? []
        if maps.contains(where: { $0.accountId == accountId }) { return }
        // Match a prior mapping by card NAME + institution first (last-4 is not
        // unique — e.g. every Amex card on a membership shares the same last-4),
        // falling back to last-4 only when a display name isn't available.
        guard let match = maps.first(where: { m in
            guard m.institution == institution else { return false }
            if !accountDisplayName.isEmpty && !m.accountDisplayName.isEmpty {
                return m.accountDisplayName == accountDisplayName
            }
            return !lastFour.isEmpty && m.lastFour == lastFour
        }) else { return }
        modelContext.insert(LinkedAccountMap(
            accountId: accountId,
            catalogCardID: match.catalogCardID,
            accountDisplayName: accountDisplayName,
            institution: institution,
            lastFour: lastFour
        ))
        try? modelContext.save()
    }

    /// Remove ALL on-device linked data (every linked statement + row + mapping),
    /// for the "delete all my data" flow. Wallet cards and manual statements stay.
    @MainActor
    @discardableResult
    static func removeAllLinkedData(modelContext: ModelContext) -> Int {
        let statements = (try? modelContext.fetch(FetchDescriptor<Statement>())) ?? []
        let userCards = (try? modelContext.fetch(FetchDescriptor<UserCard>())) ?? []
        let maps = (try? modelContext.fetch(FetchDescriptor<LinkedAccountMap>())) ?? []
        var removed = 0
        for statement in statements where linkedAccountId(of: statement) != nil {
            for c in userCards {
                c.statements.removeAll { $0.persistentModelID == statement.persistentModelID }
            }
            modelContext.delete(statement)
            removed += 1
        }
        for map in maps { modelContext.delete(map) }
        try? modelContext.save()
        return removed
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
