//
//  DashboardView.swift
//  Credit Card Benefit Tracker
//
//  Created by Jacob Michalik on 4/20/26.
//

import SwiftUI
import SwiftData

struct DashboardView: View {
    enum DashboardTab: String, CaseIterable {
        case overview = "Overview"
        case benefits = "Benefits"
        case spending = "Spending"
    }

    @State private var selectedTab: DashboardTab = .benefits

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("View", selection: $selectedTab) {
                    ForEach(DashboardTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.systemGroupedBackground))

                switch selectedTab {
                case .overview:
                    PortfolioOverviewView()
                        .background(Color(.systemGroupedBackground))
                case .benefits:
                    BenefitsView()
                case .spending:
                    SpendingBreakdownView()
                        .background(Color(.systemGroupedBackground))
                }
            }
            .navigationTitle("Value")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Portfolio Overview

struct PortfolioOverviewView: View {
    @Query(sort: \UserCard.dateAdded) private var userCards: [UserCard]

    @State private var overviewPeriod: BenefitPeriod = .monthly
    @State private var overviewDetailCard: UserCard? = nil
    @State private var includeBenefitsUsage = true
    @State private var includePointsUsage = true
    @State private var hideNoFeeCards = false

    /// Cards shown in the Overview; no-fee cards are where there's no fee to recoup.
    private var displayedCards: [UserCard] {
        hideNoFeeCards ? userCards.filter { $0.annualFee > 0 } : userCards
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // MARK: Summary header
                let totalFees = userCards.reduce(0.0) { $0 + $1.annualFee }
                let totalPotential = userCards.reduce(0.0) { $0 + annualizedBenefitValue(for: $1) }
                let netValue = totalPotential - totalFees

                VStack(spacing: 12) {
                    Text("Portfolio Overview")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 0) {
                        portfolioStat(label: "Annual Fees", value: totalFees, color: .red)
                        Divider().frame(height: 40)
                        portfolioStat(label: "Potential Value", value: totalPotential, color: .appGiraffe)
                        Divider().frame(height: 40)
                        portfolioStat(label: "Net Value", value: netValue, color: netValue >= 0 ? .appLeaf : .red)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                }
                .padding()
                .background(Color(.systemGroupedBackground))
                .cornerRadius(16)
                .padding(.horizontal)

                // MARK: Benefit-period selector
                VStack(alignment: .leading, spacing: 6) {
                    Text("Benefit period")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Picker("Benefit period", selection: $overviewPeriod) {
                        ForEach(BenefitPeriod.allCases, id: \.self) { period in
                            Text(period.rawValue).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text("Tap a card to see the benefits that make up its \(periodLabel(overviewPeriod)) value.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                // MARK: Recoup contributors toggle row
                HStack(spacing: 16) {
                    recoupToggle(title: "Benefits Usage", isOn: includeBenefitsUsage) {
                        includeBenefitsUsage.toggle()
                    }
                    recoupToggle(title: "Points from Spend", isOn: includePointsUsage) {
                        includePointsUsage.toggle()
                    }
                    Spacer()
                }
                .padding(.horizontal)

                // MARK: Hide no-fee cards toggle
                HStack {
                    recoupToggle(title: "Hide no-fee cards", isOn: hideNoFeeCards) {
                        hideNoFeeCards.toggle()
                    }
                    Spacer()
                }
                .padding(.horizontal)

                // MARK: Per-card rows
                VStack(spacing: 12) {
                    if displayedCards.isEmpty {
                        Text(hideNoFeeCards ? "No annual-fee cards in your wallet." : "No cards yet.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    ForEach(displayedCards) { card in
                        let available = periodAvailable(for: card, period: overviewPeriod)
                        let claimedPeriod = periodClaimed(for: card, period: overviewPeriod)
                        // Fee recoup uses annual value captured (benefits used + points + prior).
                        // Points are measured over the card's real fee year (from the
                        // fee anniversary), so a mid-year-opened card is judged fairly.
                        let pointsValue = PointsValuer.dollarValue(for: card, since: card.currentFeeYearStart)
                        // Full fee-year benefit usage = value banked from periods that
                        // already reset this fee year + value used in the current period.
                        let feeYearBenefits = card.feeYearBenefitUsage + claimedThisCycle(for: card)
                        let benefitsPart = includeBenefitsUsage ? feeYearBenefits : 0
                        let pointsPart = includePointsUsage ? pointsValue : 0
                        let contribution = benefitsPart + pointsPart + card.manualClaimedValue

                        Button {
                            overviewDetailCard = card
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(card.name)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.primary)
                                        Text(card.issuer)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        if let feeDate = card.feeAnniversaryDate {
                                            Text("\(card.annualFee > 0 ? "Fee date" : "Opened"): \(feeDate.formatted(.dateTime.month().day().year()))")
                                                .font(.caption2)
                                                .foregroundStyle(.tertiary)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }

                                // Selected-period benefit usage
                                if available > 0 {
                                    let periodDone = claimedPeriod >= available
                                    HStack {
                                        Text("\(periodAdjective(overviewPeriod)) benefits")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(Color.appGiraffe)
                                        Spacer()
                                        Text("$\(Int(claimedPeriod)) / $\(Int(available)) used \(periodLabel(overviewPeriod))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    ProgressView(value: min(claimedPeriod, available), total: max(available, 0.01))
                                        .tint(periodDone ? Color.appLeaf : Color.appCoral)
                                } else {
                                    Text("No \(periodAdjective(overviewPeriod).lowercased()) benefits on this card")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Divider()

                                // Annual fee recoup — clearly separate & annual
                                HStack {
                                    Text(card.annualFee == 0 ? "No annual fee" : "Annual fee $\(Int(card.annualFee))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    if card.annualFee == 0 {
                                        Text("—")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                    } else if contribution >= card.annualFee {
                                        Label("Fee recouped", systemImage: "checkmark.circle.fill")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(Color.appLeaf)
                                    } else {
                                        Text("$\(Int(card.annualFee - contribution)) to recoup")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.orange)
                                    }
                                }

                                // Contributor breakdown so the recoup math is explicit —
                                // no mental "fee − benefits = points" needed.
                                if card.annualFee > 0 {
                                    VStack(spacing: 3) {
                                        if includeBenefitsUsage {
                                            contributorRow(label: "Benefits used this year", value: benefitsPart, icon: "checkmark.seal.fill", color: .appLeaf)
                                        }
                                        if includePointsUsage {
                                            contributorRow(label: "Earned from points", value: pointsPart, icon: "sparkles", color: .appGiraffe)
                                        }
                                        if card.manualClaimedValue > 0 {
                                            contributorRow(label: "Prior history", value: card.manualClaimedValue, icon: "clock.fill", color: .secondary)
                                        }
                                    }
                                }
                            }
                            .padding()
                            .background(Color(.secondarySystemGroupedBackground))
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)

                Spacer(minLength: 32)
            }
            .padding(.top, 12)
        }
        .sheet(item: $overviewDetailCard) { card in
            OverviewCardDetailSheet(
                card: card,
                period: overviewPeriod,
                periodLabel: periodLabel(overviewPeriod)
            )
        }
    }

    // MARK: - Helpers

    private func annualizedBenefitValue(for card: UserCard) -> Double {
        guard let catalogCard = CreditCardCatalog.all.first(where: { $0.id == card.catalogCardID }) else {
            return 0
        }
        return catalogCard.benefits.reduce(0.0) { total, benefit in
            let multiplier: Double = {
                switch benefit.period {
                case .monthly:      return 12
                case .quarterly:    return 4
                case .semiAnnually: return 2
                case .annually:     return 1
                }
            }()
            return total + benefit.dollarAmount * multiplier
        }
    }

    /// Value available in the CURRENT cycle: plain sum of each benefit's dollar amount
    /// across all benefit periods (not annualized).
    private func currentCycleValue(for card: UserCard) -> Double {
        guard let catalogCard = CreditCardCatalog.all.first(where: { $0.id == card.catalogCardID }) else {
            return 0
        }
        return catalogCard.benefits.reduce(0.0) { $0 + $1.dollarAmount }
    }

    private func claimedThisCycle(for card: UserCard) -> Double {
        card.completions.reduce(0.0) { total, completion in
            if completion.isCompleted {
                return total + completion.dollarAmount
            }
            let partial = completion.partialUsage.trimmingCharacters(in: .whitespaces)
            if !partial.isEmpty {
                return total + (Double(partial) ?? 0)
            }
            return total
        }
    }

    /// Catalog benefits for a card in a specific period, paired with their completion (if any).
    private func periodBenefits(for card: UserCard, period: BenefitPeriod) -> [(benefit: CatalogBenefit, completion: BenefitCompletion?)] {
        guard let catalogCard = CreditCardCatalog.all.first(where: { $0.id == card.catalogCardID }) else { return [] }
        return catalogCard.benefits
            .filter { $0.period == period && $0.dollarAmount > 0 }
            .map { benefit in
                let comp = card.completions.first { $0.benefitName == benefit.name && $0.benefitPeriod == period }
                return (benefit, comp)
            }
    }

    /// Total dollar value available in one period for a card.
    private func periodAvailable(for card: UserCard, period: BenefitPeriod) -> Double {
        periodBenefits(for: card, period: period).reduce(0.0) { $0 + $1.benefit.dollarAmount }
    }

    /// Dollar value already used (completed or partial) in one period for a card.
    private func periodClaimed(for card: UserCard, period: BenefitPeriod) -> Double {
        periodBenefits(for: card, period: period).reduce(0.0) { total, pair in
            guard let comp = pair.completion else { return total }
            if comp.isCompleted { return total + pair.benefit.dollarAmount }
            let partial = comp.partialUsage.trimmingCharacters(in: .whitespaces)
            return total + (Double(partial) ?? 0)
        }
    }

    /// How to phrase a period's cadence in the UI.
    private func periodLabel(_ period: BenefitPeriod) -> String {
        switch period {
        case .monthly:      return "this month"
        case .quarterly:    return "this quarter"
        case .semiAnnually: return "this half-year"
        case .annually:     return "this year"
        }
    }

    /// Adjective form for a "<X> benefits" heading.
    private func periodAdjective(_ period: BenefitPeriod) -> String {
        switch period {
        case .monthly:      return "Monthly"
        case .quarterly:    return "Quarterly"
        case .semiAnnually: return "Semi-annual"
        case .annually:     return "Annual"
        }
    }

    /// One line in the fee-recoup contributor breakdown.
    private func contributorRow(label: String, value: Double, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            Text("$\(Int(value))")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(color)
        }
    }

    /// Compact SF-Symbol checkbox used to toggle recoup contributors.
    private func recoupToggle(title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: isOn ? "checkmark.square.fill" : "square")
                    .foregroundStyle(isOn ? Color.appCoral : Color.secondary)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.primary)
            }
        }
        .buttonStyle(.plain)
    }

