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

    /// Reads all UserCard completions, counts unclaimed monthly benefits,
    /// sums their dollar value, and writes both to shared UserDefaults.
    /// Also triggers a widget timeline reload so the home screen updates immediately.
    static func sync(userCards: [UserCard]) {
        var unclaimedCount = 0
        var remainingValue = 0.0

        for card in userCards {
            for completion in card.completions {
                guard completion.benefitPeriod == .monthly else { continue }
                guard !completion.isCompleted else { continue }
                guard !completion.isIgnored else { continue }
                guard completion.dollarAmount > 0 else { continue }

                unclaimedCount += 1
                remainingValue += completion.dollarAmount
            }
        }

        var benefitNames: [String] = []
        for card in userCards {
            for completion in card.completions {
                guard completion.benefitPeriod == .monthly,
                      !completion.isCompleted,
                      !completion.isIgnored,
                      completion.dollarAmount > 0 else { continue }
                benefitNames.append(completion.benefitName)
            }
        }

        if let defaults = UserDefaults(suiteName: suiteName) {
            defaults.set(unclaimedCount, forKey: "unclaimedCount")
            defaults.set(remainingValue, forKey: "remainingValue")
            defaults.set(Array(benefitNames.prefix(4)), forKey: "benefitNames")
        }

        WidgetCenter.shared.reloadAllTimelines()
    }
}
