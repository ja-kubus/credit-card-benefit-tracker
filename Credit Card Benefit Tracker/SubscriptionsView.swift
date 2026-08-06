//
//  SubscriptionsView.swift
//  Credit Card Benefit Tracker
//
//  Detects and lists recurring subscriptions from uploaded statement transactions.
//

import SwiftUI
import SwiftData

// MARK: - Detected Subscription Model

struct DetectedSubscription: Identifiable {
    let id = UUID()
    let merchant: String        // a display name (most common raw description in the group)
    let amount: Double
    let cardName: String        // most common card for this subscription
    let occurrences: Int        // number of charges
    let months: Int             // distinct months
    let lastCharged: Date
    let category: String
    let normalizedMerchantKey: String   // stable normalized key used for grouping

    /// Stable identity for ignoring: normalized merchant key + amount in cents.
    var ignoreKey: String {
        "\(normalizedMerchantKey)|\(Int((amount * 100).rounded()))"
    }
}

// MARK: - Ignored Subscriptions Store

/// Persists user-ignored subscription keys so they are never flagged again.
enum IgnoredSubscriptionsStore {
    private static let key = "ignoredSubscriptions"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: "group.benefittracker.shared") ?? .standard
    }

    static func ignoredKeys() -> Set<String> {
        let array = defaults.stringArray(forKey: key) ?? []
        return Set(array)
    }

    static func ignore(_ ignoreKey: String) {
        var set = ignoredKeys()
        set.insert(ignoreKey)
        defaults.set(Array(set), forKey: key)
    }

    static func unignore(_ ignoreKey: String) {
        var set = ignoredKeys()
        set.remove(ignoreKey)
        defaults.set(Array(set), forKey: key)
    }
}

// MARK: - Detection Engine

private enum SubscriptionDetector {

    /// A single transaction annotated with its source card and month key.
    private struct Charge {
        let rawDescription: String
        let normalizedKey: String
        let roundedAmount: Double
        let amount: Double
        let cardName: String
        let category: String
        let date: Date
        let monthKey: String     // "yyyy-MM"
    }

    /// Normalize a merchant description into a stable grouping key.
    /// Lowercases, strips store/reference numbers and common noise, collapses whitespace.
    static func normalize(_ description: String) -> String {
        var s = description.lowercased()

        // Remove "#12345" style store numbers.
        s = s.replacingOccurrences(of: "#\\s*\\d+", with: " ", options: .regularExpression)
        // Remove standalone long digit runs (reference / transaction numbers).
        s = s.replacingOccurrences(of: "\\b\\d{3,}\\b", with: " ", options: .regularExpression)
        // Remove trailing digits/store numbers left at the end.
        s = s.replacingOccurrences(of: "\\d+\\s*$", with: " ", options: .regularExpression)
        // Strip common noise tokens/punctuation.
        s = s.replacingOccurrences(of: "[*#.,/\\\\-]", with: " ", options: .regularExpression)
        // Collapse whitespace.
        s = s.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func monthKey(for date: Date, calendar: Calendar) -> String {
        let comps = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", comps.year ?? 0, comps.month ?? 0)
    }

    /// Detect subscriptions across all cards, excluding any the user has ignored.
    static func detect(from cards: [UserCard]) -> [DetectedSubscription] {
        let ignored = IgnoredSubscriptionsStore.ignoredKeys()
        return detectAll(from: cards).filter { !ignored.contains($0.ignoreKey) }
    }

    /// Detect subscriptions the user has ignored (the ignored subset only).
    static func detectIgnored(from cards: [UserCard]) -> [DetectedSubscription] {
        let ignored = IgnoredSubscriptionsStore.ignoredKeys()
        return detectAll(from: cards).filter { ignored.contains($0.ignoreKey) }
    }

    /// Detect all subscriptions across all cards, including ignored ones.
    static func detectAll(from cards: [UserCard]) -> [DetectedSubscription] {
        var calendar = Calendar.current
        calendar.timeZone = .current

        // 1. Gather all charges.
        var charges: [Charge] = []
        for card in cards {
            for statement in card.statements {
                for row in statement.rows {
                    // Negative/zero amounts are credits, refunds, or returned
                    // payments — never a subscription charge.
                    guard row.amount > 0 else { continue }
                    let normalized = normalize(row.transactionDescription)
                    guard !normalized.isEmpty else { continue }
                    let rounded = (row.amount * 100).rounded() / 100   // nearest cent
                    charges.append(
                        Charge(
                            rawDescription: row.transactionDescription
                                .trimmingCharacters(in: .whitespacesAndNewlines),
                            normalizedKey: normalized,
                            roundedAmount: rounded,
                            amount: row.amount,
                            cardName: card.name,
                            category: row.category,
                            date: row.transactionDate,
                            monthKey: monthKey(for: row.transactionDate, calendar: calendar)
                        )
                    )
                }
            }
        }

        // 2/3. Group by (normalizedMerchant, roundedAmount).
        struct GroupKey: Hashable {
            let merchant: String
            let amount: Double
        }
        var groups: [GroupKey: [Charge]] = [:]
        for charge in charges {
            let key = GroupKey(merchant: charge.normalizedKey, amount: charge.roundedAmount)
            groups[key, default: []].append(charge)
        }

        // 4/5. Build results for groups spanning >= 2 distinct months.
        var results: [DetectedSubscription] = []
        for (_, members) in groups {
            let distinctMonths = Set(members.map { $0.monthKey })
            guard distinctMonths.count >= 2 else { continue }

            results.append(
                DetectedSubscription(
                    merchant: mostCommon(members.map { $0.rawDescription }) ?? members[0].rawDescription,
                    amount: members[0].roundedAmount,
                    cardName: mostCommon(members.map { $0.cardName }) ?? members[0].cardName,
                    occurrences: members.count,
                    months: distinctMonths.count,
                    lastCharged: members.map { $0.date }.max() ?? members[0].date,
                    category: mostCommon(members.map { $0.category }) ?? members[0].category,
                    normalizedMerchantKey: members[0].normalizedKey
                )
            )
        }

        // Sort by amount (monthly cost) descending.
        return results.sorted { $0.amount > $1.amount }
    }

    /// Returns the most frequently occurring element in an array.
    private static func mostCommon<T: Hashable>(_ values: [T]) -> T? {
        var counts: [T: Int] = [:]
        for v in values { counts[v, default: 0] += 1 }
        return counts.max { $0.value < $1.value }?.key
    }
}

// MARK: - Subscriptions View

struct SubscriptionsView: View {
    @Query private var userCards: [UserCard]

