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
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [UserCard.self, BenefitCompletion.self, NotificationSettings.self], inMemory: true)
}
