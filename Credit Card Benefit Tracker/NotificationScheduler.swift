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

    // MARK: - Triggered notification reconstruction

    struct TriggeredNotification: Identifiable {
        let id: String          // e.g. "<benefitID>_reminder"
        let title: String
        let body: String
        let firedDate: Date
        let cardName: String
        let benefitName: String
    }

    // Number of days in a benefit period. Kept identical to scheduleAll's math.
    private static func periodDays(for period: BenefitPeriod) -> Double {
        switch period {
        case .monthly:      return 30
        case .quarterly:    return 90
        case .semiAnnually: return 182
        case .annually:     return 365
        }
    }

    // Content-string helpers so triggeredNotifications and scheduleAll stay in sync.
    private static func startTitle(benefitName: String) -> String {
        "New credit available: \(benefitName)"
    }
    private static func startBody(dollarAmount: Double, benefitName: String, cardName: String) -> String {
        "Your $\(Int(dollarAmount)) \(benefitName) on your \(cardName) just reset. Don't forget to use it!"
    }
    private static func reminderTitle(benefitName: String) -> String {
        "Use your \(benefitName) credit soon"
    }
    private static func reminderBody(dollarAmount: Double, benefitName: String, cardName: String) -> String {
        "Your $\(Int(dollarAmount)) \(benefitName) on your \(cardName) expires soon — don't let it go to waste!"
    }

    private static let acknowledgedKey = "acknowledgedNotificationIDs"

    private static func defaultsStore() -> UserDefaults {
        UserDefaults(suiteName: "group.benefittracker.shared") ?? .standard
    }

    private static func acknowledgedSet() -> Set<String> {
        let store = defaultsStore()
        let arr = store.stringArray(forKey: acknowledgedKey) ?? []
        return Set(arr)
    }

    private static func writeAcknowledgedSet(_ set: Set<String>) {
        defaultsStore().set(Array(set), forKey: acknowledgedKey)
    }

    // Composite key includes the fired month so a repeating benefit's next-period
    // notification (same id) is treated as a fresh, unacknowledged entry.
    private static func compositeKey(id: String, firedDate: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        formatter.calendar = Calendar(identifier: .gregorian)
        return "\(id)|\(formatter.string(from: firedDate))"
    }

    static func compositeKey(for notification: TriggeredNotification) -> String {
        compositeKey(id: notification.id, firedDate: notification.firedDate)
    }

    static func triggeredNotifications(userCards: [UserCard]) -> [TriggeredNotification] {
        let now = Date()
        let earliest = now.addingTimeInterval(-120 * 86400)
        let acknowledged = acknowledgedSet()

        var results: [TriggeredNotification] = []

        for card in userCards {
            for c in card.completions {
                guard !c.isIgnored, c.dollarAmount > 0 else { continue }

                // Notification A — start of period (resetDate)
                let startDate = c.resetDate
                if startDate <= now && startDate >= earliest {
                    let id = "\(c.benefitID)_start"
                    let key = compositeKey(id: id, firedDate: startDate)
                    if !acknowledged.contains(key) {
                        results.append(TriggeredNotification(
                            id: id,
                            title: startTitle(benefitName: c.benefitName),
                            body: startBody(dollarAmount: c.dollarAmount, benefitName: c.benefitName, cardName: card.name),
                            firedDate: startDate,
                            cardName: card.name,
                            benefitName: c.benefitName
                        ))
                    }
                }

                // Notification B — 75% through the period (expiring soon)
                let reminderDate = c.resetDate.addingTimeInterval(-periodDays(for: c.benefitPeriod) * 0.25 * 86400)
                if reminderDate <= now && reminderDate >= earliest {
                    let id = "\(c.benefitID)_reminder"
                    let key = compositeKey(id: id, firedDate: reminderDate)
                    if !acknowledged.contains(key) {
                        results.append(TriggeredNotification(
                            id: id,
                            title: reminderTitle(benefitName: c.benefitName),
                            body: reminderBody(dollarAmount: c.dollarAmount, benefitName: c.benefitName, cardName: card.name),
                            firedDate: reminderDate,
                            cardName: card.name,
                            benefitName: c.benefitName
                        ))
                    }
                }
            }
        }

        return results.sorted { $0.firedDate > $1.firedDate }
    }

    static func acknowledge(_ id: String) {
        var set = acknowledgedSet()
        set.insert(id)
        writeAcknowledgedSet(set)
    }

    static func acknowledgeAll(_ ids: [String]) {
        var set = acknowledgedSet()
        for id in ids { set.insert(id) }
        writeAcknowledgedSet(set)
    }

    static func unacknowledgeAll() {
        defaultsStore().removeObject(forKey: acknowledgedKey)
    }
}
