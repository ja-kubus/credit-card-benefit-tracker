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

    @State private var cardToDelete: UserCard? = nil

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
                    Button {
                        showingAddCard = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
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
            .alert("Remove Card", isPresented: Binding(
                get: { cardToDelete != nil },
                set: { if !$0 { cardToDelete = nil } }
            )) {
                Button("Remove", role: .destructive) {
                    if let card = cardToDelete {
                        modelContext.delete(card)
                        cardToDelete = nil
                    }
                }
                Button("Cancel", role: .cancel) { cardToDelete = nil }
            } message: {
                if let card = cardToDelete {
                    Text("Remove \(card.issuer) \(card.name) from your wallet?")
                }
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
                    ZStack(alignment: .topTrailing) {
                        CardThumbnail(card: card)
                            .onTapGesture { selectedCard = card }
                            .contextMenu {
                                Button(role: .destructive) {
                                    cardToDelete = card
                                } label: {
                                    Label("Remove Card", systemImage: "trash")
                                }
                            }

                        // Remove badge
                        Button {
                            cardToDelete = card
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.white, .red)
                                .shadow(radius: 2)
                        }
                        .offset(x: 6, y: -6)
                    }
                }
            }
            .padding(16)
        }
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
