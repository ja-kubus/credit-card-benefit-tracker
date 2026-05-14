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
    @State private var expandedCategories: Set<BenefitCategory> = Set(BenefitCategory.allCases)

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
        let itemsByCategory = benefitItemsByCategory(for: selectedPeriod)
        let hasAnyBenefits = itemsByCategory.values.contains { !$0.isEmpty }
        
        return Group {
            if !hasAnyBenefits {
                emptyBenefits
            } else {
                List {
                    ForEach(BenefitCategory.allCases, id: \.self) { category in
                        DisclosureGroup(
                            isExpanded: Binding(
                                get: { expandedCategories.contains(category) },
                                set: { isExpanded in
                                    if isExpanded {
                                        expandedCategories.insert(category)
                                    } else {
                                        expandedCategories.remove(category)
                                    }
                                }
                            )
                        ) {
                            let items = itemsByCategory[category] ?? []
                            if items.isEmpty {
                                Text("No benefits in this category")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.vertical, 8)
                            } else {
                                ForEach(items, id: \.completion.id) { item in
                                    BenefitRow(
                                        cardName: item.cardName,
                                        catalogBenefit: item.benefit,
                                        completion: item.completion
                                    )
                                }
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(category.color)
                                    .frame(width: 12, height: 12)
                                Text(category.rawValue)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Spacer()
                                let count = itemsByCategory[category]?.count ?? 0
                                Text("\(count)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
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

    private func benefitItemsByCategory(for period: BenefitPeriod) -> [BenefitCategory: [BenefitItem]] {
        var result: [BenefitCategory: [BenefitItem]] = [:]
        
        // Initialize all categories
        for category in BenefitCategory.allCases {
            result[category] = []
        }
        
        for card in userCards {
            guard let catalog = CreditCardCatalog.all.first(where: { $0.id == card.catalogCardID }) else { continue }
            let periodBenefits = catalog.benefits.filter { $0.period == period }
            for benefit in periodBenefits {
                if let comp = card.completions.first(where: { $0.benefitName == benefit.name && $0.benefitPeriod == period }) {
                    let item = BenefitItem(cardName: card.name, benefit: benefit, completion: comp)
                    result[benefit.category, default: []].append(item)
                }
            }
        }
        
        // Sort within each category by card name
        for (key, var items) in result {
            items.sort { $0.cardName < $1.cardName }
            result[key] = items
        }
        
        return result
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
