//
//  NotificationsCenterView.swift
//  Credit Card Benefit Tracker
//

import SwiftUI

struct NotificationsCenterView: View {
    let userCards: [UserCard]

    @State private var notifications: [NotificationScheduler.TriggeredNotification] = []

    var body: some View {
        Group {
            if notifications.isEmpty {
                ContentUnavailableView(
                    "No Notifications",
                    systemImage: "bell.slash",
                    description: Text("Benefit reminders that have fired will appear here.")
                )
            } else {
                List {
                    ForEach(notifications) { notification in
                        row(for: notification)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button {
                                    acknowledge(notification)
                                } label: {
                                    Label("Clear", systemImage: "checkmark")
                                }
                                .tint(Color.appLeaf)
                            }
                    }
                }
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        clearAll()
                    } label: {
                        Label("Clear All", systemImage: "checkmark.circle")
                    }
                    .disabled(notifications.isEmpty)

                    Button {
                        showCleared()
                    } label: {
                        Label("Show Cleared", systemImage: "arrow.counterclockwise")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(Color.appCoral)
                }
            }
        }
        .onAppear(perform: reload)
    }

    private func row(for notification: NotificationScheduler.TriggeredNotification) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "bell.badge")
                .font(.title3)
                .foregroundStyle(Color.appBell)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(notification.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(notification.body)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(notification.firedDate.formatted(.relative(presentation: .named)))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 8)

            Button {
                acknowledge(notification)
            } label: {
                Image(systemName: "checkmark.circle")
                    .font(.title3)
                    .foregroundStyle(Color.appCoral)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Actions

    private func reload() {
        notifications = NotificationScheduler.triggeredNotifications(userCards: userCards)
    }

    private func acknowledge(_ notification: NotificationScheduler.TriggeredNotification) {
        NotificationScheduler.acknowledge(NotificationScheduler.compositeKey(for: notification))
        withAnimation {
            notifications.removeAll { $0.id == notification.id && $0.firedDate == notification.firedDate }
        }
    }

    private func clearAll() {
        let keys = notifications.map { NotificationScheduler.compositeKey(for: $0) }
        NotificationScheduler.acknowledgeAll(keys)
        withAnimation {
            notifications = []
        }
    }

    private func showCleared() {
        NotificationScheduler.unacknowledgeAll()
        withAnimation {
            reload()
        }
    }
}
