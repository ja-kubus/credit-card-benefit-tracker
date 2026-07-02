//
//  NotificationScheduler.swift
//  Credit Card Benefit Tracker
//

import UserNotifications
import Foundation

enum NotificationScheduler {
    private static let schedulingQueue = DispatchQueue(label: "benefittracker.notification-scheduling", qos: .utility)

    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    static func scheduleAll(userCards: [UserCard]) {
        // Snapshot the data we need on the calling (main) thread before hopping to background
        struct BenefitSnapshot {
            let cardName: String
            let notificationsEnabled: Bool
            let benefitID: String
            let benefitName: String
            let dollarAmount: Double
            let isIgnored: Bool
            let isCompleted: Bool
            let resetDate: Date
            let benefitPeriod: BenefitPeriod
        }

        let snapshots: [BenefitSnapshot] = userCards.flatMap { card in
            card.completions.map { c in
                BenefitSnapshot(
                    cardName: card.name,
                    notificationsEnabled: card.notificationsEnabled,
                    benefitID: c.benefitID,
                    benefitName: c.benefitName,
                    dollarAmount: c.dollarAmount,
                    isIgnored: c.isIgnored,
                    isCompleted: c.isCompleted,
                    resetDate: c.resetDate,
                    benefitPeriod: c.benefitPeriod
                )
            }
        }

        // Serial queue so overlapping reschedules can't interleave their
        // remove-all + add sequences (which would drop or duplicate requests).
        Self.schedulingQueue.async {
            let center = UNUserNotificationCenter.current()
            center.removeAllPendingNotificationRequests()

            let now = Date()
            let calendar = Calendar.current

            for snap in snapshots {
                guard snap.notificationsEnabled, !snap.isIgnored, snap.dollarAmount > 0 else { continue }

                // Notification A — start of next period
                if snap.resetDate > now {
                    var comps = calendar.dateComponents([.year, .month, .day], from: snap.resetDate)
                    comps.hour = 0; comps.minute = 1
                    let content = UNMutableNotificationContent()
                    content.title = "New credit available: \(snap.benefitName)"
                    content.body = "Your $\(Int(snap.dollarAmount)) \(snap.benefitName) on your \(snap.cardName) just reset. Don't forget to use it!"
                    content.sound = .default
                    let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                    center.add(UNNotificationRequest(identifier: "\(snap.benefitID)_start", content: content, trigger: trigger)) { _ in }
                }

                // Notification B — 75% through the period (expiring soon)
                let periodDays: Double
                switch snap.benefitPeriod {
                case .monthly:      periodDays = 30
                case .quarterly:    periodDays = 90
                case .semiAnnually: periodDays = 182
                case .annually:     periodDays = 365
                }
                let reminderDate = snap.resetDate.addingTimeInterval(-periodDays * 0.25 * 86400)
                if reminderDate > now && !snap.isCompleted {
                    var comps = calendar.dateComponents([.year, .month, .day], from: reminderDate)
                    comps.hour = 0; comps.minute = 1
                    let content = UNMutableNotificationContent()
                    content.title = "Use your \(snap.benefitName) credit soon"
                    content.body = "Your $\(Int(snap.dollarAmount)) \(snap.benefitName) on your \(snap.cardName) expires soon — don't let it go to waste!"
                    content.sound = .default
                    let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                    center.add(UNNotificationRequest(identifier: "\(snap.benefitID)_reminder", content: content, trigger: trigger)) { _ in }
                }
            }
        }
    }

    static func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
