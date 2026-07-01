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
            }
        }
        .onChange(of: completions) { _, _ in
            debouncedWidgetSync()
        }
        .onAppear {
            WidgetDataWriter.sync(userCards: userCards)
            NotificationScheduler.requestPermission()
        }
        .onChange(of: userCards) { _, cards in
            NotificationScheduler.scheduleAll(userCards: cards)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [UserCard.self, BenefitCompletion.self, NotificationSettings.self], inMemory: true)
}
