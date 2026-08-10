//
//  AdBannerView.swift
//  Credit Card Benefit Tracker
//
//  Placeholder ad banner shown to free users whose trial has ended. It renders
//  only when `SubscriptionManager.showsAds` is true, and doubles as an upsell:
//  tapping it opens the paywall.
//
//  TODO (production): replace the placeholder content with a real ad view
//  (e.g. Google AdMob GADBannerView wrapped in a UIViewRepresentable). Keep the
//  same `showsAds` gate so subscribers never see ads. Integrating AdMob also
//  requires the SDK, an ad unit id, App Tracking Transparency handling, and
//  updated App Privacy labels.
//

import SwiftUI

struct AdBannerView: View {
    @EnvironmentObject private var subscriptions: SubscriptionManager
    @State private var showPaywall = false

    var body: some View {
        if subscriptions.showsAds {
            Button {
                showPaywall = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(Color.appCoral)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Remove ads")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text("Go Ad-Free for $0.99/mo, or unlock card linking")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial)
                .overlay(alignment: .topLeading) {
                    Text("AD")
                        .font(.system(size: 8, weight: .bold))
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(Color.secondary.opacity(0.25))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                        .padding(4)
                }
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showPaywall) {
                PaywallView(contextMessage: "Subscribe to remove ads.")
            }
        }
    }
}
