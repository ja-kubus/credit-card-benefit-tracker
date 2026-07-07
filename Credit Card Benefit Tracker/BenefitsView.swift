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
    @State private var selectedCardIds: Set<PersistentIdentifier> = []
    @State private var showCardFilter = false
    @State private var searchText = ""
    // Precomputed statement match cache: "cardCatalogID|benefitName" -> Bool
    @State private var statementMatchCache: Set<String> = []

    // MARK: - Computed Properties

    var totalValueRemaining: Double {
        let cardsToShow = selectedCardIds.isEmpty ? Set<PersistentIdentifier>() : selectedCardIds
        var total: Double = 0
        for card in userCards {
            guard cardsToShow.contains(card.persistentModelID) else { continue }
            guard let catalog = CreditCardCatalog.all.first(where: { $0.id == card.catalogCardID }) else { continue }
            let periodBenefits = catalog.benefits.filter { $0.period == selectedPeriod }
            for benefit in periodBenefits {
                guard benefit.dollarAmount > 0 else { continue }
                let comp = card.completions.first(where: { $0.benefitName == benefit.name && $0.benefitPeriod == selectedPeriod })
                if let comp = comp {
                    if !comp.isCompleted && !comp.isIgnored {
                        total += benefit.dollarAmount
                    }
                } else {
                    total += benefit.dollarAmount
                }
            }
        }
        return total
    }

    struct ExpiringItem {
        let cardName: String
        let completion: BenefitCompletion
    }

    var expiringBenefits: [ExpiringItem] {
        let cardsToShow = selectedCardIds.isEmpty ? Set<PersistentIdentifier>() : selectedCardIds
        let now = Date()
        let sevenDaysLater = now.addingTimeInterval(7 * 24 * 60 * 60)
        var items: [ExpiringItem] = []
        for card in userCards {
            guard cardsToShow.contains(card.persistentModelID) else { continue }
            for comp in card.completions {
                guard !comp.isCompleted,
                      !comp.isIgnored,
                      comp.dollarAmount > 0,
                      comp.resetDate > now,
                      comp.resetDate <= sevenDaysLater else { continue }
                items.append(ExpiringItem(cardName: card.name, completion: comp))
            }
        }
        return items.sorted { $0.completion.resetDate < $1.completion.resetDate }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Card filtering dropdown
                VStack(spacing: 12) {
                    HStack {
                        Text("Filter by Card")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        Button {
                            showCardFilter = true
                        } label: {
                            HStack {
                                let selectedCount = selectedCardIds.isEmpty ? userCards.count : selectedCardIds.count
                                let totalCount = userCards.count
                                Text("\(selectedCount) of \(totalCount) cards")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.appCoral)
                                
                                Image(systemName: "chevron.down")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 12)
                .background(Color(.secondarySystemGroupedBackground))
                .sheet(isPresented: $showCardFilter) {
                    CardFilterSheet(selectedCardIds: $selectedCardIds, userCards: userCards, isPresented: $showCardFilter)
                }

                expiringSoonStrip

                if totalValueRemaining > 0 {
                    valueRemainingBanner
                        .padding(.horizontal)
                        .padding(.top, 8)
                }

                periodPicker
                    .padding(.horizontal)
                    .padding(.top, 8)

                Divider().padding(.top, 8)

                benefitsList
            }
            .navigationTitle("Benefits")
            .searchable(text: $searchText, prompt: "Search benefits...")
            .onAppear {
                ensureCompletionsExist()
                resetExpiredCompletions()
                rebuildStatementMatchCache()
                // Initialize with all cards selected
                if selectedCardIds.isEmpty {
                    selectedCardIds = Set(userCards.map { $0.persistentModelID })
                }
            }
            // Observe a fingerprint including statement counts — @Query arrays compare
            // by identity, so appending a Statement alone wouldn't trigger onChange.
            .onChange(of: userCards.map { "\($0.persistentModelID)|\($0.statements.count)" }) { _, _ in
                rebuildStatementMatchCache()
            }
        }
    }

    // MARK: - Period Picker

    private var valueRemainingBanner: some View {
        let itemsByCategory = benefitItemsByCategory(for: selectedPeriod)
        // Count only unclaimed benefits that contribute to the dollar figure
        let benefitCount = itemsByCategory.values.reduce(0) { sum, items in
            sum + items.filter { $0.benefit.dollarAmount > 0 && !$0.completion.isCompleted && !$0.completion.isIgnored }.count
        }

        return HStack(spacing: 12) {
            Image(systemName: "dollarsign.circle.fill")
                .font(.title2)
                .foregroundStyle(Color.appLeaf)

            VStack(alignment: .leading, spacing: 2) {
                Text("$\(Int(totalValueRemaining)) remaining this period")
                    .font(.subheadline.weight(.bold))
                Text("across \(benefitCount) benefit\(benefitCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(12)
        .background(Color.appSage.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var expiringSoonStrip: some View {
        Group {
            if !expiringBenefits.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Expiring Soon")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                        .padding(.horizontal)
                        .padding(.top, 8)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(expiringBenefits.indices, id: \.self) { index in
                                let item = expiringBenefits[index]
                                expiringChip(item: item)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                    }
                }
                .background(Color.orange.opacity(0.07))
            }
        }
    }

    private func expiringChip(item: ExpiringItem) -> some View {
        let now = Date()
        let days = Calendar.current.dateComponents([.day], from: now, to: item.completion.resetDate).day ?? 0
        let countdownText = days == 0 ? "Today" : (days == 1 ? "1 day" : "\(days) days")

        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "clock.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                Text(countdownText)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.orange)
            }
            Text(item.completion.benefitName)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
            Text(item.cardName)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }

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
                                        completion: item.completion,
                                        hasStatementMatch: hasStatementMatch(for: item.completion, card: item.card)
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
        let card: UserCard
    }

    // MARK: - Statement Match Detection

    // O(1) lookup during render — rebuilt only when cards/statements change
    func hasStatementMatch(for completion: BenefitCompletion, card: UserCard) -> Bool {
        statementMatchCache.contains("\(card.catalogCardID)|\(completion.benefitName)")
    }

    private func rebuildStatementMatchCache() {
        var cache: Set<String> = []

        for card in userCards {
            guard !card.statements.isEmpty else { continue }
            let allRows = card.statements.flatMap { $0.rows }

            for completion in card.completions {
                guard !completion.isCompleted, !completion.isIgnored, completion.dollarAmount > 0 else { continue }

                let periodDays: Double
                switch completion.benefitPeriod {
                case .monthly:      periodDays = 30
                case .quarterly:    periodDays = 90
                case .semiAnnually: periodDays = 180
                case .annually:     periodDays = 365
                }
                let periodStart = completion.resetDate.addingTimeInterval(-periodDays * 86400)
                let rows = allRows.filter { $0.transactionDate >= periodStart && $0.transactionDate < completion.resetDate }
                guard !rows.isEmpty else { continue }

                let nameLower = completion.benefitName.lowercased()
                let descLower = completion.benefitDescription.lowercased()
                let catalogBenefit = CreditCardCatalog.all
                    .first(where: { $0.id == card.catalogCardID })?
                    .benefits.first(where: { $0.name == completion.benefitName })

                let matched = rows.contains { row in
                    let txDesc = row.transactionDescription.lowercased()
                    let txCat  = row.category
                    if (nameLower.contains("uber") || descLower.contains("uber")) && txDesc.contains("uber") { return true }
                    if (nameLower.contains("lyft") || descLower.contains("lyft")) && txDesc.contains("lyft") { return true }
                    if nameLower.contains("dining") || descLower.contains("dining") || catalogBenefit?.category == .dining {
                        if txCat == "Restaurants" { return true }
                    }
                    if nameLower.contains("airline") || nameLower.contains("flight") ||
                       descLower.contains("airline") || descLower.contains("flight") ||
                       catalogBenefit?.category == .travel {
                        if txCat == "Flights" || txCat == "Airlines" { return true }
                    }
                    if (nameLower.contains("hotel") || nameLower.contains("resort") ||
                        descLower.contains("hotel") || descLower.contains("resort")) && txCat == "Hotels" { return true }
                    if (nameLower.contains("streaming") || descLower.contains("streaming")) && txCat == "Streaming" { return true }
                    if (nameLower.contains("grocery") || nameLower.contains("supermarket") ||
                        descLower.contains("grocery") || descLower.contains("supermarket")) && txCat == "Supermarkets" { return true }
                    if (nameLower.contains("gas") || descLower.contains("gas")) && txCat == "Gas Stations" { return true }
                    if (nameLower.contains("transit") || nameLower.contains("commut") ||
                        descLower.contains("transit") || descLower.contains("commut")) && txCat == "Transit" { return true }
                    return false
                }
                if matched {
                    cache.insert("\(card.catalogCardID)|\(completion.benefitName)")
                }
            }
        }
        statementMatchCache = cache
    }

    private func benefitItemsByCategory(for period: BenefitPeriod) -> [BenefitCategory: [BenefitItem]] {
        var result: [BenefitCategory: [BenefitItem]] = [:]
        
        // Initialize all categories
        for category in BenefitCategory.allCases {
            result[category] = []
        }
        
        // If no cards selected, show nothing. Otherwise show selected cards.
        let cardsToShow = selectedCardIds.isEmpty ? Set<PersistentIdentifier>() : selectedCardIds
        
        for card in userCards {
            guard cardsToShow.contains(card.persistentModelID) else { continue }
            guard let catalog = CreditCardCatalog.all.first(where: { $0.id == card.catalogCardID }) else { continue }
            let periodBenefits = catalog.benefits.filter { $0.period == period }
            for benefit in periodBenefits {
                guard let comp = card.completions.first(where: { $0.benefitName == benefit.name && $0.benefitPeriod == period }) else { continue }
                let item = BenefitItem(cardName: card.name, benefit: benefit, completion: comp, card: card)
                result[benefit.category, default: []].append(item)
            }
        }
        
        // Sort within each category by card name
        for (key, var items) in result {
            items.sort { $0.cardName < $1.cardName }
            result[key] = items
        }

        // Apply search filter
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            for (key, items) in result {
                result[key] = items.filter { item in
                    item.benefit.name.lowercased().contains(query) ||
                    item.benefit.description.lowercased().contains(query) ||
                    item.cardName.lowercased().contains(query)
                }
            }
        }

        return result
    }

    private func ensureCompletionsExist() {
        for card in userCards {
            guard let catalog = CreditCardCatalog.all.first(where: { $0.id == card.catalogCardID }) else { continue }
            for benefit in catalog.benefits {
                let exists = card.completions.contains { $0.benefitName == benefit.name && $0.benefitPeriod == benefit.period }
                if !exists {
                    let newCompletion = BenefitCompletion(cardID: card.catalogCardID, benefit: benefit)
                    modelContext.insert(newCompletion)
                    card.completions.append(newCompletion)
                }
            }
        }
    }

    private func resetExpiredCompletions() {
        for completion in completions {
            completion.resetIfNeeded()
        }
    }
}

