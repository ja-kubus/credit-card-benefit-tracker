//
//  TutorialView.swift
//  Credit Card Benefit Tracker
//
//  Created by Jacob Michalik on 5/20/26.
//

import SwiftUI
import SwiftData

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
            if currentStep != 13 {
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
        .interactiveDismissDisabled(currentStep < 13) // Prevent swipe-to-dismiss during tutorial
    }
    
    @ViewBuilder
    private func contentForStep(_ step: Int) -> some View {
        switch step {
        case 0:
            // Welcome - My Wallet page with no cards
            CardsView()
        case 1:
            // Tap the plus - My Wallet page (bottom overlay)
            CardsView()
        case 2:
            // Select a Card - Add card page
            AddCardView()
        case 3:
            // Switch to Grid View - My Wallet page (bottom overlay)
            CardsView()
        case 4:
            // Managing Your Cards - My Wallet page
            CardsView()
        case 5:
            // Card Details - Earning Rates tab (bottom overlay)
            if let card = selectedAddedCard {
                CardTabsView(card: card, onDelete: nil)
            } else {
                CardsView()
            }
        case 6:
            // Benefits Overview - Card detail
            if let card = selectedAddedCard {
                CardTabsView(card: card, onDelete: nil)
            } else {
                CardsView()
            }
        case 7:
            // Points & Statements tab (bottom overlay)
            if let card = selectedAddedCard {
                CardTabsView(card: card, onDelete: nil)
            } else {
                CardsView()
            }
        case 8:
            // Upload Statements - Grid view (bottom overlay)
            CardsView()
        case 9:
            // Browse All Benefits - Benefits page
            BenefitsView()
        case 10:
            // Best Card Recommendations
            RecommendationsView()
        case 11:
            // Annual Fee Tracker - Card tabs view
            if let card = selectedAddedCard {
                CardTabsView(card: card, onDelete: nil)
            } else {
                CardsView()
            }
        case 12:
            // Settings
            SettingsView()
        case 13:
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
        
        if currentStep > 13 {
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
    
    /// Returns true for steps where we should darken the background and spotlight a button
    private func shouldSpotlight() -> Bool {
        return [1, 3, 8].contains(step) // Steps with interactive buttons to click
    }
    
    /// Get the spotlight frame for interactive buttons
    private func getSpotlightFrame(screenWidth: CGFloat) -> CGRect {
        let yOffset: CGFloat = 40
        
        switch step {
        case 1:
            // Plus button - top right
            return CGRect(x: screenWidth - 55, y: yOffset, width: 40, height: 40)
        case 3:
            // Grid toggle button - top left
            return CGRect(x: 18, y: yOffset, width: 40, height: 40)
        case 8:
            // Upload button - top right
            return CGRect(x: screenWidth - 105, y: yOffset, width: 40, height: 40)
        default:
            return .zero
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width
            let screenHeight = geometry.size.height
            
            ZStack {
                // Dark overlay with spotlight cutout for certain steps
                if shouldSpotlight() {
                    Canvas { context, size in
                        let spotlightFrame = getSpotlightFrame(screenWidth: screenWidth)
                        var path = Path()
                        path.addRect(CGRect(origin: .zero, size: size))
                        path.addEllipse(in: spotlightFrame.insetBy(dx: -15, dy: -15)) // Larger circle for the hole
                        
                        context.fill(path, with: .color(.black.opacity(0.6)), style: FillStyle(eoFill: true))
                    }
                    .ignoresSafeArea()
                }
                
                VStack {
                    // For steps 1, 3, 7, 8 show at bottom; others at top
                    if [1, 3, 7, 8].contains(step) {
                        Spacer()
                        
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(stepTitle(step))
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(.white)
                                Spacer()
                                Button("Skip Tutorial") {
                                    onSkip()
                                }
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.7))
                            }
                            
                            Text(stepDescription(step))
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.9))
                                .lineLimit(5)
                            
                            HStack {
                                Spacer()
                                Button(action: onContinue) {
                                    HStack(spacing: 6) {
                                        Text("Continue")
                                        Image(systemName: "chevron.right")
                                    }
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(canContinue ? Color.white : Color.white.opacity(0.4))
                                    .foregroundStyle(canContinue ? .blue : .blue.opacity(0.5))
                                    .cornerRadius(8)
                                }
                                .disabled(!canContinue)
                            }
                        }
                        .padding(20)
                        .background(Color.blue.opacity(0.9))
                        .cornerRadius(14)
                        .padding(20)
                    } else {
                        // Top position for other steps
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(stepTitle(step))
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(.white)
                                Spacer()
                                Button("Skip Tutorial") {
                                    onSkip()
                                }
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.7))
                            }
                            
                            Text(stepDescription(step))
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.9))
                                .lineLimit(5)
                            
                            HStack {
                                Spacer()
                                Button(action: onContinue) {
                                    HStack(spacing: 6) {
                                        Text("Continue")
                                        Image(systemName: "chevron.right")
                                    }
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(canContinue ? Color.white : Color.white.opacity(0.4))
                                    .foregroundStyle(canContinue ? .blue : .blue.opacity(0.5))
                                    .cornerRadius(8)
                                }
                                .disabled(!canContinue)
                            }
                        }
                        .padding(20)
                        .background(Color.blue.opacity(0.9))
                        .cornerRadius(14)
                        .padding(20)
                        
                        Spacer()
                    }
                }
            }
        }
    }
    
    private func stepTitle(_ step: Int) -> String {
        switch step {
        case 0: return "Welcome to Credit Card Benefit Tracker!"
        case 1: return "Adding Your First Card"
        case 2: return "Select a Card"
        case 3: return "Switch to Grid View"
        case 4: return "Managing Your Cards"
        case 5: return "Card Details"
        case 6: return "Benefits Overview"
        case 7: return "Points & Statements"
        case 8: return "Upload Statements"
        case 9: return "Browse All Benefits"
        case 10: return "Best Card Recommendations"
        case 11: return "Annual Fee Tracker"
        case 12: return "Customize Your Settings"
        default: return "Tutorial"
        }
    }
    
    private func stepDescription(_ step: Int) -> String {
        switch step {
        case 0: return "This app helps you track credit card benefits and maximize your rewards. Let's get started by adding your first card!"
        case 1: return "Tap the plus (+) icon in the top right to add a new card."
        case 2: return "Select any card from the list to add it to your wallet."
        case 3: return "You can switch between accordion and grid views. Tap the toggle button in the top left to see grid mode."
        case 4: return "In grid view, tap on a card and select the delete button to remove it. You'll get a confirmation prompt."
        case 5: return "Tap on your card to open the detailed view. Here you can see all earning rates and categories."
        case 6: return "Benefits are organized by time period - Monthly, Quarterly, Semi-Annual, and Annual benefits."
        case 7: return "The Points & Statements tab lets you upload credit card statements to track points earned."
        case 8: return "Tap the upload button at the top to add PDF statements from your card issuer. The app automatically categorizes transactions."
        case 9: return "The Benefits tab shows all benefits across your cards. You can search benefits, see the expiring soon strip, and track value remaining across your wallet."
        case 10: return "See which card in your wallet earns the most for each spending category. Point valuations are factored in, so a 14x Hilton card is correctly ranked against a 4x Amex card."
        case 11: return "Track whether your cards are earning their keep. Benefits used, points earned from statements, and any prior history add up toward breaking even on your annual fee."
        case 12: return "In Settings, you can enable notifications for missed benefits and view your app preferences."
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
                .foregroundStyle(.green)
            
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
                    .background(Color.blue)
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
