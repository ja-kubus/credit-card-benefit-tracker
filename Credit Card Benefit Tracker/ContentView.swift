//
//  ContentView.swift
//  Credit Card Benefit Tracker
//
//  Created by Jacob Michalik on 4/20/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @AppStorage("hasCompletedTutorial") private var hasCompletedTutorial = false
    @AppStorage("didNormalizeStatementNames") private var didNormalizeStatementNames = false
    @AppStorage("didCleanupSummaryRows") private var didCleanupSummaryRows = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @Query private var userCards: [UserCard]
    @Query private var completions: [BenefitCompletion]

    /// One-time migration: rename statements uploaded before names were
    /// normalized to the uniform "<catalogCardID>_<issuer>_<Mon yyyy>" format.
    private func normalizeExistingStatementNames() {
        guard !didNormalizeStatementNames else { return }
        let all = (try? modelContext.fetch(FetchDescriptor<Statement>())) ?? []
        for statement in all {
            statement.fileName = StatementUploadSheet.normalizedStatementName(
                catalogCardID: statement.cardID,
                issuer: statement.issuers,
                month: statement.statementMonth
            )
        }
        try? modelContext.save()
        didNormalizeStatementNames = true
    }

    /// One-time cleanup: delete statement rows that were logged as transactions
    /// before summary lines like "New Balance" were filtered out at parse time.
    private func cleanupSummaryTransactionRows() {
        guard !didCleanupSummaryRows else { return }
        let rows = (try? modelContext.fetch(FetchDescriptor<StatementRow>())) ?? []
        var removed = 0
        for row in rows where StatementParser.isSummaryLine(row.transactionDescription) {
            modelContext.delete(row)
            removed += 1
        }
        if removed > 0 { try? modelContext.save() }
        didCleanupSummaryRows = true
    }

    @State private var widgetSyncTask: Task<Void, Never>? = nil
    @State private var notifRescheduleTask: Task<Void, Never>? = nil

    /// Debounced so rapid benefit toggles trigger one reschedule, not one per tap.
    /// Ensures completing a benefit cancels its pending "expiring soon" reminder.
    private func debouncedNotificationReschedule() {
        notifRescheduleTask?.cancel()
        notifRescheduleTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            NotificationScheduler.scheduleAll(userCards: userCards)
        }
    }
    // item-based sheet payloads: the sheet content receives its data directly,
    // so the sheet can never render blank while a separate @State is still empty
    // (the cold-launch-after-share race).
    @State private var sharedImportPayload: SharedImportPayload? = nil
    @State private var showSharedUploadSheet = false

    private func checkSharedInbox() {
        // On a cold launch the view isn't attached yet (an immediate sheet
        // presentation gets dropped), and the Share Extension may still be
        // finishing its file copy when the app foregrounds. One delayed check +
        // one retry covers both races.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            presentSharedInboxIfNeeded()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                presentSharedInboxIfNeeded()
            }
        }
    }

    private func presentSharedInboxIfNeeded() {
        guard sharedImportPayload == nil, !showSharedUploadSheet else { return }
        let pending = SharedInbox.pendingFiles()
        if !pending.isEmpty {
            sharedImportPayload = SharedImportPayload(files: pending)
        }
    }

    private func debouncedWidgetSync() {
        widgetSyncTask?.cancel()
        widgetSyncTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            WidgetDataWriter.sync(userCards: userCards) // snapshot on main, write on background
        }
    }

    var body: some View {
        ZStack {
            TabView {
                CardsView()
                    .tabItem {
                        Label("Wallet", systemImage: "creditcard.fill")
                    }

                BenefitsView()
                    .tabItem {
                        Label("Benefits", systemImage: "checkmark.seal.fill")
                    }
                RecommendationsView()
                    .tabItem {
                        Label("Best Card", systemImage: "star.circle.fill")
                    }
                SubscriptionsView()
                    .tabItem {
                        Label("Subscriptions", systemImage: "repeat.circle.fill")
                    }
                SettingsView()
                    .tabItem{
                        Label("Settings", systemImage: "gearshape.fill")
                    }
            }
            
            if !hasCompletedTutorial {
                TutorialView()
                    .zIndex(1)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                WidgetDataWriter.sync(userCards: userCards)
                checkSharedInbox()
            }
        }
        // @Query arrays compare by model identity, so onChange(of: completions)
        // never fires on property mutations — observe the mutable fields instead.
        .onChange(of: completions.map { "\($0.isCompleted)|\($0.isIgnored)|\($0.partialUsage)" }) { _, _ in
            debouncedWidgetSync()
            debouncedNotificationReschedule()
        }
        .onAppear {
            normalizeExistingStatementNames()
            cleanupSummaryTransactionRows()
            WidgetDataWriter.sync(userCards: userCards)
            NotificationScheduler.requestPermission()
            checkSharedInbox()
        }
        .sheet(item: $sharedImportPayload, onDismiss: {
            // If the user tapped Import, the coordinator holds the files —
            // open the upload sheet pre-loaded with them. Presenting the second
            // sheet immediately inside onDismiss races the first sheet's
            // dismissal animation and renders a blank sheet (the real one only
            // appears after swiping it away). Wait for the dismissal to settle,
            // and only present when there are actually files to import.
            guard !SharedImportCoordinator.shared.filesToImport.isEmpty else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                guard !SharedImportCoordinator.shared.filesToImport.isEmpty else { return }
                showSharedUploadSheet = true
            }
        }) { payload in
            // Content receives its files directly — never reads a separate
            // @State that could still be empty on the first render.
            SharedImportSheet(files: payload.files)
        }
        .sheet(isPresented: $showSharedUploadSheet) {
            StatementUploadSheet(userCards: userCards) {}
        }
        .onChange(of: userCards.map { "\($0.persistentModelID)|\($0.notificationsEnabled)" }) { _, _ in
            NotificationScheduler.scheduleAll(userCards: userCards)
        }
    }
}

/// Identifiable wrapper so the shared-import sheet can be presented with
/// `.sheet(item:)` — the files travel with the payload, avoiding the blank-
/// first-render race of `.sheet(isPresented:)` reading a separate @State.
private struct SharedImportPayload: Identifiable {
    let id = UUID()
    let files: [SharedInbox.InboxFile]
}

/// Shown when the Share Extension has stashed statement files in the
/// App Group inbox. "Import" hands the files to SharedImportCoordinator
/// for the statement upload flow to pick up; "Discard" deletes them.
private struct SharedImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    let files: [SharedInbox.InboxFile]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(files) { file in
                        Label(file.originalName, systemImage: "doc.fill")
                    }
                } header: {
                    Text("Statements received via Share")
                }
            }
            .navigationTitle("Import Statements")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Discard", role: .destructive) {
                        SharedInbox.clear()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") {
                        SharedImportCoordinator.shared.filesToImport = files
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [UserCard.self, BenefitCompletion.self, NotificationSettings.self], inMemory: true)
}
