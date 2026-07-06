//
//  WidgetDataWriter.swift
//  Credit Card Benefit Tracker
//
//  Syncs benefit data to the shared App Group UserDefaults so the
//  BenefitWidget extension can read it without accessing SwiftData directly.
//  Data is written per benefit period so the widget can page between
//  Monthly / Quarterly / Semi-Annually / Annually.
//

import Foundation
import WidgetKit
import SwiftData

struct WidgetDataWriter {
    static let suiteName = "group.benefittracker.shared"

    /// Period raw values, in the order the widget cycles through them.
    static let periodKeys = ["Monthly", "Quarterly", "Semi-Annually", "Annually"]

    /// Snapshots unclaimed benefit data on the calling (main) thread, then writes
    /// to shared UserDefaults and reloads widget timelines on a background queue
    /// so the main thread is never blocked by the slow App Group pref access.
    static func sync(userCards: [UserCard]) {
        // Snapshot on calling thread (SwiftData models are main-actor bound)
        var counts: [String: Int] = [:]
        var values: [String: Double] = [:]
        var names: [String: [String]] = [:]

        for card in userCards {
            for completion in card.completions {
                guard !completion.isCompleted,
                      !completion.isIgnored,
                      completion.dollarAmount > 0 else { continue }
                let period = completion.period
                counts[period, default: 0] += 1
                values[period, default: 0] += completion.dollarAmount
                if names[period, default: []].count < 4 {
                    names[period, default: []].append(completion.benefitName)
                }
            }
        }

        // UserDefaults(suiteName:) is slow in the simulator (cfprefsd detaches) —
        // move the write and widget reload entirely off the main thread.
        DispatchQueue.global(qos: .utility).async {
            if let defaults = UserDefaults(suiteName: suiteName) {
                for period in periodKeys {
                    defaults.set(counts[period] ?? 0, forKey: "unclaimedCount_\(period)")
                    defaults.set(values[period] ?? 0.0, forKey: "remainingValue_\(period)")
                    defaults.set(names[period] ?? [], forKey: "benefitNames_\(period)")
                }
            }
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
