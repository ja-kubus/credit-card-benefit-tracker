//
//  AddCardView.swift
//  Credit Card Benefit Tracker
//
//  Created by Jacob Michalik on 4/20/26.
//

import SwiftUI
import SwiftData

struct AddCardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var userCards: [UserCard]

    @State private var searchText = ""

    private var ownedIDs: Set<String> {
        Set(userCards.map(\.catalogCardID))
    }

    private var filteredCards: [CatalogCard] {
        let available = CreditCardCatalog.available(excluding: ownedIDs)
        if searchText.isEmpty { return available }
        return available.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.issuer.localizedCaseInsensitiveContains(searchText)
        }
    }

    // Group by issuer
    private var groupedCards: [(issuer: String, cards: [CatalogCard])] {
        let grouped = Dictionary(grouping: filteredCards, by: \.issuer)
        return grouped.keys.sorted().map { issuer in
            (issuer: issuer, cards: grouped[issuer]!.sorted { $0.name < $1.name })
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if groupedCards.isEmpty {
                    ContentUnavailableView.search
                } else {
                    List {
                        ForEach(groupedCards, id: \.issuer) { group in
                            Section(group.issuer) {
                                ForEach(group.cards) { card in
                                    CatalogCardRow(card: card) {
                                        addCard(card)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Add Card")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search cards…")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func addCard(_ catalog: CatalogCard) {
        let card = UserCard(from: catalog)
        modelContext.insert(card)

        // Find catalog entry and create BenefitCompletion records
        for benefit in catalog.benefits {
            let completion = BenefitCompletion(cardID: card.catalogCardID, benefit: benefit)
            modelContext.insert(completion)
            card.completions.append(completion)
        }
    }
}

// MARK: - Row

struct CatalogCardRow: View {
    let card: CatalogCard
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            // Mini card thumbnail – real photo if available, gradient fallback
            Group {
                if UIImage(named: card.imageName) != nil {
                    Image(card.imageName)
                        .resizable()
                        .aspectRatio(1.586, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: card.accentColor), Color(hex: card.accentColor).opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            Text(card.issuer.prefix(2))
                                .font(.caption2.weight(.heavy))
                                .foregroundStyle(.white)
                        )
                }
            }
            .frame(width: 60, height: 38)
            .shadow(color: Color(hex: card.accentColor).opacity(0.3), radius: 4, x: 0, y: 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(card.name)
                    .font(.subheadline.weight(.semibold))
                Text(card.annualFee == 0 ? "No Annual Fee" : "Annual Fee: \(card.annualFee, format: .currency(code: "USD"))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                onAdd()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    AddCardView()
        .modelContainer(for: [UserCard.self, BenefitCompletion.self], inMemory: true)
}