    /// Builds a caption like "Benefits $120 + Points $85 + Prior $50" from active,
    /// non-zero contributors.
    private func recoupBreakdown(benefits: Double?, points: Double?, prior: Double) -> String {
        var parts: [String] = []
        if let benefits, benefits > 0 { parts.append("Benefits $\(Int(benefits))") }
        if let points, points > 0 { parts.append("Points $\(Int(points))") }
        if prior > 0 { parts.append("Prior $\(Int(prior))") }
        return parts.joined(separator: " + ")
    }

    private func portfolioStat(label: String, value: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text("$\(Int(abs(value)))")
                .font(.headline.weight(.bold))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }
}

// MARK: - Spending Breakdown

struct SpendingBreakdownView: View {
    @Query(sort: \UserCard.dateAdded) private var userCards: [UserCard]

    // User-selectable spending date range (defaults to the last ~3 months → today)
    @State private var spendingStartDate: Date = Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()
    @State private var spendingEndDate: Date = Date()
    // Selected cards to aggregate. Empty == all cards.
    @State private var spendingSelectedCards: Set<PersistentIdentifier> = []
    @State private var selectedSpendingCategory: String? = nil

    /// Inclusive [start-of-day(start), end-of-day(end)] bounds for the spending filter.
    private var spendingDateBounds: (start: Date, end: Date) {
        let cal = Calendar.current
        let start = cal.startOfDay(for: spendingStartDate)
        let endDay = cal.startOfDay(for: spendingEndDate)
        let end = cal.date(byAdding: .init(day: 1, second: -1), to: endDay) ?? spendingEndDate
        return (start, end)
    }

