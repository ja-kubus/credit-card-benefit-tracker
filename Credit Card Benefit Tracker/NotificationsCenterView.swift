//
//  NotificationsCenterView.swift
//  Credit Card Benefit Tracker
//

import SwiftUI
import SwiftData

struct NotificationsCenterView: View {
    let userCards: [UserCard]

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \AppNotification.createdAt, order: .reverse) private var events: [AppNotification]
    @State private var reminders: [NotificationScheduler.TriggeredNotification] = []

    var body: some View {
        Group {
            if events.isEmpty && reminders.isEmpty {
                ContentUnavailableView(
                    "No Notifications",
                    systemImage: "bell.slash",
                    description: Text("Alerts (like completing a period's benefits or recouping a fee) and benefit reminders will appear here.")
                )
            } else {
                List {
                    if !events.isEmpty {
                        Section("Alerts") {
                            ForEach(events) { event in
                                eventRow(event)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            delete(event)
                                        } label: {
                                            Label("Clear", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                    }

                    if !reminders.isEmpty {
                        Section("Reminders") {
                            ForEach(reminders) { reminder in
                                reminderRow(reminder)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button {
                                            acknowledge(reminder)
                                        } label: {
                                            Label("Clear", systemImage: "checkmark")
                                        }
                                        .tint(Color.appLeaf)
                                    }
                            }
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
                        Label("Clear All", systemImage: "trash")
                    }
                    .disabled(events.isEmpty && reminders.isEmpty)

                    Button {
                        showClearedReminders()
                    } label: {
                        Label("Show Cleared Reminders", systemImage: "arrow.counterclockwise")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(Color.appCoral)
                }
            }
        }
        .onAppear {
            reminders = NotificationScheduler.triggeredNotifications(userCards: userCards)
            markEventsRead()
        }
    }

    // MARK: - Rows

    private func eventRow(_ event: AppNotification) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: event.kind == "feeRecouped" ? "creditcard.fill" : "checkmark.seal.fill")
                .font(.title3)
                .foregroundStyle(Color.appLeaf)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.subheadline.weight(.semibold))
                Text(event.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(event.createdAt.formatted(.relative(presentation: .named)))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 8)
            if !event.isRead {
                Circle().fill(Color.appCoral).frame(width: 8, height: 8).padding(.top, 6)
            }
        }
        .padding(.vertical, 4)
    }

    private func reminderRow(_ reminder: NotificationScheduler.TriggeredNotification) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "bell.badge")
                .font(.title3)
                .foregroundStyle(Color.appBell)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                Text(reminder.title)
                    .font(.subheadline.weight(.semibold))
                Text(reminder.body)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(reminder.firedDate.formatted(.relative(presentation: .named)))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Actions

    private func markEventsRead() {
        var changed = false
        for event in events where !event.isRead {
            event.isRead = true
            changed = true
        }
        if changed { try? modelContext.save() }
    }

    private func delete(_ event: AppNotification) {
        withAnimation {
            modelContext.delete(event)
            try? modelContext.save()
        }
    }

    private func acknowledge(_ reminder: NotificationScheduler.TriggeredNotification) {
        NotificationScheduler.acknowledge(NotificationScheduler.compositeKey(for: reminder))
        withAnimation {
            reminders.removeAll { $0.id == reminder.id && $0.firedDate == reminder.firedDate }
        }
    }

    private func clearAll() {
        withAnimation {
            for event in events { modelContext.delete(event) }
            try? modelContext.save()
            let keys = reminders.map { NotificationScheduler.compositeKey(for: $0) }
            NotificationScheduler.acknowledgeAll(keys)
            reminders = []
        }
    }

    private func showClearedReminders() {
        NotificationScheduler.unacknowledgeAll()
        withAnimation {
            reminders = NotificationScheduler.triggeredNotifications(userCards: userCards)
        }
    }
}
