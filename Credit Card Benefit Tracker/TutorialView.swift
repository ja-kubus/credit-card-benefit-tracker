//
//  TutorialView.swift
//  Credit Card Benefit Tracker
//
//  Created by Jacob Michalik on 5/20/26.
//

import SwiftUI
import SwiftData

// MARK: - Spotlight Registry
//
// Toolbar buttons report their actual on-screen frames (global coordinates)
// here so the tutorial spotlight lands exactly on them instead of relying on
// hardcoded estimates that break across devices and safe areas.
@Observable
final class TutorialSpotlightRegistry {
    static let shared = TutorialSpotlightRegistry()
    var frames: [String: CGRect] = [:]
    private init() {}
}

extension View {
    /// Reports this view's global frame to the tutorial spotlight registry
    /// under the given key, so the tutorial can highlight it precisely.
    func reportSpotlightFrame(_ key: String) -> some View {
        onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .global)
        } action: { frame in
            TutorialSpotlightRegistry.shared.frames[key] = frame
        }
    }
}

struct TutorialView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage("hasCompletedTutorial") private var hasCompletedTutorial = false
    @AppStorage("isRedoingTutorial") private var isRedoingTutorial = false
    
    @State private var currentStep = 0
    @State private var dummyCards: [UserCard] = []
    @State private var showAddCard = false
    @State private var showGridView = false
    @State private var selectedCard: UserCard?
    @State private var selectedAddedCard: UserCard?
    @State private var cardCountBeforeTutorial = 0
    
    var body: some View {
        ZStack {
            // Main content based on step
            contentForStep(currentStep)
                .zIndex(0)
            
            // Tutorial overlay with highlight and instructions (not shown on final step)
            if currentStep != 14 {
                TutorialOverlay(
                    step: currentStep,
                    onContinue: handleContinue,
                    onSkip: skipTutorial,
                    dummyCards: dummyCards,
                    selectedCard: selectedCard,
                    selectedAddedCard: selectedAddedCard,
                    canContinue: canContinueStep()
                )
                .zIndex(1)
            }
        }
        .onAppear {
            // Track how many cards existed before tutorial started
            let allCardsBefore = try? modelContext.fetch(FetchDescriptor<UserCard>())
            cardCountBeforeTutorial = allCardsBefore?.count ?? 0
        }
        .interactiveDismissDisabled(currentStep < 14) // Prevent swipe-to-dismiss during tutorial
    }
    
    @ViewBuilder
    private func contentForStep(_ step: Int) -> some View {
        switch step {
        case 0:
            // Welcome - Wallet tab with no cards
            CardsView()
        case 1:
            // Tap the plus - Wallet tab (bottom overlay, spotlight add button)
            CardsView()
        case 2:
            // Select a Card - Add card page
            AddCardView()
        case 3:
            // Switch to Grid View - Wallet tab (bottom overlay, spotlight toggle)
            CardsView()
        case 4:
            // Managing Your Cards - Wallet tab
            CardsView()
        case 5:
            // Card Details - Earning Rates tab
            if let card = selectedAddedCard {
                CardTabsView(card: card, onDelete: nil)
            } else {
                CardsView()
            }
        case 6:
            // Card Benefits - Card detail
            if let card = selectedAddedCard {
                CardTabsView(card: card, onDelete: nil)
            } else {
                CardsView()
            }
        case 7:
            // Upload Statements - Wallet tab (bottom overlay, spotlight upload)
            CardsView()
        case 8:
            // Value tab - Overview (annual fee vs value recoup)
            DashboardView()
        case 9:
            // Value tab - Benefits segment
            DashboardView()
        case 10:
            // Value tab - Spending segment
            DashboardView()
        case 11:
            // Best Card Recommendations
            RecommendationsView()
        case 12:
            // Subscriptions - recurring charges
            SubscriptionsView()
        case 13:
            // Settings & Notifications
            SettingsView()
        case 14:
            // Thank you screen (no overlay)
            ThankYouView(onDone: {
                completeTutorial()
            })
        default:
            CardsView()
        }
    }
    
    /// Determines if the Continue button should be enabled for the current step
    private func canContinueStep() -> Bool {
        switch currentStep {
        case 2:
            // For step 2 (AddCardView), check if at least one card was added during tutorial
            let currentCardCount = (try? modelContext.fetch(FetchDescriptor<UserCard>()))?.count ?? 0
            
            if isRedoingTutorial {
                // If redoing from settings, allow continue if there are already cards OR if one was just added
                return currentCardCount > cardCountBeforeTutorial || currentCardCount > 0
            } else {
                // On first run, force user to add a card
                return currentCardCount > cardCountBeforeTutorial
            }
        default:
            return true
        }
    }
    
    private func handleContinue() {
        // Special logic for certain steps
        if currentStep == 2 {
            // After adding card, get the newly added card (sorted so .last is the newest)
            let allCards = try? modelContext.fetch(
                FetchDescriptor<UserCard>(sortBy: [SortDescriptor(\.dateAdded)])
            )
            if let cards = allCards, !cards.isEmpty {
                selectedAddedCard = cards.last
                dummyCards = cards
            }
        }
        
        currentStep += 1

        if currentStep > 14 {
            completeTutorial()
        }
    }
    
    private func skipTutorial() {
        completeTutorial()
    }
    
    private func completeTutorial() {
        hasCompletedTutorial = true
        isRedoingTutorial = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            dismiss()
        }
    }
}

