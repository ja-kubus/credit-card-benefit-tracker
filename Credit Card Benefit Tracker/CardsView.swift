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
    // Sheet trigger — only set when we want to open the detail view
    @State private var selectedCard: UserCard? = nil
    // Accordion "lifted" card — set on single tap, does NOT open the sheet
    @State private var liftedCard: UserCard? = nil

    // Mass deletion state
    @State private var isDeleting = false
    @State private var selectedForDeletion: Set<PersistentIdentifier> = []
    @State private var showBulkDeleteAlert = false
    
    // Accordion state
    @State private var viewMode: ViewMode = .accordion
    @State private var expandCards: Bool = false
    @State private var showDetailView: Bool = false
    @Namespace var animation

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    enum ViewMode {
        case grid
        case accordion
    }
    
    var isCardSelected: Bool {
        return selectedCard != nil
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if userCards.isEmpty {
                    emptyState
                } else if viewMode == .accordion {
                    accordionView
                } else {
                    gridView
                }
            }
            .navigationTitle("My Wallet")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 12) {
                        // Accordion view button
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                viewMode = .accordion
                            }
                        } label: {
                            Image(systemName: "square.stack.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(viewMode == .accordion ? .white : .gray)
                                .frame(width: 32, height: 32)
                                .background(viewMode == .accordion ? Color.blue : Color.gray.opacity(0.2))
                                .clipShape(Circle())
                        }

                        // Grid view button
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                viewMode = .grid
                            }
                        } label: {
                            Image(systemName: "square.grid.2x2.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(viewMode == .grid ? .white : .gray)
                                .frame(width: 32, height: 32)
                                .background(viewMode == .grid ? Color.blue : Color.gray.opacity(0.2))
                                .clipShape(Circle())
                        }
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewMode == .grid {
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
                    } else {
                        Button {
                            showingAddCard = true
                        } label: {
                            Image(systemName: "plus")
                                .fontWeight(.semibold)
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
                    selectedCard = nil
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
            .overlay {
                if showDetailView, let currentCard = selectedCard {
                    CardDetailOverlay(
                        currentCard: currentCard,
                        showDetailView: $showDetailView,
                        animation: animation,
                        onDelete: {
                            modelContext.delete(currentCard)
                            showDetailView = false
                        }
                    )
                }
            }
        }
    }

    // MARK: - Sub-views

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

    private var accordionView: some View {
        VStack(spacing: 0) {
            // ── Lifted card ── fully separated at the top
            if let lifted = liftedCard {
                CardThumbnail(card: lifted)
                    .matchedGeometryEffect(id: lifted.persistentModelID, in: animation)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                    .onTapGesture {
                        // Tap lifted card → open detail sheet
                        selectedCard = lifted
                    }
                    .gesture(DragGesture(minimumDistance: 30)
                        .onEnded { value in
                            // Check if the vertical movement is greater than horizontal
                            if value.translation.height > 0 && abs(value.translation.height) > abs(value.translation.width) {
                                withAnimation(.easeInOut(duration: 0.4)) {
                                    liftedCard = nil
                                }
                            }
                        })
            }

            // ── Stacked remaining cards ──
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: -150) {
                    ForEach(userCards) { card in
                        if liftedCard?.persistentModelID != card.persistentModelID {
                            CardThumbnail(card: card)
                                .matchedGeometryEffect(id: card.persistentModelID, in: animation)
                                .zIndex(Double(userCards.firstIndex(where: { $0.persistentModelID == card.persistentModelID }) ?? 0))
                                .padding(.horizontal, 20)
                                .onTapGesture {
                                    // Single tap → lift this card, return previous lifted card to stack
                                    withAnimation(.easeInOut(duration: 0.4)) {
                                        liftedCard = card
                                    }
                                }
                        }
                    }
                }
                .padding(.top, 12)
                .padding(.bottom, 32)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var gridView: some View {
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

// MARK: - Card Detail Overlay

struct CardDetailOverlay: View {
    let currentCard: UserCard
    @Binding var showDetailView: Bool
    var animation: Namespace.ID
    var onDelete: () -> Void
    
    @State private var showDeleteAlert = false

    var body: some View {
        VStack {
            CardThumbnail(card: currentCard)
                .matchedGeometryEffect(id: currentCard.persistentModelID, in: animation)
                .frame(height: 200)
                .padding()
                .onTapGesture {
                    withAnimation(.easeInOut) {
                        showDetailView = false
                    }
                }
                .zIndex(10)

            GeometryReader { proxy in
                let height = proxy.size.height + 50
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 16) {
                        // Card info and delete button
                        VStack(spacing: 12) {
                            VStack(spacing: 4) {
                                Text(currentCard.name)
                                    .font(.system(size: 18, weight: .semibold))
                                Text(currentCard.issuer)
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                            }
                            
                            Button(role: .destructive) {
                                showDeleteAlert = true
                            } label: {
                                HStack {
                                    Image(systemName: "trash.fill")
                                    Text("Remove Card")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(12)
                                .background(Color.red.opacity(0.1))
                                .foregroundStyle(.red)
                                .cornerRadius(8)
                            }
                        }
                        .padding()
                    }
                }
                .frame(maxWidth: .infinity)
                .background(
                    Color.white
                        .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
                        .ignoresSafeArea()
                )
            }
            .padding([.horizontal, .top])
            .zIndex(-10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(.systemGray6).ignoresSafeArea())
        .alert("Remove Card", isPresented: $showDeleteAlert) {
            Button("Remove", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Remove \(currentCard.issuer) \(currentCard.name) from your wallet?")
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
