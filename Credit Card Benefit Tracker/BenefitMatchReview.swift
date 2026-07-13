//
//  BenefitMatchReview.swift
//  Credit Card Benefit Tracker
//
//  Matching engine + review sheet for auto-checking benefits
//  against imported statement transactions.
//

import SwiftUI
import SwiftData

// MARK: - Match model

struct BenefitMatch: Identifiable {
    let id = UUID()
    let completion: BenefitCompletion
    let matchedRows: [StatementRow]
    let cardName: String
    /// True when the matched transactions fall in the PREVIOUS period window
    /// (the statement covers a period that has already reset).
    let isFromPreviousPeriod: Bool
    /// uploadHash of the statement the matched rows came from — recorded on the
    /// completion so deleting that statement can undo the auto-check-off.
    let sourceStatementHash: String

    /// Sum of all matched rows' amounts, capped at the benefit's dollarAmount.
    var totalMatchedAmount: Double {
        min(matchedRows.reduce(0) { $0 + $1.amount }, completion.dollarAmount)
    }

    /// True when the summed matched amount >= the benefit's dollarAmount (full completion);
    /// false means we'll record partial usage instead.
    var isFullMatch: Bool { totalMatchedAmount >= completion.dollarAmount }
}

// MARK: - Matching engine

enum BenefitMatcher {

    /// Finds benefit matches for the given card against the given new statement rows.
    /// Checks both the current period window and the previous period window
    /// (common case: uploading last month's statement after the period rolled over).
    /// Returns at most one match per completion, carrying all matching rows.
    static func findMatches(card: UserCard, in rows: [StatementRow], sourceHash: String) -> [BenefitMatch] {
        var matches: [BenefitMatch] = []

        for completion in card.completions {
            guard !completion.isCompleted,
                  !completion.isIgnored,
                  completion.dollarAmount > 0 else { continue }

            let currentStart = periodStart(before: completion.resetDate, period: completion.benefitPeriod)
            let previousStart = periodStart(before: currentStart, period: completion.benefitPeriod)

            let currentRows = rows.filter { row in
                row.transactionDate >= currentStart &&
                row.transactionDate < completion.resetDate &&
                rowMatches(completion: completion, row: row)
            }

            if !currentRows.isEmpty {
                matches.append(BenefitMatch(
                    completion: completion,
                    matchedRows: currentRows,
                    cardName: card.name,
                    isFromPreviousPeriod: false,
                    sourceStatementHash: sourceHash
                ))
                continue
            }

            let previousRows = rows.filter { row in
                row.transactionDate >= previousStart &&
                row.transactionDate < currentStart &&
                rowMatches(completion: completion, row: row)
            }

            if !previousRows.isEmpty {
                matches.append(BenefitMatch(
                    completion: completion,
                    matchedRows: previousRows,
                    cardName: card.name,
                    isFromPreviousPeriod: true,
                    sourceStatementHash: sourceHash
                ))
            }
        }

        return matches
    }

    /// True calendar-aligned period start: the period boundary one period-length before `date`.
    private static func periodStart(before date: Date, period: BenefitPeriod) -> Date {
        let calendar = Calendar.current
        let result: Date?
        switch period {
        case .monthly:      result = calendar.date(byAdding: .month, value: -1, to: date)
        case .quarterly:    result = calendar.date(byAdding: .month, value: -3, to: date)
        case .semiAnnually: result = calendar.date(byAdding: .month, value: -6, to: date)
        case .annually:     result = calendar.date(byAdding: .year, value: -1, to: date)
        }
        return result ?? date
    }

    private static func rowMatches(completion: BenefitCompletion, row: StatementRow) -> Bool {
        let text = (completion.benefitName + " " + completion.benefitDescription).lowercased()
        let rowDesc = row.transactionDescription.lowercased()
        let category = row.category

        if text.contains("uber") && rowDesc.contains("uber") { return true }
        if text.contains("lyft") && rowDesc.contains("lyft") { return true }
        if text.contains("dining") && category == "Restaurants" { return true }
        if (text.contains("airline") || text.contains("flight")) && (category == "Flights" || category == "Airlines") { return true }
        if (text.contains("hotel") || text.contains("resort")) && category == "Hotels" { return true }
        if text.contains("streaming") && category == "Streaming" { return true }
        if (text.contains("grocery") || text.contains("supermarket")) && category == "Supermarkets" { return true }
        if text.contains("gas") && category == "Gas Stations" { return true }
        if (text.contains("transit") || text.contains("commut")) && category == "Transit" { return true }

        return false
    }
}

// MARK: - Review sheet

struct BenefitMatchReviewSheet: View {
    let matches: [BenefitMatch]
    /// Called with the benefits that were actually checked off (empty on Skip).
    let onDone: ([AppliedBenefitResult]) -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var approved: Set<UUID>