// MARK: - Tutorial Overlay

struct TutorialOverlay: View {
    let step: Int
    let onContinue: () -> Void
    let onSkip: () -> Void
    let dummyCards: [UserCard]
    let selectedCard: UserCard?
    let selectedAddedCard: UserCard?
    let canContinue: Bool

    // Drag state so the user can move the instruction card out of the way
    @State private var cardOffset: CGSize = .zero
    @State private var dragTranslation: CGSize = .zero

    /// Returns true for steps where we should darken the background and spotlight a button
    private func shouldSpotlight() -> Bool {
        return [1, 3, 7].contains(step) // Steps with interactive buttons to click
    }
    
    /// Get the spotlight frame for interactive buttons.
    /// Prefers the button's actual measured frame (reported to
    /// TutorialSpotlightRegistry in global coordinates); falls back to a
    /// safe-area-based estimate if the button hasn't reported yet.
    private func getSpotlightFrame(screenWidth: CGFloat, safeAreaTop: CGFloat) -> CGRect {
        let registryKey: String?
        switch step {
        case 1: registryKey = "addCard"
        case 3: registryKey = "gridToggle"
        case 7: registryKey = "upload"
        default: registryKey = nil
        }

        if let key = registryKey,
           let measured = TutorialSpotlightRegistry.shared.frames[key],
           !measured.isEmpty {
            return measured
        }

        // Fallback estimates (nav bar center ≈ safeAreaTop + 22)
        let centerY = safeAreaTop + 22
        let size: CGFloat = 36
        func frame(centerX: CGFloat) -> CGRect {
            CGRect(x: centerX - size / 2, y: centerY - size / 2, width: size, height: size)
        }
        switch step {
        case 1: return frame(centerX: screenWidth - 30)
        case 3: return frame(centerX: 76)
        case 7: return frame(centerX: screenWidth - 78)
        default: return .zero
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width
            let safeAreaTop = geometry.safeAreaInsets.top

            ZStack {
                // Dark overlay with spotlight cutout for certain steps.
                // Read the frame during body evaluation (not inside the Canvas
                // closure) so @Observable registry updates trigger a re-render.
                if shouldSpotlight() {
                    let spotlightFrame = getSpotlightFrame(screenWidth: screenWidth, safeAreaTop: safeAreaTop)
                    Canvas { context, size in
                        var path = Path()
                        path.addRect(CGRect(origin: .zero, size: size))
                        path.addEllipse(in: spotlightFrame.insetBy(dx: -15, dy: -15)) // Larger circle for the hole

                        context.fill(path, with: .color(.black.opacity(0.6)), style: FillStyle(eoFill: true))
                    }
                    .ignoresSafeArea()
                }

                VStack {
                    // For steps 1, 3, 7 show at bottom (spotlighted buttons); others at top
                    if [1, 3, 7].contains(step) {
                        Spacer()
                        instructionCard
                    } else {
                        // Top position for other steps
                        instructionCard
                        Spacer()
                    }
                }
            }
        }
        .onChange(of: step) { _, _ in
            // New step: return the card to its default position
            cardOffset = .zero
            dragTranslation = .zero
        }
    }

