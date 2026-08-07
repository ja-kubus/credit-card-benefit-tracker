//
//  NotificationEvents.swift
//  Credit Card Benefit Tracker
//
//  Detects in-app events (a benefit period fully used, a card's annual fee
//  recouped), persists them as AppNotifications, and surfaces them as banners.
//

import SwiftUI
import SwiftData

// MARK: - Banner presentation

/// A transient in-app banner. Carries the originating notification so a manual
/// dismissal can mark it read (no red dot) while it stays in history.
struct BannerPayload: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
    let isPositive: Bool
    let notification: AppNotification?

    static func == (lhs: BannerPayload, rhs: BannerPayload) -> Bool { lhs.id == rhs.id }
}

@Observable
final class BannerCenter {
    static let shared = BannerCenter()
    var current: BannerPayload?
    private init() {}
    func show(_ payload: BannerPayload) { current = payload }
}

// MARK: - Event evaluation

enum NotificationEvents {

    private static let cycleKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// Evaluate every card for newly-satisfied period-complete / fee-recoup
    /// conditions. New AppNotifications are created (deduped by cycle). When
    /// `silent` is true (app launch seeding) they're marked read and no banner
    /// fires; otherwise they're unread and banner the newest one.
    static func evaluate(cards: [UserCard], context: ModelContext, silent: Bool) {
        let existing = (try? context.fetch(FetchDescriptor<AppNotification>())) ?? []
        var existingKeys = Set(existing.map { $0.dedupKey })

        var newest: AppNotification?

        for card in cards {
            guard let catalog = CreditCardCatalog.all.first(where: { $0.id == card.catalogCardID }) else { continue }

            // MARK: Period completed
            for period in BenefitPeriod.allCases {
                let periodBenefits = catalog.benefits.filter { $0.period == period && $0.dollarAmount > 0 }
                guard !periodBenefits.isEmpty else { continue }

                var relevantCompletions: [BenefitCompletion] = []
                var allTracked = true
                for benefit in periodBenefits {
                    guard let comp = card.completions.first(where: { $0.benefitName == benefit.name && $0.benefitPeriod == period }) else {
                        allTracked = false; break
                    }
                    if comp.isIgnored { continue }
                    relevantCompletions.append(comp)
                }
                guard allTracked, !relevantCompletions.isEmpty else { continue }
                guard relevantCompletions.allSatisfy({ $0.isCompleted }) else { continue }

                let cycle = relevantCompletions.map { $0.resetDate }.min().map { cycleKeyFormatter.string(from: $0) } ?? ""
                let key = "period|\(card.catalogCardID)|\(period.rawValue)|\(cycle)"
                if !existingKeys.contains(key) {
                    existingKeys.insert(key)
                    let n = AppNotification(
                        kind: "periodCompleted",
                        title: "\(periodAdjective(period)) benefits complete! 🎉",
                        message: "You've used every \(periodAdjective(period).lowercased()) benefit on your \(card.name).",
                        cardName: card.name,
                        dedupKey: key,
                        isRead: silent
                    )
                    context.insert(n)
                    newest = n
                }
            }

            // MARK: Annual fee recouped
            if card.annualFee > 0 {
                let points = PointsValuer.dollarValue(for: card, since: card.currentFeeYearStart)
                let benefitsUsed = card.feeYearBenefitUsage + claimedThisCycle(card)
                let contribution = benefitsUsed + points + card.manualClaimedValue
                if contribution >= card.annualFee {
                    let cycle = cycleKeyFormatter.string(from: card.currentFeeYearStart)
                    let key = "fee|\(card.catalogCardID)|\(cycle)"
                    if !existingKeys.contains(key) {
                        existingKeys.insert(key)
                        let n = AppNotification(
                            kind: "feeRecouped",
                            title: "Annual fee recouped! 💳",
                            message: "Your \(card.name) has earned back its $\(Int(card.annualFee)) annual fee this year.",
                            cardName: card.name,
                            dedupKey: key,
                            isRead: silent
                        )
                        context.insert(n)
                        newest = n
                    }
                }
            }
        }

        try? context.save()

        if !silent, let n = newest {
            BannerCenter.shared.show(BannerPayload(
                title: n.title,
                message: n.message,
                isPositive: true,
                notification: n
            ))
        }
    }

    private static func claimedThisCycle(_ card: UserCard) -> Double {
        card.completions.reduce(0.0) { total, comp in
            if comp.isCompleted { return total + comp.dollarAmount }
            let partial = comp.partialUsage.trimmingCharacters(in: .whitespaces)
            return total + (Double(partial) ?? 0)
        }
    }

    private static func periodAdjective(_ period: BenefitPeriod) -> String {
        switch period {
        case .monthly:      return "Monthly"
        case .quarterly:    return "Quarterly"
        case .semiAnnually: return "Semi-annual"
        case .annually:     return "Annual"
        }
    }
}

// MARK: - Banner view

struct BannerView: View {
    let payload: BannerPayload
    let onDismiss: (_ manual: Bool) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: payload.isPositive ? "checkmark.seal.fill" : "bell.fill")
                .font(.title3)
                .foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 2) {
                Text(payload.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                Text(payload.message)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            Button {
                onDismiss(true)
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .padding(14)
        .background(Color.appLeaf, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
        .padding(.horizontal, 16)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}
