//
//  ContentView.swift
//  Credit Card Benefit Tracker
//
//  Created by Jacob Michalik on 4/20/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            CardsView()
                .tabItem {
                    Label("Wallet", systemImage: "creditcard.fill")
                }

            BenefitsView()
                .tabItem {
                    Label("Benefits", systemImage: "checkmark.seal.fill")
                }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [UserCard.self, BenefitCompletion.self], inMemory: true)
}