    @State private var refreshToken = UUID()
    @State private var showingIgnored = false

    private var subscriptions: [DetectedSubscription] {
        _ = refreshToken
        return SubscriptionDetector.detect(from: userCards)
    }

    private var ignoredSubscriptions: [DetectedSubscription] {
        _ = refreshToken
        return SubscriptionDetector.detectIgnored(from: userCards)
    }

    private var totalMonthly: Double {
        subscriptions.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        NavigationStack {
            Group {
                if subscriptions.isEmpty {
                    ContentUnavailableView(
                        "No Subscriptions Found",
                        systemImage: "repeat.circle",
                        description: Text("Upload at least two months of statements and we'll spot recurring charges — same merchant, same amount, 2+ months.")
                    )
                } else {
                    List {
                        Section {
                            Text("Duplicate transactions over 2+ consecutive months")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 4, trailing: 16))
                                .listRowSeparator(.hidden)
                            summaryHeader
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                .listRowSeparator(.hidden)
                        }

                        Section {
                            ForEach(subscriptions) { sub in
                                subscriptionRow(sub)
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            IgnoredSubscriptionsStore.ignore(sub.ignoreKey)
                                            refreshToken = UUID()
                                        } label: {
                                            Label("Ignore", systemImage: "eye.slash")
                                        }
                                    }
                            }
                        } footer: {
                            Text("Detected from repeated charges in your statements. Review and cancel any you no longer use.")
                                .font(.footnote)
                        }
                    }
                }
            }
            .navigationTitle("Subscriptions")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingIgnored = true
                    } label: {
                        Image(systemName: "eye.slash.circle")
                            .foregroundStyle(Color.appCoral)
                    }
                    .accessibilityLabel("View ignored subscriptions")
                }
            }
            .sheet(isPresented: $showingIgnored) {
                ignoredSheet
            }
        }
    }

    // MARK: Ignored Sheet

    private var ignoredSheet: some View {
        NavigationStack {
            Group {
                if ignoredSubscriptions.isEmpty {
                    ContentUnavailableView(
                        "Nothing Ignored",
                        systemImage: "eye",
                        description: Text("Subscriptions you ignore will appear here so you can restore them.")
                    )
                } else {
                    List {
                        ForEach(ignoredSubscriptions) { sub in
                            subscriptionRow(sub)
                                .swipeActions(edge: .trailing) {
                                    Button {
                                        IgnoredSubscriptionsStore.unignore(sub.ignoreKey)
                                        refreshToken = UUID()
                                    } label: {
                                        Label("Restore", systemImage: "arrow.uturn.backward")
                                    }
                                    .tint(Color.appLeaf)
                                }
                        }
                    }
                }
            }
            .navigationTitle("Ignored")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showingIgnored = false }
                }
            }
        }
    }

    // MARK: Summary Header

    private var summaryHeader: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Estimated Monthly")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(totalMonthly, format: .currency(code: "USD"))
                    .font(.title2.bold())
                    .foregroundStyle(Color.appCoral)
            }

            Divider()
                .frame(height: 36)

            VStack(alignment: .leading, spacing: 4) {
                Text("Subscriptions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(subscriptions.count)")
                    .font(.title2.bold())
                    .foregroundStyle(Color.appLeaf)
            }

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.appSage.opacity(0.5))
        )
    }

    // MARK: Subscription Row

    private func subscriptionRow(_ sub: DetectedSubscription) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(sub.merchant)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                Spacer()
                Text(sub.amount, format: .currency(code: "USD"))
                    .font(.body.weight(.semibold))
            }

            Text(sub.cardName)
                .font(.caption)
                .foregroundStyle(Color.appCoral)

            HStack(alignment: .top, spacing: 8) {
                categoryChip(sub.category)

                Text("\(sub.occurrences) charges · \(sub.months) months · last \(sub.lastCharged, format: .dateTime.month().day().year())")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
    }

    private func categoryChip(_ category: String) -> some View {
        Text(category)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(Color.appLeaf.opacity(0.2))
            )
            .foregroundStyle(Color.appLeaf)
    }
}
