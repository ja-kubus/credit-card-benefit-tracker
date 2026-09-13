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
        let tokens: [String]     // normalizedKey split into words, for prefix matching
        let roundedAmount: Double
        let amount: Double
        let cardName: String
        let category: String
        let date: Date
        let monthKey: String     // "yyyy-MM"
    }

    /// Words that carry no merchant identity — dropped so descriptor noise
    /// doesn't split one subscription into two keys.
    private static let stopWords: Set<String> = [
        "the", "a", "an", "and", "of", "for", "to", "at", "on", "llc", "inc",
        "co", "corp", "ltd", "com", "www", "http", "https"
    ]

    /// How close two charge amounts must be to count as the SAME recurring
    /// charge. Recurring bills drift (insurance premiums tick up, streaming
    /// price hikes), so an exact-amount match wrongly splits one subscription;
    /// amounts within 20% of the previous charge are treated as one.
    private static let amountRelTolerance = 0.20

    /// Normalize a merchant description into a stable grouping key.
    /// Tokenizes and drops tokens that contain a digit (store/reference/order
    /// numbers), single characters, and obvious stop words, so the same
    /// merchant produces one stable key ("geico auto") regardless of trailing
    /// ids or punctuation. Falls back to digit-stripped text if nothing remains.
    static func normalize(_ description: String) -> String {
        let lowered = description.lowercased()
        let tokens = lowered.split { !($0.isLetter || $0.isNumber) }
        let kept = tokens.filter { t in
            if t.count < 2 { return false }
            if t.contains(where: { $0.isNumber }) { return false }
            if stopWords.contains(String(t)) { return false }
            return true
        }
        let key = kept.joined(separator: " ")
        return key.isEmpty
            ? lowered.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                     .trimmingCharacters(in: .whitespacesAndNewlines)
            : key
    }

    /// Whether two charges are the same recurring subscription. True when their
    /// amounts are within tolerance AND their merchant keys are compatible —
    /// i.e. one token list is a leading prefix of the other. This groups the
    /// same service whose descriptor text varies month to month
    /// ("google youtube premium" vs "google youtube"; "walmart plus" vs
    /// "walmart") while keeping distinct services at one biller apart
    /// ("google youtube" vs "google nest").
    private static func sameSubscription(_ a: Charge, _ b: Charge) -> Bool {
        let ref = max(min(a.roundedAmount, b.roundedAmount), 0.01)
        guard abs(a.roundedAmount - b.roundedAmount) / ref <= amountRelTolerance else { return false }
        let (short, long) = a.tokens.count <= b.tokens.count ? (a.tokens, b.tokens) : (b.tokens, a.tokens)
        guard !short.isEmpty else { return false }
        return Array(long.prefix(short.count)) == short
    }

    /// Cluster charges into subscriptions via union-find over `sameSubscription`.
    /// Charges are pre-bucketed by their first token so we only compare within a
    /// brand (keeps it fast and prevents unrelated brands from ever joining).
    private static func clusterCharges(_ members: [Charge]) -> [[Charge]] {
        var buckets: [String: [Charge]] = [:]
        for c in members {
            buckets[c.tokens.first ?? c.normalizedKey, default: []].append(c)
        }

        var clusters: [[Charge]] = []
        for (_, bucket) in buckets {
            let n = bucket.count
            var parent = Array(0..<n)
            func find(_ x: Int) -> Int {
                var r = x
                while parent[r] != r { parent[r] = parent[parent[r]]; r = parent[r] }
                return r
            }
            for i in 0..<n {
                for j in (i + 1)..<n where sameSubscription(bucket[i], bucket[j]) {
                    parent[find(i)] = find(j)
                }
            }
            var grouped: [Int: [Charge]] = [:]
            for i in 0..<n { grouped[find(i), default: []].append(bucket[i]) }
            clusters.append(contentsOf: grouped.values)
        }
        return clusters
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
                            tokens: normalized.split(separator: " ").map(String.init),
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

        // 2/3/4/5. Cluster charges into subscriptions: same brand + compatible
        // descriptor (token-prefix) + nearby amount. This consolidates a service
        // whose descriptor text OR price drifts month to month (e.g. Google,
        // Walmart+, GEICO) instead of splitting it and double-counting. Keep
        // clusters spanning >= 2 distinct months. The representative amount is
        // the most RECENT charge's, reflecting the current monthly cost.
        var results: [DetectedSubscription] = []
        for members in clusterCharges(charges) {
            let distinctMonths = Set(members.map { $0.monthKey })
            guard distinctMonths.count >= 2 else { continue }

            let latest = members.max { $0.date < $1.date } ?? members[0]
            results.append(
                DetectedSubscription(
                    merchant: mostCommon(members.map { $0.rawDescription }) ?? latest.rawDescription,
                    amount: latest.roundedAmount,
                    cardName: mostCommon(members.map { $0.cardName }) ?? latest.cardName,
                    occurrences: members.count,
                    months: distinctMonths.count,
                    lastCharged: members.map { $0.date }.max() ?? latest.date,
                    category: mostCommon(members.map { $0.category }) ?? latest.category,
                    normalizedMerchantKey: latest.normalizedKey
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
