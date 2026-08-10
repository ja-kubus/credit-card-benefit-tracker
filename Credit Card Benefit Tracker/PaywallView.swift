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
                        tier: .adFree,
                        tagline: "Remove ads",
                        features: ["No ads", "Manual statement upload"]
                    )
                    tierCard(
                        tier: .premium,
                        tagline: "Link up to 5 cards",
                        features: ["Everything in Ad-Free", "Connect cards automatically", "Up to 5 linked cards"]
                    )
                    tierCard(
                        tier: .max,
                        tagline: "Link up to 10 cards",
                        features: ["Everything in Premium", "Up to 10 linked cards"]
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

                    Text("Subscriptions renew monthly until cancelled. Manage or cancel anytime in Settings. Manual statement upload is always free.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.top, 8)
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
                Text(product?.displayPrice ?? "—")
                    .font(.title3.weight(.semibold))
                + Text(product != nil ? " /mo" : "")
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
                    if purchasing == product?.id {
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
            .disabled(product == nil || isCurrent || purchasing != nil)
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

    private func product(for tier: AppTier) -> Product? {
        let id: String
        switch tier {
        case .adFree: id = SubscriptionProduct.adFree
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
