//
//  BenefitsView.swift
//  Credit Card Benefit Tracker
//
//  Created by Jacob Michalik on 4/20/26.
//

import SwiftUI
import SwiftData

struct BenefitsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var userCards: [UserCard]
    @Query private var completions: [BenefitCompletion]

    @State private var selectedPeriod: BenefitPeriod = .monthly

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                periodPicker
                    .padding(.horizontal)
                    .padding(.top, 8)

                Divider().padding(.top, 8)

                benefitsList
            }
            .navigationTitle("Benefits")
            .onAppear { resetExpiredCompletions() }
        }
    }

    // MARK: - Period Picker

    private var periodPicker: some View {
        Picker("Period", selection: $selectedPeriod) {
            ForEach(BenefitPeriod.allCases, id: \.self) { period in
                Text(period.rawValue).tag(period)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Benefits List

    private var benefitsList: some View {
        let items = benefitItems(for: selectedPeriod)
        return Group {
            if items.isEmpty {
                emptyBenefits
            } else {
                List {
                    ForEach(items, id: \.completion.id) { item in
                        BenefitRow(
                            cardName: item.cardName,
                            catalogBenefit: item.benefit,
                            completion: item.completion
                        )
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }

    private var emptyBenefits: some View {
        ContentUnavailableView(
            "No \(selectedPeriod.rawValue) Benefits",
            systemImage: "checkmark.seal",
            description: Text("Add cards with \(selectedPeriod.rawValue.lowercased()) benefits to see them here.")
        )
    }

    // MARK: - Data Helpers

    struct BenefitItem {
        let cardName: String
        let benefit: CatalogBenefit
        let completion: BenefitCompletion
    }

    private func benefitItems(for period: BenefitPeriod) -> [BenefitItem] {
        var result: [BenefitItem] = []
        for card in userCards {
            guard let catalog = CreditCardCatalog.all.first(where: { $0.id == card.catalogCardID }) else { continue }
            let periodBenefits = catalog.benefits.filter { $0.period == period }
            for benefit in periodBenefits {
                if let comp = card.completions.first(where: { $0.benefitName == benefit.name && $0.benefitPeriod == period }) {
                    result.append(BenefitItem(cardName: card.name, benefit: benefit, completion: comp))
                }
            }
        }
        return result.sorted { $0.cardName < $1.cardName }
    }

    private func resetExpiredCompletions() {
        for completion in completions {
            completion.resetIfNeeded()
        }
    }
}

// MARK: - Benefit Row

struct BenefitRow: View {
    let cardName: String
    let catalogBenefit: CatalogBenefit
    @Bindable var completion: BenefitCompletion

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Checkbox
            Button {
                completion.isCompleted.toggle()
            } label: {
                Image(systemName: completion.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(completion.isCompleted ? .green : .secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(catalogBenefit.name)
                        .font(.subheadline.weight(.semibold))
                        .strikethrough(completion.isCompleted, color: .secondary)
                    Spacer()
                    if catalogBenefit.dollarAmount > 0 {
                        Text(catalogBenefit.dollarAmount, format: .currency(code: "USD"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.green)
                    }
                }
                Text(cardName)
                    .font(.caption)
                    .foregroundStyle(.blue)
                Text(catalogBenefit.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption2)
                    Text("Resets \(completion.resetDate, style: .date)")
                        .font(.caption2)
                }
                .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    BenefitsView()
        .modelContainer(for: [UserCard.self, BenefitCompletion.self], inMemory: true)
}
