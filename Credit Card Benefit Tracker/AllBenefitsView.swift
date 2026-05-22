//
//  AllBenefitsView.swift
//  Credit Card Benefit Tracker
//
//  Created by Jacob Michalik on 5/20/26.
//

import SwiftUI
import SwiftData

struct AllBenefitsView: View {
    @Environment(\.dismiss) private var dismiss
    
    let userCards: [UserCard]
    
    @State private var selectedCardIds: Set<PersistentIdentifier> = []
    @State private var selectedPeriod: BenefitPeriod? = nil
    
    var filteredBenefits: [(card: UserCard, catalog: CatalogCard, benefits: [CatalogBenefit])] {
        var result: [(UserCard, CatalogCard, [CatalogBenefit])] = []
        
        let cardsToShow = selectedCardIds.isEmpty ? Set(userCards.map { $0.persistentModelID }) : selectedCardIds
        
        for card in userCards {
            if !cardsToShow.contains(card.persistentModelID) { continue }
            
            guard let catalog = CreditCardCatalog.all.first(where: { $0.id == card.catalogCardID }) else { continue }
            
            var cardBenefits: [CatalogBenefit]
            if let period = selectedPeriod {
                cardBenefits = catalog.benefits.filter { $0.period == period }
            } else {
                cardBenefits = catalog.benefits
            }
            
            if !cardBenefits.isEmpty {
                result.append((card, catalog, cardBenefits))
            }
        }
        
        return result
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // ── Filter Section ──
                VStack(spacing: 12) {
                    // Card Filter
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Filter by Card")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(userCards, id: \.persistentModelID) { card in
                                    let isSelected = selectedCardIds.isEmpty || selectedCardIds.contains(card.persistentModelID)
                                    
                                    Button {
                                        if selectedCardIds.isEmpty {
                                            // All are currently selected, so clicking one deselects all others
                                            selectedCardIds = [card.persistentModelID]
                                        } else if selectedCardIds.contains(card.persistentModelID) {
                                            // Deselect this card
                                            selectedCardIds.remove(card.persistentModelID)
                                        } else {
                                            // Select this card
                                            selectedCardIds.insert(card.persistentModelID)
                                        }
                                    } label: {
                                        VStack(spacing: 2) {
                                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                                .font(.system(size: 12, weight: .semibold))
                                            Text(card.name)
                                                .font(.caption2.weight(.semibold))
                                                .lineLimit(2)
                                                .multilineTextAlignment(.center)
                                        }
                                        .frame(width: 60)
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 6)
                                        .background(isSelected ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
                                        .foregroundStyle(isSelected ? .blue : .secondary)
                                        .cornerRadius(8)
                                    }
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    Divider()
                    
                    // Period Filter
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Filter by Period")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                        
                        HStack(spacing: 8) {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedPeriod = nil
                                }
                            } label: {
                                Text("All")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(selectedPeriod == nil ? Color.blue : Color.gray.opacity(0.1))
                                    .foregroundStyle(selectedPeriod == nil ? .white : .secondary)
                                    .cornerRadius(6)
                            }
                            
                            ForEach(BenefitPeriod.allCases, id: \.self) { period in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedPeriod = period
                                    }
                                } label: {
                                    Text(period.rawValue)
                                        .font(.caption.weight(.semibold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(selectedPeriod == period ? Color.blue : Color.gray.opacity(0.1))
                                        .foregroundStyle(selectedPeriod == period ? .white : .secondary)
                                        .cornerRadius(6)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical, 12)
                .background(Color(.secondarySystemGroupedBackground))
                
                Divider()
                
                // ── Benefits List ──
                if filteredBenefits.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "checkmark.seal")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text("No benefits match your filters.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(Array(filteredBenefits.enumerated()), id: \.offset) { cardIndex, item in
                                VStack(alignment: .leading, spacing: 12) {
                                    // Card header
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(item.card.issuer)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            Text(item.card.name)
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(.primary)
                                        }
                                        Spacer()
                                    }
                                    
                                    // Benefits for this card
                                    VStack(spacing: 0) {
                                        ForEach(Array(item.benefits.enumerated()), id: \.offset) { benefitIndex, benefit in
                                            HStack(alignment: .top, spacing: 12) {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    HStack(spacing: 8) {
                                                        Text(benefit.name)
                                                            .font(.subheadline.weight(.semibold))
                                                            .foregroundStyle(.primary)
                                                        
                                                        Spacer()
                                                        
                                                        Text(benefit.dollarAmount.formatted(.currency(code: "USD").precision(.fractionLength(0))))
                                                            .font(.subheadline.weight(.bold))
                                                            .foregroundStyle(.green)
                                                    }
                                                    
                                                    Text(benefit.period.rawValue.lowercased())
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                    
                                                    if !benefit.description.isEmpty {
                                                        Text(benefit.description)
                                                            .font(.caption)
                                                            .foregroundStyle(.secondary)
                                                    }
                                                }
                                                
                                                Spacer(minLength: 0)
                                            }
                                            .padding(.vertical, 12)
                                            .padding(.horizontal, 12)
                                            
                                            if benefitIndex < item.benefits.count - 1 {
                                                Divider().padding(.leading, 12)
                                            }
                                        }
                                    }
                                    .background(Color(.secondarySystemGroupedBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("All Benefits")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: UserCard.self, BenefitCompletion.self, configurations: config)
    
    let card1 = UserCard(from: CreditCardCatalog.all[0])
    let card2 = UserCard(from: CreditCardCatalog.all[1])
    container.mainContext.insert(card1)
    container.mainContext.insert(card2)
    
    return AllBenefitsView(userCards: [card1, card2])
        .modelContainer(container)
}