    init(matches: [BenefitMatch], onDone: @escaping ([AppliedBenefitResult]) -> Void) {
        self.matches = matches
        self.onDone = onDone
        // Previous-period matches default to OFF — the completion has already reset,
        // so confirming them requires explicit user intent.
        _approved = State(initialValue: Set(matches.filter { !$0.isFromPreviousPeriod }.map(\.id)))
    }

    var body: some View {
        NavigationStack {
            Group {
                if matches.isEmpty {
                    ContentUnavailableView(
                        "No Matches",
                        systemImage: "checkmark.circle",
                        description: Text("No statement transactions matched your unclaimed benefits.")
                    )
                } else {
                    List {
                        Section {
                            ForEach(matches) { match in
                                matchRow(match)
                            }
                        } header: {
                            Text("We found transactions in this statement that match your unclaimed benefits. Confirm to mark them off.")
                                .textCase(nil)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Benefits Found")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                bottomButtons
            }
        }
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled()
    }

    private func matchRow(_ match: BenefitMatch) -> some View {
        Toggle(isOn: binding(for: match.id)) {
            VStack(alignment: .leading, spacing: 4) {
                Text(match.completion.benefitName)
                    .font(.body.weight(.semibold))
                Text(match.cardName)
                    .font(.caption)
                    .foregroundStyle(Color.appCoral)
                if let first = match.matchedRows.first {
                    let extra = match.matchedRows.count - 1
                    let merchant = extra > 0
                        ? "\(first.transactionDescription) +\(extra) more"
                        : first.transactionDescription
                    Text("\(merchant) • \(match.totalMatchedAmount, format: .currency(code: "USD")) • \(first.transactionDate, format: .dateTime.month(.abbreviated).day())")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if match.isFromPreviousPeriod {
                    Text("(from last period — confirm you used it before the reset)")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                badge(for: match)
            }
        }
    }

    @ViewBuilder
    private func badge(for match: BenefitMatch) -> some View {
        if match.isFullMatch {
            badgeLabel("Will complete", color: .appLeaf)
        } else {
            badgeLabel("Partial: $\(Int(match.totalMatchedAmount)) of $\(Int(match.completion.dollarAmount))", color: .appGiraffe)
        }
    }

    private func badgeLabel(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private var bottomButtons: some View {
        VStack(spacing: 10) {
            Button {
                confirmSelected()
            } label: {
                Text("Confirm Selected")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(approved.isEmpty || matches.isEmpty)

            Button {
                onDone([])
            } label: {
                Text("Skip")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(.bar)
    }

    private func binding(for id: UUID) -> Binding<Bool> {
        Binding(
            get: { approved.contains(id) },
            set: { isOn in
                if isOn { approved.insert(id) } else { approved.remove(id) }
            }
        )
    }

    private func confirmSelected() {
        var applied: [AppliedBenefitResult] = []

        for match in matches where approved.contains(match.id) {
            // Previous-period matches must NOT mark the current period complete —
            // the completion has already reset for the new period.
            if match.isFromPreviousPeriod { continue }

            let completion = match.completion
            completion.autoCheckSourceHash = match.sourceStatementHash
            if match.isFullMatch {
                completion.isCompleted = true
                completion.partialUsage = ""
                applied.append(AppliedBenefitResult(benefitName: completion.benefitName, outcome: .completed))
            } else {
                // ADD to any existing partial usage rather than overwriting it.
                let existing = Double(completion.partialUsage) ?? 0
                let newTotal = min(existing + match.totalMatchedAmount, completion.dollarAmount)
                if newTotal >= completion.dollarAmount {
                    completion.isCompleted = true
                    completion.partialUsage = ""
                    applied.append(AppliedBenefitResult(benefitName: completion.benefitName, outcome: .completed))
                } else {
                    completion.partialUsage = String(Int(newTotal))
                    completion.isCompleted = false
                    applied.append(AppliedBenefitResult(
                        benefitName: completion.benefitName,
                        outcome: .partial(used: Int(newTotal), of: Int(completion.dollarAmount))
                    ))
                }
            }
        }
        try? modelContext.save()
        onDone(applied)
    }
}

/// What actually happened to a benefit the user confirmed in the review sheet —
/// reported back so the upload success popup can list the checked-off benefits.
struct AppliedBenefitResult {
    enum Outcome {
        case completed
        case partial(used: Int, of: Int)
    }
    let benefitName: String
    let outcome: Outcome

    var summaryLine: String {
        switch outcome {
        case .completed:
            return "✓ \(benefitName) — marked complete"
        case .partial(let used, let of):
            return "◐ \(benefitName) — $\(used) of $\(of) recorded"
        }
    }
}
