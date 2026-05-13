//
//  CardsView.swift
//  Credit Card Benefit Tracker
//
//  Created by Jacob Michalik on 4/20/26.
//

import SwiftUI
import SwiftData

struct CardsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \UserCard.dateAdded) private var userCards: [UserCard]
    @State private var showingAddCard = false
    @State private var selectedCard: UserCard? = nil

    // Mass deletion state
    @State private var isDeleting = false
    @State private var selectedForDeletion: Set<PersistentIdentifier> = []
    @State private var showBulkDeleteAlert = false

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            Group {
                if userCards.isEmpty {
                    emptyState
                } else {
                    cardGrid
                }
            }
            .navigationTitle("My Wallet")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isDeleting {
                        // Confirm / Cancel row
                        HStack(spacing: 16) {
                            Button("Cancel") {
                                withAnimation { exitDeletionMode() }
                            }
                            .foregroundStyle(.secondary)

                            Button {
                                if !selectedForDeletion.isEmpty {
                                    showBulkDeleteAlert = true
                                }
                            } label: {
                                Text("Delete")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(selectedForDeletion.isEmpty ? AnyShapeStyle(.secondary) : AnyShapeStyle(Color.red))
                            }
                            .disabled(selectedForDeletion.isEmpty)
                        }
                    } else {
                        HStack(spacing: 16) {
                            if !userCards.isEmpty {
                                Button {
                                    withAnimation { isDeleting = true }
                                } label: {
                                    Image(systemName: "trash")
                                        .fontWeight(.semibold)
                                }
                                .foregroundStyle(.red)
                            }

                            Button {
                                showingAddCard = true
                            } label: {
                                Image(systemName: "plus")
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddCard) {
                AddCardView()
            }
            .sheet(item: $selectedCard) { card in
                CardDetailView(card: card, onDelete: {
                    modelContext.delete(card)
                })
            }
            .alert("Remove Cards", isPresented: $showBulkDeleteAlert) {
                Button("Remove", role: .destructive) {
                    deleteSelected()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Remove \(selectedForDeletion.count) card\(selectedForDeletion.count == 1 ? "" : "s") from your wallet? This cannot be undone.")
            }
        }
    }

    // MARK: - Sub‑views

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "creditcard.and.123")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            Text("No cards yet")
                .font(.title2.weight(.semibold))
            Text("Tap **+** to add a credit card to your wallet.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var cardGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(userCards) { card in
                    let isSelected = selectedForDeletion.contains(card.persistentModelID)

                    ZStack(alignment: .topTrailing) {
                        CardThumbnail(card: card)
                            .opacity(isDeleting && !isSelected ? 0.5 : 1.0)
                            .overlay(
                                // Selection ring in deletion mode
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(isSelected ? Color.red : Color.clear, lineWidth: 3)
                            )
                            .onTapGesture {
                                if isDeleting {
                                    toggleSelection(card)
                                } else {
                                    selectedCard = card
                                }
                            }
                            .contextMenu {
                                if !isDeleting {
                                    Button(role: .destructive) {
                                        modelContext.delete(card)
                                    } label: {
                                        Label("Remove Card", systemImage: "trash")
                                    }
                                }
                            }

                        // Selection checkmark badge in deletion mode
                        if isDeleting {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(Color.white, isSelected ? Color.red : Color(.systemGray3))
                                .shadow(radius: 2)
                                .offset(x: 6, y: -6)
                                .allowsHitTesting(false)
                        }
                    }
                    .animation(.easeInOut(duration: 0.15), value: isSelected)
                }
            }
            .padding(16)
        }
    }

    // MARK: - Helpers

    private func toggleSelection(_ card: UserCard) {
        let id = card.persistentModelID
        if selectedForDeletion.contains(id) {
            selectedForDeletion.remove(id)
        } else {
            selectedForDeletion.insert(id)
        }
    }

    private func deleteSelected() {
        let toDelete = userCards.filter { selectedForDeletion.contains($0.persistentModelID) }
        for card in toDelete {
            modelContext.delete(card)
        }
        exitDeletionMode()
    }

    private func exitDeletionMode() {
        isDeleting = false
        selectedForDeletion.removeAll()
    }
}

// MARK: - Card Thumbnail

struct CardThumbnail: View {
    let card: UserCard

    var body: some View {
        Group {
            if UIImage(named: card.imageName) != nil {
                Image(card.imageName)
                    .resizable()
                    .aspectRatio(1.586, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                gradientCard
            }
        }
        .shadow(color: Color(hex: card.accentColor).opacity(0.4), radius: 8, x: 0, y: 4)
        .overlay(alignment: .bottom) {
            if UIImage(named: card.imageName) != nil {
                VStack(spacing: 1) {
                    Text(card.name)
                        .font(.caption2.weight(.semibold))
                        .lineLimit(1)
                    Text(card.issuer)
                        .font(.caption2)
                        .opacity(0.8)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial.opacity(0.85))
                .clipShape(
                    .rect(bottomLeadingRadius: 16, bottomTrailingRadius: 16)
                )
            }
        }
    }

    private var gradientCard: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: card.accentColor), Color(hex: card.accentColor).opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .aspectRatio(1.586, contentMode: .fit)

            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.25), .clear],
                        startPoint: .topLeading,
                        endPoint: .center
                    )
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(card.name)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Text(card.issuer)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(12)
        }
    }
}

#Preview {
    CardsView()
        .modelContainer(for: [UserCard.self, BenefitCompletion.self], inMemory: true)
}
