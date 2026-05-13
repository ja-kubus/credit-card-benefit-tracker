//
//  CardDetailView.swift
//  Credit Card Benefit Tracker
//
//  Created by Jacob Michalik on 4/20/26.
//

import SwiftUI
import SwiftData

struct CardDetailView: View {
    let card: UserCard
    var onDelete: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var showDeleteAlert = false

    // Pull fresh completions for this card
    private var catalog: CatalogCard? {
        CreditCardCatalog.all.first { $0.id == card.catalogCardID }
    }

    // Group benefits by period
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
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // ── Card Hero ──────────────────────────────────────────
                    cardHero
                        .padding(.horizontal, 32)
                        .padding(.top, 24)
                        .padding(.bottom, 20)

                    // ── Stats Row ─────────────────────────────────────────
                    statsRow
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)

                    earningSection
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)

                    if benefitsByPeriod.isEmpty {
                        noBenefitsPlaceholder
                    } else {
                        // ── Benefits by Period ────────────────────────────
                        VStack(spacing: 16) {
                            ForEach(benefitsByPeriod, id: \.period) { group in
                                benefitSection(period: group.period, items: group.benefits)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)
                    }
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
                        showDeleteAlert = true
                    } label: {
                        Label("Remove Card", systemImage: "trash")
                    }
                }
            }
            .alert("Remove Card", isPresented: $showDeleteAlert) {
                Button("Remove", role: .destructive) {
                    dismiss()
                    onDelete?()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Remove \(card.issuer) \(card.name) from your wallet? This cannot be undone.")
            }
        }
    }

    // MARK: - Sub-views

    private var cardHero: some View {
        Group {
            if UIImage(named: card.imageName) != nil {
                Image(card.imageName)
                    .resizable()
                    .aspectRatio(1.586, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: Color(hex: card.accentColor).opacity(0.45), radius: 16, x: 0, y: 8)
            } else {
                gradientHeroCard
            }
        }
    }

    private var gradientHeroCard: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: card.accentColor), Color(hex: card.accentColor).opacity(0.55)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .aspectRatio(1.586, contentMode: .fit)
                .shadow(color: Color(hex: card.accentColor).opacity(0.45), radius: 16, x: 0, y: 8)

            RoundedRectangle(cornerRadius: 20)
                .fill(LinearGradient(colors: [.white.opacity(0.2), .clear], startPoint: .topLeading, endPoint: .center))

            VStack(alignment: .leading, spacing: 4) {
                Text(card.name)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                Text(card.issuer)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(18)
        }
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            statTile(
                label: "Annual Fee",
                value: card.annualFee == 0
                    ? "No Fee"
                    : card.annualFee.formatted(.currency(code: "USD").precision(.fractionLength(0))),
                icon: "dollarsign.circle.fill",
                color: card.annualFee == 0 ? .green : .orange
            )
            statTile(
                label: "Annual Value",
                value: totalAnnualValue == 0
                    ? "—"
                    : totalAnnualValue.formatted(.currency(code: "USD").precision(.fractionLength(0))),
                icon: "gift.fill",
                color: .blue
            )
            statTile(
                label: "Benefits",
                value: "\(catalog?.benefits.count ?? 0)",
                icon: "checkmark.seal.fill",
                color: .purple
            )
        }
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

    private func benefitSection(period: BenefitPeriod, items: [(CatalogBenefit, BenefitCompletion?)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Section header
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

// MARK: - Benefit Row

struct DetailBenefitRow: View {
    let benefit: CatalogBenefit
    let completion: BenefitCompletion?

    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                // Completion toggle
                if let completion {
                    Button {
                        completion.isCompleted.toggle()
                    } label: {
                        Image(systemName: completion.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(completion.isCompleted ? .green : Color(.tertiaryLabel))
                    }
                    .buttonStyle(.plain)
                } else {
                    Image(systemName: "circle")
                        .font(.title3)
                        .foregroundStyle(Color(.quaternaryLabel))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(benefit.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(completion?.isCompleted == true ? .secondary : .primary)
                        .strikethrough(completion?.isCompleted == true)

                    Text(benefit.dollarAmount.formatted(.currency(code: "USD").precision(.fractionLength(0))) + " / \(benefit.period.rawValue.lowercased())")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    withAnimation(.spring(duration: 0.25)) { expanded.toggle() }
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            if expanded {
                Text(benefit.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: UserCard.self, BenefitCompletion.self, configurations: config)
    let card = UserCard(from: CreditCardCatalog.all[0])
    container.mainContext.insert(card)
    for benefit in CreditCardCatalog.all[0].benefits {
        let c = BenefitCompletion(cardID: card.catalogCardID, benefit: benefit)
        container.mainContext.insert(c)
        card.completions.append(c)
    }
    return CardDetailView(card: card)
        .modelContainer(container)
}