    /// One category's aggregated spend across all cards/statements in range.
    private struct SpendingSlice: Identifiable {
        let category: String
        let amount: Double
        let count: Int
        var id: String { category }
    }

    /// Aggregates all statement rows across every card into per-category totals,
    /// filtered by the selected date range.
    private var spendingSlices: [SpendingSlice] {
        let bounds = spendingDateBounds
        var totals: [String: (amount: Double, count: Int)] = [:]
        for card in userCards {
            if !spendingSelectedCards.isEmpty && !spendingSelectedCards.contains(card.persistentModelID) { continue }
            for statement in card.statements {
                for row in statement.rows {
                    if row.transactionDate < bounds.start || row.transactionDate > bounds.end { continue }
                    let key = row.category.isEmpty ? "Other" : row.category
                    let entry = totals[key] ?? (0, 0)
                    totals[key] = (entry.amount + row.amount, entry.count + 1)
                }
            }
        }
        return totals
            .map { SpendingSlice(category: $0.key, amount: $0.value.amount, count: $0.value.count) }
            .sorted { $0.amount > $1.amount }
    }

    /// The individual statement rows for a single category, respecting the current
    /// date range and card filter. Sorted by date descending.
    private func spendingRows(for category: String) -> [StatementRow] {
        let bounds = spendingDateBounds
        var rows: [StatementRow] = []
        for card in userCards {
            if !spendingSelectedCards.isEmpty && !spendingSelectedCards.contains(card.persistentModelID) { continue }
            for statement in card.statements {
                for row in statement.rows {
                    if row.transactionDate < bounds.start || row.transactionDate > bounds.end { continue }
                    let key = row.category.isEmpty ? "Other" : row.category
                    if key == category { rows.append(row) }
                }
            }
        }
        return rows.sorted { $0.transactionDate > $1.transactionDate }
    }

