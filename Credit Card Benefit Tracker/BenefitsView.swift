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

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                periodPicker
                    .padding(.horizontal)
                    .padding(.top, 8)

                Divider().padding(.top, 8)

                benefitsList
            }
            .navigationTitle("Benefits")
            .onAppear { resetExpiredCompletions() }
        }
    }

    // MARK: - Period Picker

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
                                        completion: item.completion
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
    }

    private func benefitItemsByCategory(for period: BenefitPeriod) -> [BenefitCategory: [BenefitItem]] {
        var result: [BenefitCategory: [BenefitItem]] = [:]
        
        // Initialize all categories
        for category in BenefitCategory.allCases {
            result[category] = []
        }
        
        for card in userCards {
            guard let catalog = CreditCardCatalog.all.first(where: { $0.id == card.catalogCardID }) else { continue }
            let periodBenefits = catalog.benefits.filter { $0.period == period }
            for benefit in periodBenefits {
                // Try to find existing completion
                var comp = card.completions.first(where: { $0.benefitName == benefit.name && $0.benefitPeriod == period })
                
                // If no completion exists, create one (handles cases where benefits were added after card was added)
                if comp == nil {
                    let newCompletion = BenefitCompletion(cardID: card.catalogCardID, benefit: benefit)
                    modelContext.insert(newCompletion)
                    card.completions.append(newCompletion)
                    comp = newCompletion
                }
                
                if let comp = comp {
                    let item = BenefitItem(cardName: card.name, benefit: benefit, completion: comp)
                    result[benefit.category, default: []].append(item)
                }
            }
        }
        
        // Sort within each category by card name
        for (key, var items) in result {
            items.sort { $0.cardName < $1.cardName }
            result[key] = items
        }
        
        return result
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
                        .foregroundStyle(completion.isCompleted ? .green : .secondary)
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
                            .foregroundStyle(completion.hasAnyUsage ? .green : .secondary)
                    }
                }
                .opacity(completion.isIgnored ? 0.5 : 1.0)
                
                Text(cardName)
                    .font(.caption)
                    .foregroundStyle(.blue)
                    .opacity(completion.isIgnored ? 0.5 : 1.0)
                
                Text(catalogBenefit.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(completion.isIgnored ? 0.5 : 1.0)

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
                                    .foregroundStyle(.blue)
                                
                                Button {
                                    completion.partialUsage = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
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
            .tint(completion.isIgnored ? .blue : .orange)
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
                                    .foregroundStyle(.green)
                                    .font(.caption)
                            } else {
                                Label("Partial usage recorded", systemImage: "info.circle")
                                    .foregroundStyle(.blue)
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
                            .foregroundStyle(.blue)
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

#Preview {
    BenefitsView()
        .modelContainer(for: [UserCard.self, BenefitCompletion.self], inMemory: true)
}
