//
//  NotificationPermissionView.swift
//  Credit Card Benefit Tracker
//
//  Created by Jacob Michalik on 5/14/26.
//

import SwiftUI

struct NotificationPermissionView: View {
    let cardName: String
    let cardIssuer: String
    let onAllow: (Bool) -> Void // bool is "remember for future cards"
    let onDeny: () -> Void
    
    @State private var rememberSelection = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Header icon
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 48))
                .foregroundStyle(.blue)
                .padding(.top, 20)
            
            // Title and message
            VStack(spacing: 8) {
                Text("Enable Notifications?")
                    .font(.title2.weight(.semibold))
                
                Text("Get notified when \(cardIssuer) \(cardName) benefits are about to expire")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)
            
            // Notification details
            VStack(alignment: .leading, spacing: 12) {
                Label(
                    "Reminder at the start of each benefit period",
                    systemImage: "bell.fill"
                )
                .font(.caption)
                
                Label(
                    "Reminder in the last 25% of the period if uncompleted",
                    systemImage: "bell.and.waveform.fill"
                )
                .font(.caption)
            }
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .padding(.horizontal)
            
            // Remember checkbox
            Toggle("Remember this selection for future cards", isOn: $rememberSelection)
                .font(.caption)
                .padding(.horizontal)
            
            Spacer()
            
            // Buttons
            VStack(spacing: 12) {
                Button {
                    onAllow(rememberSelection)
                } label: {
                    Text("Enable Notifications")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .cornerRadius(8)
                }
                
                Button {
                    onDeny()
                } label: {
                    Text("Don't Enable")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .background(Color(.systemGray5))
                        .foregroundStyle(.primary)
                        .cornerRadius(8)
                }
            }
            .padding()
        }
        .background(Color(.systemBackground))
    }
}

#Preview {
    NotificationPermissionView(
        cardName: "Platinum Card",
        cardIssuer: "American Express",
        onAllow: { _ in },
        onDeny: { }
    )
}