    /// Maps each row (by id) to the card it came from and its source statement,
    /// so the detail sheet can label transactions by card and open their statement.
    private func spendingRowSources(for category: String) -> [PersistentIdentifier: SpendingRowSource] {
        let bounds = spendingDateBounds
        var map: [PersistentIdentifier: SpendingRowSource] = [:]
        for card in userCards {
            if !spendingSelectedCards.isEmpty && !spendingSelectedCards.contains(card.persistentModelID) { continue }
            for statement in card.statements {
                for row in statement.rows {
                    if row.transactionDate < bounds.start || row.transactionDate > bounds.end { continue }
                    let key = row.category.isEmpty ? "Other" : row.category
                    if key == category {
                        map[row.persistentModelID] = SpendingRowSource(
                            cardName: card.name,
                            color: Color(hex: card.accentColor),
                            statement: statement
                        )
                    }
                }
            }
        }
        return map
    }

    /// Stable color for a category, cycling through the theme palette.
    private func spendingColor(for category: String) -> Color {
        let palette: [Color] = [.appCoral, .appGiraffe, .appLeaf, .appBell, .appCoralDark,
                                Color(red: 0.42, green: 0.62, blue: 0.78),   // muted blue
                                Color(red: 0.62, green: 0.51, blue: 0.78),   // muted purple
                                Color(red: 0.85, green: 0.55, blue: 0.62)]   // dusty rose
        // Deterministic index from the category name.
        let hash = category.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return palette[hash % palette.count]
    }

