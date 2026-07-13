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
    @Environment(\.scenePhase) private var scenePhase
    @Query private var userCards: [UserCard]
    @Query private var completions: [BenefitCompletion]

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
    @State private var showSharedImport = false
    @State private var showSharedUploadSheet = false
    @State private var sharedInboxFiles: [SharedInbox.InboxFile] = []

    private func checkSharedInbox() {
        // Delay the first check: on a cold launch the view isn't attached yet
        // (an immediate sheet presentation gets dropped), and the Share
        // Extension may still be finishing its file copy when the app
        // foregrounds. One delayed check + one retry covers both races.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            presentSharedInboxIfNeeded()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                presentSharedInboxIfNeeded()
            }
        }
    }

    private func presentSharedInboxIfNeeded() {
        guard !showSharedImport, !showSharedUploadSheet else { return }
        let pending = SharedInbox.pendingFiles()
        if !pending.isEmpty {
            sharedInboxFiles = pending
            showSharedImport = true
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
            WidgetDataWriter.sync(userCards: userCards)
            NotificationScheduler.requestPermission()
            checkSharedInbox()
        }
        .sheet(isPresented: $showSharedImport, onDismiss: {
            // If the user tapped Import, the coordinator holds the files —
            // open the upload sheet pre-loaded with them.
            if !SharedImportCoordinator.shared.filesToImport.isEmpty {
                showSharedUploadSheet = true
            }
        }) {
            SharedImportSheet(files: sharedInboxFiles)
        }
        .sheet(isPresented: $showSharedUploadSheet) {
            StatementUploadSheet(userCards: userCards) {}
        }
        .onChange(of: userCards.map { "\($0.persistentModelID)|\($0.notificationsEnabled)" }) { _, _ in
            NotificationScheduler.scheduleAll(userCards: userCards)
        }
    }
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
