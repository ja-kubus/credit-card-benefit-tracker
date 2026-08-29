//
//  SubscriptionManager.swift
//  Credit Card Benefit Tracker
//
//  Owns the app's monetization state: which tier the user has (via StoreKit 2
//  entitlements), the 7-day intro trial, and the capability flags the rest of
//  the app gates on (ads, account linking, card cap).
//
//  Tiers:
//    Free            — manual upload only, no account linking
//    Premium ($2.99) — linking up to 5 cards
//    Max ($5.99)     — linking up to 10 cards
//    Trial (7 days)  — app-managed: linking up to 2 cards
//
//  The trial is app-managed (not a StoreKit intro offer) because it grants a
//  REDUCED capability (2 cards) rather than the full product for free.
//

import Foundation
import Combine
import StoreKit

enum AppTier: Int, Comparable, CaseIterable {
    case free = 0
    case premium = 1
    case max = 2

    static func < (lhs: AppTier, rhs: AppTier) -> Bool { lhs.rawValue < rhs.rawValue }

    var displayName: String {
        switch self {
        case .free: return "Free"
        case .premium: return "Concierge Premium"
        case .max: return "Concierge Max"
        }
    }
}

enum SubscriptionProduct {
    static let premium = "social.creditcardbenefittracker.premium.monthly"
    static let max = "social.creditcardbenefittracker.max.monthly"

    static let all: [String] = [premium, max]

    static func tier(for productID: String) -> AppTier {
        switch productID {
        case premium: return .premium
        case max: return .max
        default: return .free
        }
    }
}

@MainActor
final class SubscriptionManager: ObservableObject {
    /// Tier granted by an active StoreKit subscription (ignores the trial).
    @Published private(set) var purchasedTier: AppTier = .free
    /// Products fetched from StoreKit, for the paywall.
    @Published private(set) var products: [Product] = []
    @Published private(set) var isInTrial: Bool = false
    @Published private(set) var trialDaysRemaining: Int = 0
    @Published private(set) var isLoadingProducts = false

    private let trialLength: TimeInterval = 7 * 24 * 60 * 60
    private let trialStartKey = "trial_start_date"
    private var updatesTask: Task<Void, Never>?

    // MARK: - Capabilities (what the rest of the app gates on)

    /// Account linking is available on Premium/Max, or during the trial.
    var canLinkAccounts: Bool { purchasedTier >= .premium || isInTrial }

    /// Maximum number of linked CARDS allowed on the current tier.
    var maxLinkedCards: Int {
        switch purchasedTier {
        case .max: return 15
        case .premium: return 5
        case .free: return isInTrial ? 2 : 0
        }
    }

    /// Maximum number of distinct BANKS (institutions) cards may be linked from,
    /// across ALL tiers. Cost is billed per bank, so this caps worst-case cost
    /// (5 banks x 30¢ = $1.50/mo) even for a 15-card Max user.
    let maxLinkedBanks = 5

    /// The tier label to show the user (reflects the trial).
    var effectiveTierName: String {
        if purchasedTier >= .premium { return purchasedTier.displayName }
        if isInTrial { return "Premium Trial" }
        return purchasedTier.displayName
    }

    // MARK: - Lifecycle

    init() {
        updatesTask = listenForTransactions()
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
        evaluateTrial()
    }

    deinit { updatesTask?.cancel() }

    /// Start the 7-day trial clock on first launch (idempotent).
    func startTrialIfNeeded() {
        if UserDefaults.standard.object(forKey: trialStartKey) == nil {
            UserDefaults.standard.set(Date(), forKey: trialStartKey)
        }
        evaluateTrial()
    }

    func evaluateTrial() {
        guard let start = UserDefaults.standard.object(forKey: trialStartKey) as? Date else {
            isInTrial = false
            trialDaysRemaining = 0
            return
        }
        let end = start.addingTimeInterval(trialLength)
        let now = Date()
        isInTrial = now < end
        trialDaysRemaining = max(0, Int(ceil(end.timeIntervalSince(now) / 86_400)))
    }

    // MARK: - StoreKit

    func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            let fetched = try await Product.products(for: SubscriptionProduct.all)
            // Order: premium, max.
            products = fetched.sorted {
                SubscriptionProduct.tier(for: $0.id) < SubscriptionProduct.tier(for: $1.id)
            }
        } catch {
            products = []
        }
    }

    /// Recompute the purchased tier from current entitlements (highest wins).
    /// `Transaction.currentEntitlements` already yields only active, non-revoked,
    /// non-expired entitlements, so we trust it rather than re-filtering (manual
    /// date checks misfire under StoreKit Testing's accelerated clock).
    func refreshEntitlements() async {
        var highest: AppTier = .free
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            let tier = SubscriptionProduct.tier(for: transaction.productID)
            if tier > highest { highest = tier }
        }
        purchasedTier = highest
    }

    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            if case .verified(let transaction) = verification {
                await transaction.finish()
                await refreshEntitlements()
            }
        case .userCancelled, .pending:
            break
        @unknown default:
            break
        }
    }

    /// Restore purchases (also re-syncs entitlements).
    func restore() async {
        try? await AppStore.sync()
        await refreshEntitlements()
    }

    /// Background listener for renewals/revocations happening outside a purchase.
    private func listenForTransactions() -> Task<Void, Never> {
        Task(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                guard case .verified(let transaction) = result else { continue }
                await transaction.finish()
                await self?.refreshEntitlements()
            }
        }
    }
}
