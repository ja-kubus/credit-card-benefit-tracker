//
//  WidgetDataWriter.swift
//  Credit Card Benefit Tracker
//
//  Syncs benefit data to the shared App Group UserDefaults so the
//  BenefitWidget extension can read it without accessing SwiftData directly.
//

import Foundation
import WidgetKit
import SwiftData

struct WidgetDataWriter {
    static let suiteName = "group.benefittracker.shared"

    /// Snapshots unclaimed benefit data on the calling (main) thread, then writes
    /// to shared UserDefaults and reloads widget timelines on a background queue
    /// so the main thread is never blocked by the slow App Group pref access.
    static func sync(userCards: [UserCard]) {
        // Snapshot on calling thread (SwiftData models are main-actor bound)
        var count = 0
        var value = 0.0
        var names: [String] = []

        for card in userCards {
            for completion in card.completions {
                guard !completion.isCompleted,
                      !completion.isIgnored,
                      completion.dollarAmount > 0 else { continue }
                count += 1
                value += completion.dollarAmount
                if names.count < 4 { names.append(completion.benefitName) }
            }
        }

        // UserDefaults(suiteName:) is slow in the simulator (cfprefsd detaches) —
        // move the write and widget reload entirely off the main thread.
        let snapshot = (count: count, value: value, names: names)
        DispatchQueue.global(qos: .utility).async {
            if let defaults = UserDefaults(suiteName: suiteName) {
                defaults.set(snapshot.count, forKey: "unclaimedCount")
                defaults.set(snapshot.value, forKey: "remainingValue")
                defaults.set(snapshot.names, forKey: "benefitNames")
            }
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