    private func spendingCardChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.medium))
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.appCoral : Color(.secondarySystemGroupedBackground))
                .foregroundStyle(isSelected ? .white : Color.primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    var body: some View {
        let slices = spendingSlices
        let total = slices.reduce(0.0) { $0 + $1.amount }
        let txnCount = slices.reduce(0) { $0 + $1.count }

        return ScrollView {
            VStack(spacing: 16) {
                // Date range selector — tap either date to pick from a calendar
                VStack(spacing: 8) {
                    HStack {
                        Text("Date Range")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Button("Reset") {
                            // Set end first so the "From" picker's upper bound is
                            // today before we move the start date back.
                            spendingEndDate = Date()
                            spendingStartDate = Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()
                            spendingSelectedCards = []      // back to all cards
                            selectedSpendingCategory = nil
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.appCoral)
                    }
                    HStack(spacing: 12) {
                        DatePicker("From", selection: $spendingStartDate, in: ...spendingEndDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                        Image(systemName: "arrow.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        DatePicker("To", selection: $spendingEndDate, in: spendingStartDate...Date(), displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                        Spacer()
                    }
                    .tint(Color.appCoral)
                }
                .padding(.horizontal)
                .padding(.top, 8)

                // Per-card filter chips — multi-select. "All Cards" is the empty
                // state (aggregate everything); tapping individual cards adds them
                // up. Selecting individuals deselects "All Cards" and vice-versa.
                if userCards.count > 1 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            spendingCardChip(title: "All Cards", isSelected: spendingSelectedCards.isEmpty) {
                                spendingSelectedCards = []
                            }
                            ForEach(userCards) { card in
                                let id = card.persistentModelID
                                spendingCardChip(
                                    title: card.name,
                                    isSelected: spendingSelectedCards.contains(id)
                                ) {
                                    if spendingSelectedCards.contains(id) {
                                        spendingSelectedCards.remove(id)
                                    } else {
                                        spendingSelectedCards.insert(id)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                if slices.isEmpty {
                    ContentUnavailableView(
                        "No Spending Data",
                        systemImage: "chart.pie",
                        description: Text("Upload statements to see your spending broken down by category. Try a wider date range if you've already uploaded some.")
                    )
                    .padding(.top, 40)
                } else {
                    // Summary header
                    VStack(spacing: 8) {
                        Text("Total Spend")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        HStack(alignment: .firstTextBaseline) {
                            Text(total, format: .currency(code: "USD").precision(.fractionLength(0)))
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                            Spacer()
                            Text("\(txnCount) transaction\(txnCount == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        // Stacked proportion bar
                        GeometryReader { geo in
                            HStack(spacing: 1) {
                                ForEach(slices) { slice in
                                    spendingColor(for: slice.category)
                                        .frame(width: max(1, geo.size.width * (slice.amount / max(total, 0.01))))
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        .frame(height: 12)
                        .padding(.top, 4)
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(16)
                    .padding(.horizontal)

                    // Per-category rows
                    VStack(spacing: 10) {
                        ForEach(slices) { slice in
                            let pct = total > 0 ? slice.amount / total : 0
                            Button {
                                selectedSpendingCategory = slice.category
                            } label: {
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(spendingColor(for: slice.category))
                                        .frame(width: 12, height: 12)
                                    VStack(alignment: .leading, spacing: 3) {
                                        HStack {
                                            Text(slice.category)
                                                .font(.subheadline.weight(.medium))
                                            Spacer()
                                            Text(slice.amount, format: .currency(code: "USD").precision(.fractionLength(0)))
                                                .font(.subheadline.weight(.semibold))
                                            Image(systemName: "chevron.right")
                                                .font(.caption2.weight(.semibold))
                                                .foregroundStyle(.tertiary)
                                        }
                                        GeometryReader { geo in
                                            ZStack(alignment: .leading) {
                                                Capsule().fill(Color(.tertiarySystemFill))
                                                Capsule()
                                                    .fill(spendingColor(for: slice.category))
                                                    .frame(width: max(2, geo.size.width * pct))
                                            }
                                        }
                                        .frame(height: 6)
                                        HStack {
                                            Text("\(Int(pct * 100))% of spend")
                                            Spacer()
                                            Text("\(slice.count) txn\(slice.count == 1 ? "" : "s")")
                                        }
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    }
                                }
                                .padding()
                                .background(Color(.secondarySystemGroupedBackground))
                                .cornerRadius(12)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }

                Spacer(minLength: 32)
            }
            .padding(.top, 8)
        }
        .sheet(item: Binding(
            get: { selectedSpendingCategory.map(IdentifiableString.init) },
            set: { selectedSpendingCategory = $0?.value }
        )) { holder in
            SpendingCategoryDetailSheet(
                category: holder.value,
                rows: spendingRows(for: holder.value),
                sources: spendingRowSources(for: holder.value)
            )
        }
    }
}

/// Where a spending transaction came from: its card (name + accent color) and
/// the statement it was imported/parsed from.
struct SpendingRowSource {
    let cardName: String
    let color: Color
    let statement: Statement
}

// MARK: - Spending Category Detail

/// Lightweight Identifiable wrapper so a plain String can drive `.sheet(item:)`.
private struct IdentifiableString: Identifiable {
    let value: String
    var id: String { value }
    init(_ value: String) { self.value = value }
}

/// Popup listing the transactions in a spending category, with sorting, an
/// option to pool similar merchants, and inline category editing.
struct SpendingCategoryDetailSheet: View {
    let category: String
    let sources: [PersistentIdentifier: SpendingRowSource]
    @State private var rows: [StatementRow]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var poolSimilar = false
    @State private var sortMode: SortMode = .newest
    @State private var editingRow: StatementRow?
    @State private var selectedStatement: Statement?

    init(category: String, rows: [StatementRow], sources: [PersistentIdentifier: SpendingRowSource] = [:]) {
        self.category = category
        self.sources = sources
        _rows = State(initialValue: rows)
    }

    enum SortMode: String, CaseIterable, Identifiable {
        case newest = "Newest"
        case priceHigh = "Price: High → Low"
        case priceLow = "Price: Low → High"
        var id: String { rawValue }
    }

    private static let allCategories = [
        "Restaurants", "Supermarkets", "Flights", "Hotels", "Car Rentals", "Transit",
        "Streaming", "Fitness", "Entertainment", "Drugstore", "Gas Stations", "Travel",
        "Dining", "Apple", "Apple Pay", "Apple & Rotating", "Physical Card", "Other"
    ].sorted()

    private var total: Double { rows.reduce(0.0) { $0 + $1.amount } }

    private var sortedRows: [StatementRow] {
        switch sortMode {
        case .newest:    return rows.sorted { $0.transactionDate > $1.transactionDate }
        case .priceHigh: return rows.sorted { $0.amount > $1.amount }
        case .priceLow:  return rows.sorted { $0.amount < $1.amount }
        }
    }

    struct Pool: Identifiable {
        let id = UUID()
        let merchant: String
        let total: Double
        let count: Int
        let latest: Date
    }

    private var pools: [Pool] {
        var groups: [String: [StatementRow]] = [:]
        for row in rows { groups[Self.normalizedMerchant(row.transactionDescription), default: []].append(row) }
        var result = groups.values.map { rs -> Pool in
            Pool(merchant: Self.displayMerchant(rs),
                 total: rs.reduce(0) { $0 + $1.amount },
                 count: rs.count,
                 latest: rs.map { $0.transactionDate }.max() ?? .distantPast)
        }
        switch sortMode {
        case .newest:    result.sort { $0.latest > $1.latest }
        case .priceHigh: result.sort { $0.total > $1.total }
        case .priceLow:  result.sort { $0.total < $1.total }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text("Total")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(total, format: .currency(code: "USD"))
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color.appLeaf)
                    }
                    Text("\(rows.count) transaction\(rows.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Toggle("Pool similar transactions", isOn: $poolSimilar)
                        .font(.subheadline)
                        .tint(Color.appCoral)
                }

                Section {
                    if poolSimilar {
                        ForEach(pools) { pool in
                            HStack(alignment: .firstTextBaseline) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(pool.merchant.isEmpty ? category : pool.merchant)
                                        .font(.subheadline.weight(.medium))
                                        .lineLimit(2)
                                    Text("\(pool.count) transaction\(pool.count == 1 ? "" : "s")")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(pool.total, format: .currency(code: "USD"))
                                    .font(.subheadline.weight(.semibold))
                            }
                            .padding(.vertical, 2)
                        }
                    } else {
                        ForEach(sortedRows) { row in
                            let src = sources[row.persistentModelID]
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                // LEFT (large tap area): open the source statement.
                                Button {
                                    if let src { selectedStatement = src.statement }
                                } label: {
                                    HStack(alignment: .firstTextBaseline) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(row.transactionDescription.isEmpty ? category : row.transactionDescription)
                                                .font(.subheadline)
                                                .foregroundStyle(.primary)
                                                .lineLimit(2)
                                            Text(row.transactionDate, format: .dateTime.year().month().day())
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            if let src {
                                                HStack(spacing: 4) {
                                                    Image(systemName: "creditcard.fill")
                                                        .font(.system(size: 10))
                                                    Text(src.cardName)
                                                        .font(.caption.weight(.medium))
                                                    Image(systemName: "chevron.right")
                                                        .font(.system(size: 8, weight: .semibold))
                                                }
                                                .foregroundStyle(src.color)
                                            }
                                        }
                                        Spacer(minLength: 8)
                                        Text(row.amount, format: .currency(code: "USD"))
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.primary)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .disabled(src == nil)

                                // RIGHT (dedicated control): change the category.
                                Button {
                                    editingRow = row
                                } label: {
                                    Image(systemName: "pencil.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(Color.appCoral)
                                        .padding(.vertical, 4)
                                        .padding(.leading, 4)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                } footer: {
                    if !poolSimilar {
                        Text("Tap a transaction to open its statement, or tap the pencil to change its category.")
                    }
                }
            }
            .navigationTitle(category)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Picker("Sort", selection: $sortMode) {
                            ForEach(SortMode.allCases) { Text($0.rawValue).tag($0) }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                            .foregroundStyle(Color.appCoral)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.appCoral)
                }
            }
            .sheet(item: $editingRow) { row in
                CategoryPickerSheet(
                    transaction: row,
                    availableCategories: Self.allCategories,
                    onSelect: { newCategory in
                        row.category = newCategory
                        try? modelContext.save()
                        // If it no longer belongs to this category view, drop it.
                        let key = newCategory.isEmpty ? "Other" : newCategory
                        if key != category {
                            rows.removeAll { $0.id == row.id }
                        }
                        editingRow = nil
                    },
                    onDismiss: { editingRow = nil }
                )
            }
            .sheet(isPresented: Binding(
                get: { selectedStatement != nil },
                set: { if !$0 { selectedStatement = nil } }
            )) {
                if let statement = selectedStatement {
                    StatementDetailPopup(statement: statement, modelContext: modelContext) {
                        selectedStatement = nil
                    }
                }
            }
        }
    }

    /// Normalize a merchant so repeat purchases pool together (strip store/ref
    /// numbers and punctuation).
    private static func normalizedMerchant(_ description: String) -> String {
        var t = description.lowercased()
        t = t.replacingOccurrences(of: "#\\s*\\d+", with: " ", options: .regularExpression)
        t = t.replacingOccurrences(of: "\\b\\d{3,}\\b", with: " ", options: .regularExpression)
        t = t.replacingOccurrences(of: "[*#.,/\\\\-]", with: " ", options: .regularExpression)
        t = t.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return t.trimmingCharacters(in: .whitespaces)
    }

    /// Most common raw description in a pooled group, for display.
    private static func displayMerchant(_ rows: [StatementRow]) -> String {
        var counts: [String: Int] = [:]
        for r in rows { counts[r.transactionDescription, default: 0] += 1 }
        return counts.max { $0.value < $1.value }?.key ?? (rows.first?.transactionDescription ?? "")
    }
}

/// Popup listing the benefits that make up a card's value for one period,
/// with each benefit's dollar amount and used/unused status. Benefits can be
/// marked used here; when marking, the user chooses whether it's new usage
/// (adds value) or a retroactive fix already counted in prior history (no
/// double-count — the amount moves out of prior history into benefits used).
struct OverviewCardDetailSheet: View {
    let card: UserCard
    let period: BenefitPeriod
    let periodLabel: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    // Bump to force a recompute after mutating a completion.
    @State private var refreshToken = UUID()
    // The benefit awaiting the "new vs retroactive" choice.
    @State private var pendingBenefit: CatalogBenefit? = nil

    private var items: [(benefit: CatalogBenefit, completion: BenefitCompletion?)] {
        _ = refreshToken
        guard let catalogCard = CreditCardCatalog.all.first(where: { $0.id == card.catalogCardID }) else { return [] }
        return catalogCard.benefits
            .filter { $0.period == period && $0.dollarAmount > 0 }
            .map { benefit in
                let comp = card.completions.first { $0.benefitName == benefit.name && $0.benefitPeriod == period }
                return (benefit, comp)
            }
    }

    private var available: Double { items.reduce(0.0) { $0 + $1.benefit.dollarAmount } }
    private var used: Double {
        items.reduce(0.0) { total, pair in
            guard let comp = pair.completion else { return total }
            if comp.isCompleted { return total + pair.benefit.dollarAmount }
            let partial = comp.partialUsage.trimmingCharacters(in: .whitespaces)
            return total + (Double(partial) ?? 0)
        }
    }

    private func status(for pair: (benefit: CatalogBenefit, completion: BenefitCompletion?)) -> (text: String, color: Color, icon: String) {
        guard let comp = pair.completion else {
            return ("Not used — tap to mark", .secondary, "circle")
        }
        if comp.isCompleted {
            return ("Used — tap to undo", .appLeaf, "checkmark.circle.fill")
        }
        let partial = Double(comp.partialUsage.trimmingCharacters(in: .whitespaces)) ?? 0
        if partial > 0 {
            return ("$\(Int(partial)) of $\(Int(pair.benefit.dollarAmount)) used — tap to mark full", .appGiraffe, "circle.lefthalf.filled")
        }
        return ("Not used — tap to mark", .secondary, "circle")
    }

    /// Ensure a completion record exists for a catalog benefit, creating one if needed.
    private func completion(for benefit: CatalogBenefit) -> BenefitCompletion {
        if let existing = card.completions.first(where: { $0.benefitName == benefit.name && $0.benefitPeriod == period }) {
            return existing
        }
        let created = BenefitCompletion(cardID: card.catalogCardID, benefit: benefit)
        modelContext.insert(created)
        card.completions.append(created)
        return created
    }

    private func handleTap(_ pair: (benefit: CatalogBenefit, completion: BenefitCompletion?)) {
        if let comp = pair.completion, comp.isCompleted {
            // Undo
            comp.isCompleted = false
            comp.partialUsage = ""
            save()
        } else {
            // Ask new-usage vs retroactive before marking
            pendingBenefit = pair.benefit
        }
    }

    private func markUsed(_ benefit: CatalogBenefit, retroactive: Bool) {
        let comp = completion(for: benefit)
        comp.isCompleted = true
        comp.partialUsage = ""
        if retroactive {
            // Value was already logged in prior history — move it out so the
            // fee-recoup total doesn't count it twice.
            card.manualClaimedValue = max(0, card.manualClaimedValue - benefit.dollarAmount)
        }
        save()
    }

    private func save() {
        try? modelContext.save()
        refreshToken = UUID()
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text("\(period.rawValue) value")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("$\(Int(used)) / $\(Int(available))")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(used >= available && available > 0 ? Color.appLeaf : Color.primary)
                    }
                    Text("Used \(periodLabel)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    if items.isEmpty {
                        Text("No \(period.rawValue.lowercased()) benefits on this card.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(items, id: \.benefit.id) { pair in
                            let s = status(for: pair)
                            Button {
                                handleTap(pair)
                            } label: {
                                HStack(alignment: .firstTextBaseline) {
                                    Image(systemName: s.icon)
                                        .foregroundStyle(s.color)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(pair.benefit.name)
                                            .font(.subheadline)
                                            .foregroundStyle(.primary)
                                        Text(s.text)
                                            .font(.caption)
                                            .foregroundStyle(s.color)
                                    }
                                    Spacer()
                                    Text(pair.benefit.dollarAmount, format: .currency(code: "USD").precision(.fractionLength(0)))
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                }
                                .padding(.vertical, 2)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    Text("Benefits")
                } footer: {
                    Text("Tap a benefit to mark it used. You'll be asked whether it's new usage or a value you already entered as prior history.")
                }
            }
            .navigationTitle(card.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.appCoral)
                }
            }
            .confirmationDialog(
                pendingBenefit.map { "Mark \"\($0.name)\" as used?" } ?? "Mark as used?",
                isPresented: Binding(get: { pendingBenefit != nil }, set: { if !$0 { pendingBenefit = nil } }),
                titleVisibility: .visible
            ) {
                if let benefit = pendingBenefit {
                    Button("New usage (adds $\(Int(benefit.dollarAmount)) value)") {
                        markUsed(benefit, retroactive: false)
                        pendingBenefit = nil
                    }
                    Button("Already in prior history (retroactive fix)") {
                        markUsed(benefit, retroactive: true)
                        pendingBenefit = nil
                    }
                    Button("Cancel", role: .cancel) { pendingBenefit = nil }
                }
            } message: {
                Text("Choose \"New usage\" if you just used this benefit. Choose \"Already in prior history\" if you previously entered this value as prior history — it won't be counted twice.")
            }
        }
    }
}
