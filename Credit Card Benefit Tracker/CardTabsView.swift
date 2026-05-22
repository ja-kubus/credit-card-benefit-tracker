
//
//  CardTabsView.swift
//  Credit Card Benefit Tracker
//
//  Created by Jacob Michalik on 5/20/26.
//

import SwiftUI
import SwiftData

struct CardTabsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let card: UserCard
    var onDelete: (() -> Void)? = nil
    
    @State private var selectedTab: TabSelection = .earnings
    @State private var showStatementUpload = false
    @State private var scrollToTarget: String?
    
    enum TabSelection {
        case earnings
        case points
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // ── Tab selector ──
                HStack(spacing: 16) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = .earnings
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "percent")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Earning Rates")
                                .font(.subheadline.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selectedTab == .earnings ? Color.blue : Color.clear)
                        .foregroundStyle(selectedTab == .earnings ? .white : .secondary)
                        .cornerRadius(8)
                    }
                    
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = .points
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "chart.bar.fill")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Points & Statements")
                                .font(.subheadline.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selectedTab == .points ? Color.blue : Color.clear)
                        .foregroundStyle(selectedTab == .points ? .white : .secondary)
                        .cornerRadius(8)
                    }
                }
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground))
                
                Divider()
                
                // ── Content ──
                if selectedTab == .earnings {
                    EarningsTabContent(card: card, onDelete: onDelete, scrollToTarget: $scrollToTarget)
                } else {
                    PointsTabContent(card: card, showStatementUpload: $showStatementUpload)
                }
            }
            .navigationTitle("\(card.issuer) \(card.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button(role: .destructive) {
                        onDelete?()
                        dismiss()
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                }
            }
            .sheet(isPresented: $showStatementUpload) {
                StatementUploadSheet(userCards: [card]) {
                    // Callback on successful upload
                }
            }
        }
    }
}

// MARK: - Earnings Tab Content

struct EarningsTabContent: View {
    let card: UserCard
    var onDelete: (() -> Void)? = nil
    @Binding var scrollToTarget: String?
    
    private var catalog: CatalogCard? {
        CreditCardCatalog.all.first { $0.id == card.catalogCardID }
    }
    
    private var benefitsByPeriod: [(period: BenefitPeriod, benefits: [(CatalogBenefit, BenefitCompletion?)])] {
        guard let catalog else { return [] }
        return BenefitPeriod.allCases.compactMap { period in
            let periodBenefits = catalog.benefits.filter { $0.period == period }
            guard !periodBenefits.isEmpty else { return nil }
            let pairs: [(CatalogBenefit, BenefitCompletion?)] = periodBenefits.map { benefit in
                let comp = card.completions.first {
                    $0.benefitName == benefit.name && $0.benefitPeriod == period
                }
                return (benefit, comp)
            }
            return (period: period, benefits: pairs)
        }
    }
    
    private var totalAnnualValue: Double {
        guard let catalog else { return 0 }
        return catalog.benefits.reduce(0) { sum, b in
            let multiplier: Double
            switch b.period {
            case .monthly:      multiplier = 12
            case .quarterly:    multiplier = 4
            case .semiAnnually: multiplier = 2
            case .annually:     multiplier = 1
            }
            return sum + b.dollarAmount * multiplier
        }
    }
    
    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(spacing: 24) {
                    // ── Stats Row ─────────────────────────────────────────
                    HStack(spacing: 12) {
                        statTile(
                            label: "Annual Fee",
                            value: card.annualFee == 0
                                ? "No Fee"
                                : card.annualFee.formatted(.currency(code: "USD").precision(.fractionLength(0))),
                            icon: "dollarsign.circle.fill",
                            color: card.annualFee == 0 ? .green : .orange
                        )
                        
                        // Benefits tile - tappable to scroll
                        Button {
                            scrollToTarget = "benefits"
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    scrollProxy.scrollTo("benefits", anchor: .top)
                                }
                            }
                        } label: {
                            statTile(
                                label: "Benefits",
                                value: "\(catalog?.benefits.count ?? 0)",
                                icon: "checkmark.seal.fill",
                                color: .pink
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        statTile(
                            label: "Annual Value",
                            value: totalAnnualValue == 0
                                ? "—"
                                : totalAnnualValue.formatted(.currency(code: "USD").precision(.fractionLength(0))),
                            icon: "gift.fill",
                            color: .blue
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    // ── Earning Rates ──
                    earningSection
                        .padding(.horizontal, 20)
                    
                    if benefitsByPeriod.isEmpty {
                        noBenefitsPlaceholder
                    } else {
                        // ── Benefits by Period ────────────────────────
                        VStack(spacing: 16) {
                            ForEach(benefitsByPeriod, id: \.period) { group in
                                benefitSection(period: group.period, items: group.benefits)
                            }
                        }
                        .padding(.horizontal, 20)
                        .id("benefits")
                    }
                    
                    Spacer().frame(height: 20)
                }
            }
        }
    }
    
    private var earningSection: some View {
        let highlights = catalog.map { CreditCardCatalog.earningHighlights(for: $0) } ?? []

        return VStack(alignment: .leading, spacing: 10) {
            Label("Earning Rates", systemImage: "percent")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 4)

            VStack(alignment: .leading, spacing: 8) {
                if highlights.isEmpty {
                    Text("No recurring points multiplier or cashback rate listed for this card.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                } else {
                    ForEach(Array(highlights.enumerated()), id: \.offset) { index, highlight in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 7))
                                .foregroundStyle(.secondary)
                                .padding(.top, 7)
                            Text(highlight)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 2)

                        if index < highlights.count - 1 {
                            Divider().padding(.leading, 38)
                        }
                    }
                    .padding(.vertical, 12)
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
    
    private var noBenefitsPlaceholder: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.seal")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("No tracked benefits for this card.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 40)
    }
    
    private func statTile(label: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text(value)
                .font(.subheadline.weight(.bold))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func benefitSection(period: BenefitPeriod, items: [(CatalogBenefit, BenefitCompletion?)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(period.rawValue, systemImage: periodIcon(period))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(periodColor(period))
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, pair in
                    let (benefit, completion) = pair
                    DetailBenefitRow(benefit: benefit, completion: completion)

                    if index < items.count - 1 {
                        Divider().padding(.leading, 56)
                    }
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
    
    private func periodIcon(_ period: BenefitPeriod) -> String {
        switch period {
        case .monthly:      return "calendar"
        case .quarterly:    return "calendar.badge.clock"
        case .semiAnnually: return "calendar.badge.checkmark"
        case .annually:     return "star.circle"
        }
    }

    private func periodColor(_ period: BenefitPeriod) -> Color {
        switch period {
        case .monthly:      return .blue
        case .quarterly:    return .orange
        case .semiAnnually: return .purple
        case .annually:     return .green
        }
    }
}

// MARK: - Points Tab Content

struct PointsTabContent: View {
    let card: UserCard
    @Binding var showStatementUpload: Bool
    @State private var isPresentedDummy = true
    
    var body: some View {
        PointsBreakdownView(card: card, isPresented: $isPresentedDummy, showStatementUploadButton: false)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: UserCard.self, BenefitCompletion.self, Statement.self, StatementRow.self, configurations: config)
    let card = UserCard(from: CreditCardCatalog.all[0])
    container.mainContext.insert(card)
    for benefit in CreditCardCatalog.all[0].benefits {
        let c = BenefitCompletion(cardID: card.catalogCardID, benefit: benefit)
        container.mainContext.insert(c)
        card.completions.append(c)
    }
    return CardTabsView(card: card)
        .modelContainer(container)
}
