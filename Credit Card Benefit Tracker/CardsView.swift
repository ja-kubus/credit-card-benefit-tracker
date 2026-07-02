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
    @State private var isDragging = false
    @State private var showingAddCard = false
    // Sheet trigger — only set when we want to open the detail view
    @State private var selectedCard: UserCard? = nil
    // Accordion "lifted" card — set on single tap, does NOT open the sheet
    @State private var liftedCard: UserCard? = nil

    // Mass deletion state
    @State private var isDeleting = false
    @State private var selectedForDeletion: Set<PersistentIdentifier> = []
    @State private var showBulkDeleteAlert = false
    
    // Upload state
    @State private var showStatementUpload = false
    
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
        case portfolio
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
                } else if viewMode == .portfolio {
                    portfolioView
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

                        // Portfolio view button
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                viewMode = .portfolio
                            }
                        } label: {
                            Image(systemName: "chart.bar.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(viewMode == .portfolio ? .white : .gray)
                                .frame(width: 32, height: 32)
                                .background(viewMode == .portfolio ? Color.blue : Color.gray.opacity(0.2))
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
                                        showStatementUpload = true
                                    } label: {
                                        Image(systemName: "arrow.up.doc")
                                            .fontWeight(.semibold)
                                    }
                                    .foregroundStyle(.blue)
                                }

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
                        // Accordion view buttons
                        HStack(spacing: 16) {
                            if !userCards.isEmpty {
                                Button {
                                    showStatementUpload = true
                                } label: {
                                    Image(systemName: "arrow.up.doc")
                                        .fontWeight(.semibold)
                                }
                                .foregroundStyle(.blue)
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
                CardTabsView(card: card, onDelete: {
                    modelContext.delete(card)
                    selectedCard = nil
                })
            }
            .sheet(isPresented: $showStatementUpload) {
                StatementUploadSheet(userCards: userCards) {
                    // This callback is called when upload completes successfully
                }
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
                .gesture(DragGesture(minimumDistance: 30)
                    .onChanged { gesture in
                        if !isDragging { isDragging = true }
                    })
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

    private var portfolioView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // MARK: Summary header
                let totalFees = userCards.reduce(0.0) { $0 + $1.annualFee }
                let totalPotential = userCards.reduce(0.0) { $0 + annualizedBenefitValue(for: $1) }
                let netValue = totalPotential - totalFees

                VStack(spacing: 12) {
                    Text("Portfolio Overview")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 0) {
                        portfolioStat(label: "Annual Fees", value: totalFees, color: .red)
                        Divider().frame(height: 40)
                        portfolioStat(label: "Potential Value", value: totalPotential, color: .blue)
                        Divider().frame(height: 40)
                        portfolioStat(label: "Net Value", value: netValue, color: netValue >= 0 ? .green : .red)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                }
                .padding()
                .background(Color(.systemGroupedBackground))
                .cornerRadius(16)
                .padding(.horizontal)

                // MARK: Per-card rows
                VStack(spacing: 12) {
                    ForEach(userCards) { card in
                        let cycleAvailable = currentCycleValue(for: card)
                        let claimed = claimedThisCycle(for: card)

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(card.name)
                                        .font(.subheadline.weight(.semibold))
                                    Text(card.issuer)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("$\(Int(card.annualFee)) fee")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.red)
                                    Text("$\(Int(cycleAvailable)) this cycle")
                                        .font(.caption)
                                        .foregroundStyle(.blue)
                                }
                            }

                            ProgressView(value: min(claimed, cycleAvailable), total: max(cycleAvailable, 0.01))
                                .tint(.green)

                            HStack {
                                Text("This cycle: $\(Int(claimed)) / $\(Int(cycleAvailable))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                let totalTowardFee = claimed + card.manualClaimedValue
                                if totalTowardFee >= card.annualFee {
                                    Text("Fee recouped")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.green)
                                } else {
                                    Text("$\(Int(card.annualFee - totalTowardFee)) to recoup fee")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal)

                Spacer(minLength: 32)
            }
            .padding(.top, 12)
        }
        .background(Color(.systemGroupedBackground))
    }

    private func annualizedBenefitValue(for card: UserCard) -> Double {
        guard let catalogCard = CreditCardCatalog.all.first(where: { $0.id == card.catalogCardID }) else {
            return 0
        }
        return catalogCard.benefits.reduce(0.0) { total, benefit in
            let multiplier: Double = {
                switch benefit.period {
                case .monthly:      return 12
                case .quarterly:    return 4
                case .semiAnnually: return 2
                case .annually:     return 1
                }
            }()
            return total + benefit.dollarAmount * multiplier
        }
    }

    /// Value available in the CURRENT cycle: plain sum of each benefit's dollar amount
    /// across all benefit periods (not annualized).
    private func currentCycleValue(for card: UserCard) -> Double {
        guard let catalogCard = CreditCardCatalog.all.first(where: { $0.id == card.catalogCardID }) else {
            return 0
        }
        return catalogCard.benefits.reduce(0.0) { $0 + $1.dollarAmount }
    }

    private func claimedThisCycle(for card: UserCard) -> Double {
        card.completions.reduce(0.0) { total, completion in
            if completion.isCompleted {
                return total + completion.dollarAmount
            }
            let partial = completion.partialUsage.trimmingCharacters(in: .whitespaces)
            if !partial.isEmpty {
                return total + (Double(partial) ?? 0)
            }
            return total
        }
    }

    private func portfolioStat(label: String, value: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text("$\(Int(abs(value)))")
                .font(.headline.weight(.bold))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
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

// MARK: - Points Breakdown View

struct PointsBreakdownView: View {
    let card: UserCard
    @Binding var isPresented: Bool
    var showStatementUploadButton: Bool = false
    @State private var selectedYear = Calendar.current.component(.year, from: Date())
    @State private var showMissingMonths = false

    var currentYearStatements: [Statement] {
        card.statements.filter { Calendar.current.component(.year, from: $0.statementMonth) == selectedYear }
    }

    // Months (1-based) that have at least one uploaded statement for the selected year
    private var uploadedMonths: Set<Int> {
        Set(currentYearStatements.map { Calendar.current.component(.month, from: $0.statementMonth) })
    }

    // Months we expect statements for: Jan through last month (for the selected year)
    // If selected year is in the past, all 12 months are expected
    private var expectedMonths: [Int] {
        let cal = Calendar.current
        let now = Date()
        let currentYear = cal.component(.year, from: now)
        let currentMonth = cal.component(.month, from: now)
        let lastExpectedMonth = selectedYear < currentYear ? 12 : max(currentMonth - 1, 0)
        guard lastExpectedMonth > 0 else { return [] }
        return Array(1...lastExpectedMonth)
    }

    private var missingMonths: [Int] {
        expectedMonths.filter { !uploadedMonths.contains($0) }
    }

    private static let monthNames = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
    
    // Extract earning rates from card's earning highlights
    var earningRates: [EarningRate] {
        // Parse earning highlights from catalog
        guard let catalog = CreditCardCatalog.all.first(where: { $0.id == card.catalogCardID }) else {
            return []
        }
        let highlights = CreditCardCatalog.earningHighlights(for: catalog)
        
        // Map highlights to earning rates with intelligent parsing
        var rates: [EarningRate] = []
        var seenCategories = Set<String>()
        
        for highlight in highlights {
            // Extract multiplier (e.g., "14x", "5x", "2x")
            let multiplier = extractMultiplier(from: highlight)
            guard multiplier > 0 else { continue }
            
            // Categorize based on keywords
            let categories = categorizeEarningHighlight(highlight, multiplier: multiplier)
            
            // Skip highlights that didn't get categorized (empty results)
            // Only process highlights that matched specific categories
            guard !categories.isEmpty else { continue }
            
            for (categoryName, categoryType) in categories {
                // Avoid duplicates
                let key = "\(multiplier)x_\(categoryType)"
                if !seenCategories.contains(key) {
                    rates.append(EarningRate(multiplier: multiplier, category: categoryType, description: highlight))
                    seenCategories.insert(key)
                }
            }
        }
        
        // Add default 1x for other purchases if not already present
        if !seenCategories.contains("1.0x_Other") {
            rates.append(EarningRate(multiplier: 1.0, category: "Other", description: "1x point on all other eligible purchases"))
        }
        
        return rates.sorted { $0.multiplier > $1.multiplier }
    }
    
    // Extract numeric multiplier from earning highlight
    private func extractMultiplier(from highlight: String) -> Double {
        let lowercased = highlight.lowercased()
        
        // Look for patterns like "14x", "5x", "3%", etc.
        if let range = lowercased.range(of: #"(\d+(?:\.\d+)?)x"#, options: .regularExpression) {
            let xString = String(lowercased[range]).lowercased().replacingOccurrences(of: "x", with: "")
            return Double(xString) ?? 0
        }
        
        // Handle percentage format (6%)
        if let range = lowercased.range(of: #"(\d+(?:\.\d+)?)%"#, options: .regularExpression) {
            let percentString = String(lowercased[range]).replacingOccurrences(of: "%", with: "")
            // Convert percentage to multiplier format (6% = 6x for display purposes)
            return Double(percentString) ?? 0
        }
        
        return 0
    }
    
    // Categorize earning highlight into one or more spending categories
    private func categorizeEarningHighlight(_ highlight: String, multiplier: Double) -> [(name: String, category: String)] {
        let lowercased = highlight.lowercased()
        var results: [(String, String)] = []
        
        // Restaurant keywords
        if lowercased.contains(regex: "restaurant") {
            results.append((multiplier > 1 ? "\(Int(multiplier))x Restaurants" : "Restaurants", "Restaurants"))
        }
        
        // Supermarket/Grocery keywords
        if lowercased.contains(regex: "supermarket|grocery|whole foods|kroger|safeway") {
            results.append((multiplier > 1 ? "\(Int(multiplier))x Supermarkets" : "Supermarkets", "Supermarkets"))
        }
        
        // Apple Store/Purchases keywords
        if lowercased.contains(regex: "apple|apple pay|physical.*card|rotating") {
            // Distinguish between Apple Pay, Physical Card, and Apple/Rotating
            if lowercased.contains(regex: "apple pay") {
                results.append((multiplier > 1 ? "\(Int(multiplier))x Apple Pay" : "Apple Pay", "Apple Pay"))
            } else if lowercased.contains(regex: "physical.*card") {
                results.append((multiplier > 1 ? "\(Int(multiplier))x Physical Card" : "Physical Card", "Physical Card"))
            } else if lowercased.contains(regex: "apple.*rotating|rotating.*apple|apple and rotating") {
                results.append((multiplier > 1 ? "\(Int(multiplier))x Apple & Rotating" : "Apple & Rotating", "Apple & Rotating"))
            } else if lowercased.contains(regex: "apple") {
                // Generic Apple mention - classify as Apple & Rotating
                results.append((multiplier > 1 ? "\(Int(multiplier))x Apple & Rotating" : "Apple & Rotating", "Apple & Rotating"))
            }
        }
        
        // Hotel/Lodging keywords - be specific about which hotels/brands
        if lowercased.contains(regex: "hilton") {
            results.append((multiplier > 1 ? "\(Int(multiplier))x Hilton Hotels" : "Hilton Hotels", "Hotels"))
        } else if lowercased.contains(regex: "hyatt") {
            results.append((multiplier > 1 ? "\(Int(multiplier))x Hyatt Hotels" : "Hyatt Hotels", "Hotels"))
        } else if lowercased.contains(regex: "ihg|intercontinental") {
            results.append((multiplier > 1 ? "\(Int(multiplier))x IHG Hotels" : "IHG Hotels", "Hotels"))
        } else if lowercased.contains(regex: "hotel|resort|accommodation|stay") {
            results.append((multiplier > 1 ? "\(Int(multiplier))x Hotels" : "Hotels", "Hotels"))
        }
        
         // Car rental keywords - matches all variations
         // Matches: "car rental", "car rentals", "rental car", "rental cars", "car hire"
         if lowercased.contains(regex: "car rental|car rentals|rental car|rental cars|car hire") {
             results.append((multiplier > 1 ? "\(Int(multiplier))x Car Rentals" : "Car Rentals", "Car Rentals"))
         }
        
        // Flight/Airlines keywords
        // Matches: "flight", "flights", "airline", "airlines", specific carrier names
        if lowercased.contains(regex: "flight|airline|united|american|delta|southwest|alaska|jetblue|spirit|frontier") {
            results.append((multiplier > 1 ? "\(Int(multiplier))x Flights" : "Flights", "Flights"))
        }
        
        // Travel keywords (broader - includes airlines, hotels, travel agents)
        // But exclude if we already captured flights or hotels
        if lowercased.contains(regex: "travel|booking") && !lowercased.contains(regex: "dining|restaurant") {
            // Only add if we haven't already added a more specific travel category
            if results.isEmpty || (!results.contains { $0.1 == "Flights" } && !results.contains { $0.1 == "Hotels" }) {
                results.append((multiplier > 1 ? "\(Int(multiplier))x Travel" : "Travel", "Travel"))
            }
        }
        
        // Dining (different from restaurants - includes food delivery, etc.)
        if lowercased.contains(regex: "dining|food|grubhub|doordash|uber eats|delivery") && !lowercased.contains(regex: "restaurant") {
            results.append((multiplier > 1 ? "\(Int(multiplier))x Dining" : "Dining", "Restaurants"))
        }
        
        // Gas stations - more flexible pattern
        if lowercased.contains(regex: "gas station|gas station|fuel|petrol") && !lowercased.contains(regex: "vehicle") {
            results.append((multiplier > 1 ? "\(Int(multiplier))x Gas Stations" : "Gas Stations", "Gas Stations"))
        }
        
        // Transit/Commute keywords
        if lowercased.contains(regex: "transit|commut|rideshare|uber|lyft|taxi") {
            results.append((multiplier > 1 ? "\(Int(multiplier))x Transit" : "Transit", "Transit"))
        }
        
        // Streaming services
        if lowercased.contains(regex: "streaming|netflix|disney|hulu|spotify|paramount|peacock|appletv|prime video") {
            results.append((multiplier > 1 ? "\(Int(multiplier))x Streaming" : "Streaming", "Streaming"))
        }
        
        // Gym/Fitness keywords
        if lowercased.contains(regex: "gym|fitness|health club|workout") {
            results.append((multiplier > 1 ? "\(Int(multiplier))x Fitness" : "Fitness", "Fitness"))
        }
        
        // Entertainment keywords (shows, movies, attractions)
        if lowercased.contains(regex: "entertainment|attraction|ticketmaster|event|concert|movie") {
            results.append((multiplier > 1 ? "\(Int(multiplier))x Entertainment" : "Entertainment", "Entertainment"))
        }
        
        // Drugstore keywords
        if lowercased.contains(regex: "drugstore|pharmacy|cvs|walgreens") {
            results.append((multiplier > 1 ? "\(Int(multiplier))x Drugstore" : "Drugstore", "Drugstore"))
        }
        
        // Default to "Other" if nothing matched
        // NOTE: We don't add a high-multiplier "Other" here - only the default 1x Other
        // is added at the end of earningRates to avoid duplicates
        if results.isEmpty && multiplier == 1.0 {
            results.append((multiplier > 1 ? "\(Int(multiplier))x Other" : "Other", "Other"))
        }
        
        return results
    }
    
    func calculatePointsForCategory(_ category: String) -> Double {
        var total = 0.0
        guard let rate = earningRates.first(where: { $0.category.lowercased() == category.lowercased() }) else {
            return 0
        }
        
        // Map display categories to statement row categories
        let statementCategories: [String] = {
            switch category.lowercased() {
            case "car rentals":
                return ["car rental", "car rentals", "rental car", "rental cars"]
            case "flights":
                return ["flights", "airlines", "air travel"]
            case "hotels":
                return ["hotels", "hotel", "resorts"]
            case "restaurants":
                return ["restaurants", "dining"]
            case "supermarkets":
                return ["supermarkets", "grocery"]
            case "gas stations":
                return ["gas stations", "gas station", "fuel", "petrol"]
            case "transit":
                return ["transit", "commute", "rideshare", "uber", "lyft", "taxi"]
            case "streaming":
                return ["streaming", "netflix", "disney", "hulu", "spotify", "paramount", "peacock", "appletv", "prime video"]
            case "fitness":
                return ["gym", "fitness", "health club", "workout"]
            case "entertainment":
                return ["entertainment", "attraction", "ticketmaster", "event", "concert", "movie"]
            case "drugstore":
                return ["drugstore", "pharmacy", "cvs", "walgreens"]
            case "apple":
                return ["apple", "apple store"]
            case "apple pay":
                return ["apple pay", "apple wallet"]
            case "apple & rotating":
                return ["apple", "apple store", "rotating"]
            case "physical card":
                return ["physical card"]
            default:
                return [category.lowercased()]
            }
        }()
        
        for statement in currentYearStatements {
            for row in statement.rows {
                // Check if row category matches any of our mapped categories
                if statementCategories.contains(where: { row.category.lowercased().contains($0) }) {
                    total += row.amount * rate.multiplier
                }
            }
        }
        return total
    }

    @Environment(\.modelContext) private var modelContext
    @State private var selectedStatement: Statement? = nil
    @State private var showingStatementDetail = false
    
    var recentStatements: [Statement] {
        card.statements.sorted { $0.statementMonth > $1.statementMonth }.prefix(5).map { $0 }
    }

    private static let statementMonthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM yyyy"
        return f
    }()

    // Year options derived from uploaded statements: earliest statement year
    // (or last year, whichever is earlier) through the current year.
    private var yearOptions: [Int] {
        let currentYear = Calendar.current.component(.year, from: Date())
        let earliestStatementYear = card.statements
            .map { Calendar.current.component(.year, from: $0.statementMonth) }
            .min()
        let startYear = min(earliestStatementYear ?? (currentYear - 1), currentYear - 1)
        return Array(startYear...currentYear)
    }
    
    var totalPoints: Double {
        earningRates.reduce(0) { total, rate in
            total + calculatePointsForCategory(rate.category)
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header with year selector and statement selector
                VStack(spacing: 12) {
                    HStack {
                        Text("Points Breakdown")
                            .font(.headline)

                        // Missing statements badge
                        Button {
                            showMissingMonths = true
                        } label: {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "doc.text.fill")
                                    .font(.subheadline)
                                    .foregroundStyle(missingMonths.isEmpty ? Color.secondary : Color.red)
                            }
                        }
                        .popover(isPresented: $showMissingMonths, arrowEdge: .top) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(missingMonths.isEmpty ? "All statements uploaded" : "Missing Statements")
                                    .font(.subheadline.weight(.semibold))

                                if missingMonths.isEmpty {
                                    HStack(spacing: 6) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.green)
                                        Text("You're all caught up for \(selectedYear).")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                } else {
                                    Text("No statement uploaded for:")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    FlowLayout(spacing: 6) {
                                        ForEach(missingMonths, id: \.self) { month in
                                            Text(PointsBreakdownView.monthNames[month - 1])
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(.white)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Color.red)
                                                .clipShape(Capsule())
                                        }
                                    }
                                }
                            }
                            .padding()
                            .presentationCompactAdaptation(.popover)
                        }

                        Spacer()
                        Menu {
                            ForEach(yearOptions, id: \.self) { year in
                                Button(action: { selectedYear = year }) {
                                    if selectedYear == year {
                                        Label(String(year), systemImage: "checkmark")
                                    } else {
                                        Text(String(year))
                                    }
                                }
                            }
                        } label: {
                            Text(String(selectedYear))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.blue)
                        }
                    }
                    
                    // Recent statements dropdown
                    if !recentStatements.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Validate Recent Statements")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            
                            Menu {
                                ForEach(recentStatements, id: \.id) { statement in
                                    Button {
                                        selectedStatement = statement
                                        showingStatementDetail = true
                                    } label: {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(statement.fileName)
                                            Text(PointsBreakdownView.statementMonthFormatter.string(from: statement.statementMonth))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        if let selected = selectedStatement {
                                            Text(selected.fileName)
                                                .font(.caption.weight(.semibold))
                                            Text(PointsBreakdownView.statementMonthFormatter.string(from: selected.statementMonth))
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        } else {
                                            Text("Select a statement to validate")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .font(.caption)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 10)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(6)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding()
                
                Divider()
                
                ScrollView {
                    VStack(spacing: 16) {
                        // Points breakdown by category
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Points by Category")
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal)
                            
                            VStack(spacing: 8) {
                                ForEach(Array(earningRates.enumerated()), id: \.offset) { index, rate in
                                    PointsCategoryRow(
                                        rate: rate,
                                        points: calculatePointsForCategory(rate.category)
                                    )
                                }
                                
                                // Total row
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Total Points")
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(.primary)
                                        }
                                        Spacer()
                                        VStack(alignment: .trailing, spacing: 2) {
                                            Text("\(totalPoints, format: .number.precision(.fractionLength(0)))")
                                                .font(.headline.weight(.semibold))
                                                .foregroundStyle(.green)
                                            Text("points")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .padding()
                                    .background(Color.green.opacity(0.1))
                                    .cornerRadius(8)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingStatementDetail) {
                if let statement = selectedStatement {
                    StatementDetailPopup(statement: statement, modelContext: modelContext) {
                        showingStatementDetail = false
                        selectedStatement = nil
                    }
                }
            }
        }
    }
}

// MARK: - Statement Detail Popup

struct StatementDetailPopup: View {
    let statement: Statement
    let modelContext: ModelContext
    let onClose: () -> Void
    
    @State private var showDeleteConfirm = false
    @State private var selectedRowID: PersistentIdentifier? = nil
    @State private var selectedCategory: String? = nil

    private static let statementMonthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM yyyy"
        return f
    }()
    
    private let availableCategories = [
        "Restaurants",
        "Supermarkets",
        "Flights",
        "Hotels",
        "Car Rentals",
        "Transit",
        "Streaming",
        "Fitness",
        "Entertainment",
        "Drugstore",
        "Gas Stations",
        "Travel",
        "Dining",
        "Apple",
        "Apple Pay",
        "Apple & Rotating",
        "Physical Card",
        "Other"
    ].sorted()
    
    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    onClose()
                }
            
            // Popup card
            VStack(spacing: 0) {
                // Header with close button
                HStack {
                    Text(statement.fileName)
                        .font(.headline.weight(.semibold))
                    Spacer()
                    Button {
                        onClose()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.gray)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(12, corners: [.topLeft, .topRight])
                
                Divider()
                
                // Scrollable content area with statement info and transactions
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 16) {
                        // Statement info
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Statement Month:")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(Self.statementMonthFormatter.string(from: statement.statementMonth))
                                    .font(.caption)
                            }

                            HStack {
                                Text("Uploaded:")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(statement.uploadDate, style: .date)
                                    .font(.caption)
                            }
                            
                            HStack {
                                Text("Transactions:")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(statement.rows.count)")
                                    .font(.caption)
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(8)
                        
                        // Itemized transactions
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Transactions")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            
                            VStack(spacing: 6) {
                                ForEach(statement.rows, id: \.id) { row in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(row.transactionDescription)
                                                .font(.caption.weight(.semibold))
                                            Text(row.transactionDate, style: .date)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        VStack(alignment: .trailing, spacing: 2) {
                                            Text("$\(String(format: "%.2f", row.amount))")
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(.blue)
                                            Button {
                                                selectedRowID = row.id
                                                selectedCategory = row.category
                                            } label: {
                                                Text(row.category)
                                                    .font(.caption2)
                                                    .foregroundStyle(.blue)
                                                    .underline()
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(Color.gray.opacity(0.05))
                                    .cornerRadius(6)
                                }
                            }
                        }
                        .padding()
                    }
                }
                
                Divider()
                
                // Action buttons
                HStack(spacing: 12) {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        HStack {
                            Image(systemName: "trash.fill")
                            Text("Delete")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.red.opacity(0.1))
                        .foregroundStyle(.red)
                        .cornerRadius(8)
                    }
                    
                    Button {
                        onClose()
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Done")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.blue.opacity(0.1))
                        .foregroundStyle(.blue)
                        .cornerRadius(8)
                    }
                }
                .padding()
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 10)
            .padding(24)
        }
        .confirmationDialog("Delete Statement?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                modelContext.delete(statement)
                try? modelContext.save()
                onClose()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this statement? This action cannot be undone.")
        }
        .sheet(item: $selectedRowID) { rowID in
            StatementRowCategoryEditor(
                statement: statement,
                rowID: rowID,
                availableCategories: availableCategories,
                modelContext: modelContext,
                onDismiss: { selectedRowID = nil }
            )
        }
    }
}

