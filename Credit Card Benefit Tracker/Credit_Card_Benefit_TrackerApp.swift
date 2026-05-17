//
//  Credit_Card_Benefit_TrackerApp.swift
//  Credit Card Benefit Tracker
//
//  Created by Jacob Michalik on 4/20/26.
//

import SwiftUI
import SwiftData

@main
struct Credit_Card_Benefit_TrackerApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            UserCard.self,
            BenefitCompletion.self,
            NotificationSettings.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
