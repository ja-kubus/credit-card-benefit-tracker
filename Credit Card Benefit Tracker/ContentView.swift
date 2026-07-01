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
        .onAppear {
            WidgetDataWriter.sync(userCards: userCards)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [UserCard.self, BenefitCompletion.self, NotificationSettings.self], inMemory: true)
}