// MARK: - Category Picker Sheet

struct CategoryPickerSheet: View {
    let transaction: StatementRow
    let availableCategories: [String]
    let onSelect: (String) -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationStack {
            List(availableCategories, id: \.self) { category in
                CategoryPickerRow(
                    category: category,
                    isSelected: transaction.category == category,
                    onSelect: { onSelect(category) }
                )
            }
            .navigationTitle("Select Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Category Picker Row

struct CategoryPickerRow: View {
    let category: String
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                Text(category)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                }
            }
        }
        .foregroundStyle(.primary)
    }
}

// MARK: - Statement Row Category Editor

struct StatementRowCategoryEditor: View {
    let statement: Statement
    let rowID: PersistentIdentifier
    let availableCategories: [String]
    let modelContext: ModelContext
    let onDismiss: () -> Void
    
    var selectedRow: StatementRow? {
        statement.rows.first { $0.persistentModelID == rowID }
    }
    
    var body: some View {
        if let row = selectedRow {
            CategoryPickerSheet(
                transaction: row,
                availableCategories: availableCategories,
                onSelect: { newCategory in
                    row.category = newCategory
                    try? modelContext.save()
                    onDismiss()
                },
                onDismiss: onDismiss
            )
        }
    }
}

// MARK: - Points Category Row

struct PointsCategoryRow: View {
    let rate: EarningRate
    let points: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(rate.multiplier, format: .number)X - \(rate.category)")
                        .font(.subheadline.weight(.semibold))
                    Text(rate.description)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(points, format: .number.precision(.fractionLength(0)))")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.blue)
                    Text("points")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)
        }
    }
}

// MARK: - Corner Radius Extension

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect,
                                byRoundingCorners: corners,
                                cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

// MARK: - Flow Layout (wrapping HStack)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var x: CGFloat = 0, y: CGFloat = 0, maxHeight: CGFloat = 0, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 {
                y += rowHeight + spacing; x = 0; rowHeight = 0
            }
            rowHeight = max(rowHeight, size.height)
            maxHeight = max(maxHeight, y + rowHeight)
            x += size.width + spacing
        }
        return CGSize(width: width, height: maxHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                y += rowHeight + spacing; x = bounds.minX; rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
    }
}

#Preview {
    CardsView()
        .modelContainer(for: [UserCard.self, BenefitCompletion.self, Statement.self, StatementRow.self], inMemory: true)
}