struct BenefitRow: View {
    let cardName: String
    let catalogBenefit: CatalogBenefit
    @Bindable var completion: BenefitCompletion
    var hasStatementMatch: Bool = false
    @State private var showPartialUsageInput = false
    @State private var showAnniversaryDatePicker = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Checkbox or locked icon
            if completion.isIgnored {
                Image(systemName: "lock.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            } else {
                Button {
                    completion.isCompleted.toggle()
                    completion.partialUsage = ""  // Clear partial usage when toggling completed
                } label: {
                    Image(systemName: completion.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(completion.isCompleted ? Color.appLeaf : .secondary)
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(catalogBenefit.name)
                        .font(.subheadline.weight(.semibold))
                        .strikethrough(completion.isCompleted || completion.isIgnored, color: .secondary)
                    Spacer()
                    if catalogBenefit.dollarAmount > 0 {
                        Text(catalogBenefit.dollarAmount, format: .currency(code: "USD"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(completion.hasAnyUsage ? Color.appLeaf : .secondary)
                    }
                }
                .opacity(completion.isIgnored ? 0.5 : 1.0)
                
                Text(cardName)
                    .font(.caption)
                    .foregroundStyle(Color.appCoral)
                    .opacity(completion.isIgnored ? 0.5 : 1.0)
                
                Text(catalogBenefit.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(completion.isIgnored ? 0.5 : 1.0)

                if hasStatementMatch && !completion.isCompleted && !completion.isIgnored {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.text.magnifyingglass")
                        Text("Transaction detected — did you use this?")
                    }
                    .font(.caption2)
                    .foregroundStyle(.orange)
                }

                // Anniversary date editor for annual benefits
                if completion.benefitPeriod == .annually && !completion.isIgnored {
                    VStack(alignment: .leading, spacing: 6) {
                        if let startDate = completion.benefitStartDate {
                            HStack(spacing: 4) {
                                Image(systemName: "calendar")
                                    .font(.caption2)
                                Text("Anniversary: \(startDate, style: .date)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.purple)
                                
                                Button {
                                    completion.benefitStartDate = nil
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                                Spacer()
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.purple.opacity(0.1))
                            .cornerRadius(6)
                        }
                        
                        Button {
                            showAnniversaryDatePicker = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: completion.benefitStartDate == nil ? "plus.circle" : "pencil.circle")
                                    .font(.caption2)
                                Text(completion.benefitStartDate == nil ? "Set anniversary date" : "Edit anniversary date")
                                    .font(.caption)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(6)
                            .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .sheet(isPresented: $showAnniversaryDatePicker) {
                        AnniversaryDatePickerView(
                            completion: completion,
                            isPresented: $showAnniversaryDatePicker
                        )
                    }
                }

                // Partial usage display and input
                if catalogBenefit.dollarAmount > 0 && !completion.isIgnored {
                    VStack(alignment: .leading, spacing: 6) {
                        if !completion.partialUsage.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "square.and.pencil")
                                    .font(.caption2)
                                Text("Used: $\(completion.partialUsage)/$\(Int(catalogBenefit.dollarAmount))")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.appGiraffe)
                                
                                Button {
                                    completion.partialUsage = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                                Spacer()
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.appGiraffe.opacity(0.12))
                            .cornerRadius(6)
                        }
                        
                        Button {
                            showPartialUsageInput = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus.circle")
                                    .font(.caption2)
                                Text("Add partial usage")
                                    .font(.caption)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(6)
                            .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .sheet(isPresented: $showPartialUsageInput) {
                        PartialUsageInputView(
                            completion: completion,
                            maxAmount: Int(catalogBenefit.dollarAmount),
                            isPresented: $showPartialUsageInput
                        )
                    }
                }

                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption2)
                    Text("Resets \(completion.resetDate, style: .date)")
                        .font(.caption2)
                }
                .foregroundStyle(.tertiary)
                .opacity(completion.isIgnored ? 0.5 : 1.0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
        .opacity(completion.isIgnored ? 0.6 : 1.0)
        .background(completion.isIgnored ? Color.gray.opacity(0.1) : .clear)
        .cornerRadius(8)
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button {
                withAnimation {
                    completion.isIgnored.toggle()
                }
            } label: {
                Label(
                    completion.isIgnored ? "Track" : "Ignore",
                    systemImage: completion.isIgnored ? "bell" : "bell.slash"
                )
            }
            .tint(completion.isIgnored ? Color.appCoral : Color.orange)
        }
    }
}

// MARK: - Partial Usage Input Sheet

struct PartialUsageInputView: View {
    @Bindable var completion: BenefitCompletion
    let maxAmount: Int
    @Binding var isPresented: Bool
    @State private var inputValue: String = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("Partial Usage") {
                    HStack {
                        Text("$")
                            .font(.headline)
                        TextField("Amount used", text: $inputValue)
                            .keyboardType(.decimalPad)
                            .focused($isInputFocused)
                        Text("/ $\(maxAmount)")
                            .foregroundStyle(.secondary)
                    }
                    
                    if !inputValue.isEmpty, let amount = Double(inputValue), amount > 0 {
                        HStack {
                            Text("Usage: \(Int(amount * 100.0 / Double(maxAmount)))%")
                                .font(.caption)
                            Spacer()
                            if amount >= Double(maxAmount) {
                                Label("Full credit available!", systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(Color.appLeaf)
                                    .font(.caption)
                            } else {
                                Label("Partial usage recorded", systemImage: "info.circle")
                                    .foregroundStyle(Color.appGiraffe)
                                    .font(.caption)
                            }
                        }
                        .padding(.top, 4)
                    }
                }
                
                Section {
                    Text("Any amount of usage will prevent this benefit from being marked as missed. You can track partial redemption here for reference.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Record Usage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if !inputValue.isEmpty {
                            completion.partialUsage = inputValue
                            completion.isCompleted = false
                        }
                        isPresented = false
                    }
                    .disabled(inputValue.isEmpty || (Double(inputValue) ?? 0) <= 0)
                }
            }
            .onAppear {
                inputValue = completion.partialUsage
                isInputFocused = true
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Anniversary Date Picker

struct AnniversaryDatePickerView: View {
    @Bindable var completion: BenefitCompletion
    @Binding var isPresented: Bool
    @State private var selectedDate: Date = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("Set Anniversary Date") {
                    DatePicker(
                        "Anniversary Date",
                        selection: $selectedDate,
                        displayedComponents: .date
                    )
                    
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(Color.appGiraffe)
                            .font(.caption)
                        Text("Benefits renew on this date each year")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)
                }
                
                Section("Example") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("If anniversary is Dec 15:")
                            .font(.caption.weight(.semibold))
                        Text("• Current year: Dec 15")
                            .font(.caption)
                        Text("• Next year: Dec 15")
                            .font(.caption)
                        Text("• And so on...")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Annual Benefit Anniversary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        completion.benefitStartDate = selectedDate
                        // Recalculate the reset date based on the new anniversary
                        if completion.benefitPeriod == .annually {
                            completion.resetDate = completion.getNextAnniversaryDate()
                        }
                        isPresented = false
                    }
                }
            }
            .onAppear {
                selectedDate = completion.benefitStartDate ?? Date()
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Card Filter Sheet

struct CardFilterSheet: View {
    @Binding var selectedCardIds: Set<PersistentIdentifier>
    let userCards: [UserCard]
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Select All / Deselect All buttons at top
                HStack(spacing: 12) {
                    Button(action: {
                        selectedCardIds = Set(userCards.map { $0.persistentModelID })
                    }) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption.weight(.semibold))
                            Text("Select All")
                                .font(.subheadline.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.appCoral)
                        .foregroundStyle(.white)
                        .cornerRadius(8)
                    }
                    
                    Button(action: {
                        selectedCardIds.removeAll()
                    }) {
                        HStack {
                            Image(systemName: "circle")
                                .font(.caption.weight(.semibold))
                            Text("Deselect All")
                                .font(.subheadline.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.gray.opacity(0.3))
                        .foregroundStyle(.gray)
                        .cornerRadius(8)
                    }
                }
                .padding(12)
                
                Divider()
                
                // Card list
                List {
                    // Group cards by issuer
                    let cardsByIssuer = Dictionary(grouping: userCards) { $0.issuer }
                    let sortedIssuers = cardsByIssuer.keys.sorted()
                    
                    ForEach(sortedIssuers, id: \.self) { issuer in
                        Section(issuer) {
                            ForEach(cardsByIssuer[issuer] ?? [], id: \.persistentModelID) { card in
                                let isSelected = selectedCardIds.contains(card.persistentModelID)
                                
                                Button(action: {
                                    if isSelected {
                                        selectedCardIds.remove(card.persistentModelID)
                                    } else {
                                        selectedCardIds.insert(card.persistentModelID)
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(isSelected ? Color.appCoral : Color.gray)
                                        Text(card.name)
                                            .foregroundStyle(.primary)
                                        Spacer()
                                    }
                                    .frame(maxWidth: .infinity)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Filter by Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    BenefitsView()
        .modelContainer(for: [UserCard.self, BenefitCompletion.self], inMemory: true)
}
