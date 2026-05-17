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
            }
            .navigationTitle("Settings")
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
                // Missed count badge (always show)
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
                
                Toggle("", isOn: Binding(
                    get: { card.notificationsEnabled },
                    set: { newValue in
                        card.notificationsEnabled = newValue
                    }
                ))
                .frame(width: 50)
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [UserCard.self, NotificationSettings.self], inMemory: true)
}