    private var cardDragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                dragTranslation = value.translation
            }
            .onEnded { value in
                cardOffset.width += value.translation.width
                cardOffset.height += value.translation.height
                dragTranslation = .zero
            }
    }

    /// Compact instruction card with title, description, and Skip/Continue on one row.
    /// Draggable so the user can move it aside to see the content behind it.
    private var instructionCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            // Grab handle hint
            HStack {
                Spacer()
                Capsule()
                    .fill(Color.white.opacity(0.35))
                    .frame(width: 32, height: 4)
                Spacer()
            }

            Text(stepTitle(step))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)

            Text(stepDescription(step))
                .font(.caption)
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(5)

            HStack {
                Button(action: onSkip) {
                    Text("Skip")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.15))
                        .clipShape(Capsule())
                }

                Spacer()

                Button(action: onContinue) {
                    HStack(spacing: 4) {
                        Text("Continue")
                        Image(systemName: "chevron.right")
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(canContinue ? Color.appCoralDark : Color.appCoralDark.opacity(0.5))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(canContinue ? Color.white : Color.white.opacity(0.4))
                    .clipShape(Capsule())
                }
                .disabled(!canContinue)
            }
        }
        .padding(12)
        .background(Color.appCoral.opacity(0.92))
        .cornerRadius(12)
        .frame(maxWidth: 340)
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .offset(
            x: cardOffset.width + dragTranslation.width,
            y: cardOffset.height + dragTranslation.height
        )
        .gesture(cardDragGesture)
    }
    
    private func stepTitle(_ step: Int) -> String {
        switch step {
        case 0: return "Welcome to Credit Card Benefit Tracker!"
        case 1: return "Adding Your First Card"
        case 2: return "Add Your Cards"
        case 3: return "Switch to Grid View"
        case 4: return "Managing Your Cards"
        case 5: return "Card Details"
        case 6: return "Card Benefits"
        case 7: return "Upload Statements"
        case 8: return "Value: Recoup Your Fees"
        case 9: return "Value: Browse Benefits"
        case 10: return "Value: Spending Breakdown"
        case 11: return "Best Card"
        case 12: return "Subscriptions"
        case 13: return "Settings & Notifications"
        default: return "Tutorial"
        }
    }
    
    private func stepDescription(_ step: Int) -> String {
        switch step {
        case 0: return "The Wallet tab holds all your cards. This app tracks their benefits and helps you maximize rewards. Let's add your first card!"
        case 1: return "Tap the plus (+) icon in the top right to add a new card."
        case 2: return "Add as many cards as you like from the list — you need at least one to continue. You can always add more later."
        case 3: return "Switch between accordion and grid layouts. Tap the toggle in the top left to see grid mode. There's also a filter to hide no-fee cards."
        case 4: return "In grid view, tap a card and use the delete button to remove it. You'll get a confirmation prompt first."
        case 5: return "Tap a card to open its details. The Earning Rates tab shows every category and how many points it earns."
        case 6: return "Each card's benefits are grouped by period — Monthly, Quarterly, Semi-Annual, and Annual — so nothing slips by unused."
        case 7: return "Tap the upload button to import PDF or CSV statements — you can also share a statement PDF straight into the app. Transactions are auto-categorized and statement credits become tracked benefits."
        case 8: return "The Value tab opens on Overview: how much value each card has recouped against its annual fee. Pick a benefit period, choose what counts (benefits used or points from spend), and tap a card to see the breakdown."
        case 9: return "The Benefits segment lets you search every benefit across all cards, see what's expiring soon and the value remaining, and mark benefits as used."
        case 10: return "The Spending segment breaks down your statement spend by category over a date range. Filter by card and tap a category to see its transactions."
        case 11: return "The Best Card tab shows which card earns the most for each spending category. Point valuations are factored in, and you can exclude restricted portal/loyalty rates."
        case 12: return "The Subscriptions tab auto-detects recurring charges from your statements. Swipe to ignore ones you don't want tracked, and revisit them in the ignored list."
        case 13: return "Settings is your notifications center — a red badge flags unread alerts like completed periods or recouped fees. Set per-card notification toggles, and restart this tutorial anytime. There's also a home-screen widget."
        default: return "Tutorial step"
        }
    }
}


// MARK: - Thank You View

struct ThankYouView: View {
    let onDone: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(Color.appLeaf)
            
            VStack(spacing: 12) {
                Text("Thank You!")
                    .font(.title.weight(.bold))
                
                Text("You're all set to start managing your credit card benefits.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            Button(action: onDone) {
                Text("Get Started")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.appCoral)
                    .foregroundStyle(.white)
                    .cornerRadius(10)
            }
        }
        .padding(40)
        .background(Color(.systemGroupedBackground))
    }
}

#Preview {
    TutorialView()
        .modelContainer(for: UserCard.self, inMemory: true)
}
