//
//  PaywallView.swift
//  Credit Card Benefit Tracker
//
//  The subscription upsell. Shows the four tiers, the current status (including
//  trial days remaining), and StoreKit purchase + restore buttons.
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject private var subscriptions: SubscriptionManager
    @Environment(\.dismiss) private var dismiss

    /// Optional context line, e.g. "Linking requires Concierge Premium."
    var contextMessage: String?

    @State private var purchasing: String?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    statusHeader

                    if let contextMessage {
                        Text(contextMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    tierCard(
                        tier: .premium,
                        tagline: "Cards from up to 5 banks",
                        features: ["Connect cards automatically", "Cards from up to 5 banks", "Unlimited cards per bank", "Transactions import + categorize"]
                    )
                    tierCard(
                        tier: .max,
                        tagline: "Cards from up to 10 banks",
                        features: ["Everything in Premium", "Cards from up to 10 banks"]
                    )

                    Button("Restore Purchases") {
                        Task { await subscriptions.restore() }
                    }
                    .font(.footnote)
                    .padding(.top, 4)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    Text("Concierge Premium ($2.99/month) and Concierge Max ($5.99/month) are auto-renewing subscriptions. Payment is charged to your Apple Account at confirmation. It renews automatically each month unless cancelled at least 24 hours before the end of the current period; your account is charged for renewal within 24 hours before the period ends. Manage or cancel anytime in your Apple Account settings. Manual statement upload is always free.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.top, 8)

                    HStack(spacing: 16) {
                        Link("Privacy Policy", destination: URL(string: "https://ja-kubus.github.io/credit-card-benefit-tracker/privacy.html")!)
                        Link("Terms of Use (EULA)", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                    }
                    .font(.caption2)
                    .padding(.top, 2)
                }
                .padding()
            }
            .navigationTitle("Upgrade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private var statusHeader: some View {
        VStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(.largeTitle)
                .foregroundStyle(Color.appCoral)
            Text("Your plan: \(subscriptions.effectiveTierName)")
                .font(.headline)
            if subscriptions.isInTrial {
                Text("Premium trial — \(subscriptions.trialDaysRemaining) day\(subscriptions.trialDaysRemaining == 1 ? "" : "s") left (up to 2 cards)")
                    .font(.caption)
                    .foregroundStyle(Color.appLeaf)
            }
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private func tierCard(tier: AppTier, tagline: String, features: [String]) -> some View {
        let product = product(for: tier)
        let isCurrent = subscriptions.purchasedTier == tier
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tier.displayName).font(.headline)
                    Text(tagline).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(product?.displayPrice ?? fallbackPrice(tier))
                    .font(.title3.weight(.semibold))
                + Text(" /mo")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            ForEach(features, id: \.self) { f in
                Label(f, systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.primary)
            }

            Button {
                guard let product else { return }
                Task { await buy(product) }
            } label: {
                Group {
                    if let product, purchasing == product.id {
                        ProgressView()
                    } else if isCurrent {
                        Text("Current Plan")
                    } else {
                        Text("Subscribe")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.appCoral)
            .disabled(isCurrent || purchasing != nil)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.primary.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isCurrent ? Color.appLeaf : Color.clear, lineWidth: 2)
                )
        )
    }

    /// Shown when StoreKit hasn't returned the product yet (e.g. before the App
    /// Store Connect products propagate, or in a build without a StoreKit config),
    /// so the paywall never renders a blank/"Unavailable" price.
    private func fallbackPrice(_ tier: AppTier) -> String {
        switch tier {
        case .premium: return "$2.99"
        case .max: return "$5.99"
        case .free: return ""
        }
    }

    private func product(for tier: AppTier) -> Product? {
        let id: String
        switch tier {
        case .premium: id = SubscriptionProduct.premium
        case .max: id = SubscriptionProduct.max
        case .free: return nil
        }
        return subscriptions.products.first { $0.id == id }
    }

    private func buy(_ product: Product) async {
        purchasing = product.id
        errorMessage = nil
        defer { purchasing = nil }
        do {
            try await subscriptions.purchase(product)
            if subscriptions.purchasedTier != .free { dismiss() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
