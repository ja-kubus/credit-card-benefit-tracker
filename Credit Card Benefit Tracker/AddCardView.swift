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
    @Query private var notificationSettings: [NotificationSettings]

    @State private var searchText = ""
    @State private var showNotificationPermission = false
    @State private var cardPendingNotificationDecision: CatalogCard?
    @State private var rememberNotificationPreference = false

    private var ownedIDs: Set<String> {
        Set(userCards.map(\.catalogCardID))
    }

    private var filteredCards: [CatalogCard] {
        if searchText.isEmpty { return CreditCardCatalog.all }
        return CreditCardCatalog.all.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.issuer.localizedCaseInsensitiveContains(searchText)
        }
    }

    // Group by issuer (all cards, owned or not)
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
                                    let isOwned = ownedIDs.contains(card.id)
                                    CatalogCardRow(card: card, isOwned: isOwned) {
                                        initiateCardAddition(card)
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
        .sheet(isPresented: $showNotificationPermission) {
            if let catalogCard = cardPendingNotificationDecision {
                NotificationPermissionView(
                    cardName: catalogCard.name,
                    cardIssuer: catalogCard.issuer,
                    onAllow: { shouldRemember in
                        addCard(catalogCard, withNotifications: true)
                        if shouldRemember {
                            rememberNotificationPreference = true
                            updateNotificationDefaults(enabled: true)
                        }
                        showNotificationPermission = false
                    },
                    onDeny: {
                        addCard(catalogCard, withNotifications: false)
                        showNotificationPermission = false
                    }
                )
                .presentationDetents([.medium])
            }
        }
    }

    private func initiateCardAddition(_ catalog: CatalogCard) {
        // Check if we should ask for notification permission
        let settings = notificationSettings.first
        if rememberNotificationPreference || settings?.rememberNotificationPreference == true {
            // User already made a choice, use their default
            let defaultEnabled = settings?.notificationsEnabled ?? true
            addCard(catalog, withNotifications: defaultEnabled)
        } else {
            // Show permission dialog
            cardPendingNotificationDecision = catalog
            showNotificationPermission = true
        }
    }

    private func addCard(_ catalog: CatalogCard, withNotifications: Bool) {
        let card = UserCard(from: catalog)
        card.notificationsEnabled = withNotifications
        modelContext.insert(card)

        for benefit in catalog.benefits {
            let completion = BenefitCompletion(cardID: card.catalogCardID, benefit: benefit)
            modelContext.insert(completion)
            card.completions.append(completion)
        }
    }
    
    private func updateNotificationDefaults(enabled: Bool) {
        if let settings = notificationSettings.first {
            settings.notificationsEnabled = enabled
            settings.rememberNotificationPreference = true
        } else {
            let newSettings = NotificationSettings()
            newSettings.notificationsEnabled = enabled
            newSettings.rememberNotificationPreference = true
            modelContext.insert(newSettings)
        }
    }
}

// MARK: - Row

struct CatalogCardRow: View {
    let card: CatalogCard
    let isOwned: Bool
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            // Mini card thumbnail
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
            .opacity(isOwned ? 0.4 : 1.0)

            VStack(alignment: .leading, spacing: 2) {
                Text(card.name)
                    .font(.subheadline.weight(.semibold))
                Text(card.annualFee == 0 ? "No Annual Fee" : "Annual Fee: \(card.annualFee, format: .currency(code: "USD"))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if isOwned {
                    Text("Already in wallet")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            .opacity(isOwned ? 0.5 : 1.0)

            Spacer()

            if isOwned {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            } else {
                Button {
                    onAdd()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle()) // keeps tap area clean without triggering add
    }
}

#Preview {
    AddCardView()
        .modelContainer(for: [UserCard.self, BenefitCompletion.self], inMemory: true)
}
