//
//  SettingsView.swift
//  Credit Card Benefit Tracker
//
//  Created by Jacob Michalik on 5/14/26.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var userCards: [UserCard]
    @State private var showNotificationPermissionAlert = false
    @State private var pendingCardForPermission: UserCard?
    @State private var showTutorial = false
    @State private var selectedCardForMissed: UserCard? = nil
@AppStorage("hasCompletedTutorial") private var hasCompletedTutorial = false
    @AppStorage("isRedoingTutorial") private var isRedoingTutorial = false
    
    var body: some View {
        NavigationStack {
            List {
                Section("Notifications") {
                    Text("Note: 'Missed' refers to benefits that were not completed before the end of their respective periods.")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 2)
                    notificationsSection
                }
                
                Section("Missed Benefits") {
                    ClearAllMissedButton(userCards: userCards, modelContext: modelContext)
                }

                Section("Help") {
                    Button(action: {
                        hasCompletedTutorial = false
                        isRedoingTutorial = true
                        showTutorial = true
                    }) {
                        HStack {
                            Image(systemName: "questionmark.circle.fill")
                                .foregroundStyle(.blue)
                            Text("Restart Tutorial")
                                .foregroundStyle(.primary)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showTutorial) {
                TutorialView()
            }
            .sheet(item: $selectedCardForMissed) { card in
                MissedBenefitsSheet(card: card)
            }
        }
    }
    
    private var notificationsSection: some View {
        VStack(spacing: 16) {
            // Master toggle for all notifications
            Toggle("Enable Notifications", isOn: Binding(
                get: { userCards.contains { $0.notificationsEnabled } },
                set: { newValue in
                    for card in userCards {
                        card.notificationsEnabled = newValue
                    }
                    NotificationScheduler.scheduleAll(userCards: userCards)
                }
            ))
            
            if !userCards.isEmpty {
                Divider()
                
                Text("Notifications by Card")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                
                // Per-card notification toggles
                VStack(spacing: 12) {
                    ForEach(userCards) { card in
                        cardNotificationRow(card: card)
                    }
                }
            }
            
            Text("Notifications:")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 8)
            
            VStack(alignment: .leading, spacing: 8) {
                Label(
                    "1st notification at the start of each benefit period",
                    systemImage: "bell.fill"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                
                Label(
                    "2nd notification in the last 25% of the period if benefit uncompleted",
                    systemImage: "bell.and.waveform.fill"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 8)
    }
    
    private func cardNotificationRow(card: UserCard) -> some View {
        let totalMissed = card.completions.reduce(0) { $0 + $1.missedCount }
        
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(card.name)
                    .font(.subheadline.weight(.semibold))
                Text(card.issuer)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Fixed-width container for badge and toggle
            HStack(spacing: 20) {
                // Missed count badge (tappable)
                Button {
                    selectedCardForMissed = card
                } label: {
                    VStack(spacing: 1) {
                        Text("\(totalMissed)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                        Text("Missed")
                            .font(.caption2)
                            .foregroundStyle(.white)
                    }
                    .frame(width: 55)
                    .padding(.vertical, 6)
                    .background(totalMissed > 0 ? Color.red : Color.gray)
                    .cornerRadius(6)
                }
                
                Toggle("", isOn: Binding(
                    get: { card.notificationsEnabled },
                    set: { newValue in
                        card.notificationsEnabled = newValue
                        NotificationScheduler.scheduleAll(userCards: userCards)
                    }
                ))
                .frame(width: 50)
            }
        }
        .padding(.vertical, 8)
    }
}

struct MissedBenefitsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let card: UserCard

    private var missedBenefits: [(name: String, count: Int)] {
        card.completions
            .filter { $0.missedCount > 0 }
            .map { (name: $0.benefitName, count: $0.missedCount) }
            .sorted { $0.count > $1.count }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Missed Benefits")
                        .font(.headline)
                    Text(card.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()

            Divider()

            if missedBenefits.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.green)
                    Text("No missed benefits!")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(missedBenefits, id: \.name) { item in
                            HStack {
                                Text(item.name)
                                    .font(.subheadline)
                                Spacer()
                                Text("×\(item.count)")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.red)
                                    .clipShape(Capsule())
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 12)
                            Divider().padding(.leading)
                        }
                    }
                    .padding(.top, 4)
                }

                Divider()

                Button {
                    for completion in card.completions {
                        completion.missedCount = 0
                    }
                    try? modelContext.save()
                    dismiss()
                } label: {
                    Text("Clear and Close")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.red)
                        .cornerRadius(12)
                        .padding()
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

struct ClearAllMissedButton: View {
    let userCards: [UserCard]
    let modelContext: ModelContext
    @State private var showSheet = false

    var body: some View {
        Button {
            showSheet = true
        } label: {
            HStack {
                Image(systemName: "xmark.seal.fill")
                    .foregroundStyle(.red)
                Text("Clear All Missed Badges")
                    .foregroundStyle(.primary)
            }
        }
        .sheet(isPresented: $showSheet) {
            ClearAllMissedSheet(userCards: userCards, modelContext: modelContext)
        }
    }
}

struct ClearAllMissedSheet: View {
    @Environment(\.dismiss) private var dismiss
    let userCards: [UserCard]
    let modelContext: ModelContext

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Clear All Missed Badges")
                    .font(.headline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()

            Divider()

            VStack(spacing: 16) {
                Image(systemName: "xmark.seal.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.red)
                    .padding(.top, 8)

                Text("This will reset all missed benefit counts to 0 across every card.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Text("This cannot be undone.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.red)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            Button {
                for card in userCards {
                    for completion in card.completions {
                        completion.missedCount = 0
                    }
                }
                try? modelContext.save()
                dismiss()
            } label: {
                Text("Clear All and Close")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.red)
                    .cornerRadius(12)
                    .padding()
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [UserCard.self, NotificationSettings.self], inMemory: true)
}
