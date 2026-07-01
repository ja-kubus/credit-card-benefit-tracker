//
//  RecommendationsView.swift
//  Credit Card Benefit Tracker
//
//  Created by Jacob Michalik on 4/20/26.
//

import SwiftUI
import SwiftData

// MARK: - Spending Category

enum SpendingCategory: String, CaseIterable {
    case dining = "Dining"
    case groceries = "Groceries"
    case airlines = "Airlines"
    case hotels = "Hotels"
    case carRentals = "Car Rentals"
    case gas = "Gas Stations"
    case transit = "Transit"
    case streaming = "Streaming"
    case drugstores = "Drugstores"
    case other = "All Other"

    var systemImage: String {
        switch self {
        case .dining:     return "fork.knife"
        case .groceries:  return "cart.fill"
        case .airlines:   return "airplane"
        case .hotels:     return "bed.double.fill"
        case .carRentals: return "car.fill"
        case .gas:        return "fuelpump.fill"
        case .transit:    return "bus.fill"
        case .streaming:  return "play.tv.fill"
        case .drugstores: return "cross.vial.fill"
        case .other:      return "sparkles"
        }
    }
}

// MARK: - Card Recommendation Engine

struct CardRecommendationEngine {

    // Maps cardID -> (program display name, cents per point)
    static let programs: [String: (name: String, cpp: Double)] = [
        "american_express_platinum_card":                         ("Amex MR", 2.0),
        "american_express_gold_card":                             ("Amex MR", 2.0),
        "american_express_blue_cash_preferred":                   ("Cash Back", 1.0),
        "american_express_hilton_honors_aspire_card":             ("Hilton Honors", 0.5),
        "american_express_hilton_honors_surpass_card":            ("Hilton Honors", 0.5),
        "american_express_hilton_honors_card":                    ("Hilton Honors", 0.5),
        "chase_sapphire_reserve":                                 ("Chase UR", 2.0),
        "chase_sapphire_preferred":                               ("Chase UR", 2.0),
        "chase_freedom_unlimited":                                ("Cash Back", 1.0),
        "chase_freedom_flex":                                     ("Cash Back", 1.0),
        "chase_amazon_prime_visa":                                ("Cash Back", 1.0),
        "capital_one_venture_x":                                  ("Capital One Miles", 1.7),
        "capital_one_venture":                                    ("Capital One Miles", 1.7),
        "capital_one_savorone":                                   ("Cash Back", 1.0),
        "citi_strata_premier":                                    ("Citi ThankYou", 1.7),
        "citi_double_cash":                                       ("Cash Back", 1.0),
        "citi_custom_cash":                                       ("Cash Back", 1.0),
        "citi_aadvantage_platinum_select_world_elite_mastercard": ("AAdvantage", 1.5),
        "citi_aadvantage_mile_up_credit_card":                    ("AAdvantage", 1.5),
        "discover_it_cash_back":                                  ("Cash Back", 1.0),
        "wf_autograph_journey":                                   ("Wells Fargo Points", 1.0),
        "boa_premium_rewards_elite":                              ("Cash Back", 1.0),
        "usb_altitude_reserve":                                   ("US Bank Points", 1.5),
        "chase_united_explorer":                                  ("United MileagePlus", 1.3),
        "chase_united_quest":                                     ("United MileagePlus", 1.3),
        "chase_united_gateway":                                   ("United MileagePlus", 1.3),
        "chase_united_club":                                      ("United MileagePlus", 1.3),
        "chase_southwest_rapid_rewards_plus":                     ("Southwest Rapid Rewards", 1.5),
        "chase_southwest_rapid_rewards_priority":                 ("Southwest Rapid Rewards", 1.5),
        "chase_southwest_rapid_rewards_premier":                  ("Southwest Rapid Rewards", 1.5),
        "chase_ihg_one_rewards_premier":                          ("IHG One Rewards", 0.5),
        "chase_ihg_one_rewards_traveler":                         ("IHG One Rewards", 0.5),
        "chase_world_of_hyatt":                                   ("Hyatt", 1.7),
        "chase_disney_inspire_visa":                              ("Disney Dollars", 1.0),
        "chase_disney_premier_visa":                              ("Disney Dollars", 1.0),
        "chase_disney_visa":                                      ("Disney Dollars", 1.0),
    ]

    // Maps cardID -> category multipliers
    static let rates: [String: [SpendingCategory: Double]] = [
        "american_express_platinum_card": [
            .airlines: 5, .hotels: 5, .other: 1
        ],
        "american_express_gold_card": [
            .dining: 4, .groceries: 4, .airlines: 3, .other: 1
        ],
        "american_express_blue_cash_preferred": [
            .groceries: 6, .streaming: 6, .gas: 3, .transit: 3, .other: 1
        ],
        "american_express_hilton_honors_aspire_card": [
            .hotels: 14, .airlines: 7, .carRentals: 7, .other: 3
        ],
        "american_express_hilton_honors_surpass_card": [
            .hotels: 12, .dining: 6, .groceries: 6, .gas: 6, .other: 3
        ],
        "american_express_hilton_honors_card": [
            .hotels: 7, .dining: 5, .groceries: 5, .gas: 5, .other: 3
        ],
        "chase_sapphire_reserve": [
            .airlines: 4, .hotels: 4, .dining: 3, .other: 1
        ],
        "chase_sapphire_preferred": [
            .dining: 3, .airlines: 2, .hotels: 2, .other: 1
        ],
        "chase_freedom_unlimited": [
            .airlines: 5, .dining: 3, .drugstores: 3, .other: 1.5
        ],
        "chase_freedom_flex": [
            .airlines: 5, .dining: 3, .drugstores: 3, .other: 1
        ],
        "chase_amazon_prime_visa": [
            .groceries: 5, .gas: 2, .dining: 2, .transit: 2, .other: 1
        ],
        "capital_one_venture_x": [
            .hotels: 10, .carRentals: 10, .airlines: 5, .other: 2
        ],
        "capital_one_venture": [
            .other: 2
        ],
        "capital_one_savorone": [
            .dining: 3, .groceries: 3, .streaming: 3, .other: 1
        ],
        "citi_strata_premier": [
            .hotels: 10, .carRentals: 10, .airlines: 3, .dining: 3, .groceries: 3, .gas: 3, .other: 1
        ],
        "citi_double_cash": [
            .other: 2
        ],
        "citi_custom_cash": [
            .dining: 5, .other: 1
        ],
        "citi_aadvantage_platinum_select_world_elite_mastercard": [
            .dining: 2, .gas: 2, .other: 1
        ],
        "citi_aadvantage_mile_up_credit_card": [
            .groceries: 2, .other: 1
        ],
        "discover_it_cash_back": [
            .other: 1
        ],
        "wf_autograph_journey": [
            .hotels: 5, .airlines: 4, .dining: 3, .gas: 3, .transit: 3, .streaming: 3, .other: 1
        ],
        "boa_premium_rewards_elite": [
            .airlines: 2, .hotels: 2, .dining: 2, .other: 1.5
        ],
        "usb_altitude_reserve": [
            .hotels: 5, .carRentals: 5, .airlines: 5, .other: 1
        ],
        "chase_united_explorer": [
            .airlines: 2, .dining: 2, .hotels: 2, .other: 1
        ],
        "chase_united_quest": [
            .airlines: 3, .dining: 2, .hotels: 2, .transit: 2, .streaming: 2, .other: 1
        ],
        "chase_united_gateway": [
            .airlines: 2, .gas: 2, .transit: 2, .other: 1
        ],
        "chase_united_club": [
            .airlines: 4, .dining: 2, .hotels: 2, .other: 1
        ],
        "chase_southwest_rapid_rewards_plus": [
            .other: 1
        ],
        "chase_southwest_rapid_rewards_priority": [
            .dining: 2, .gas: 2, .other: 1
        ],
        "chase_southwest_rapid_rewards_premier": [
            .transit: 2, .other: 1
        ],
        "chase_ihg_one_rewards_premier": [
            .hotels: 10, .airlines: 5, .gas: 5, .dining: 5, .other: 3
        ],
        "chase_ihg_one_rewards_traveler": [
            .hotels: 5, .airlines: 2, .gas: 2, .dining: 2, .other: 1
        ],
        "chase_world_of_hyatt": [
            .hotels: 4, .transit: 2, .other: 1
        ],
        "chase_disney_inspire_visa": [
            .streaming: 10, .gas: 3, .dining: 2, .groceries: 2, .other: 1
        ],
        "chase_disney_premier_visa": [
            .streaming: 5, .airlines: 2, .other: 1
        ],
        "chase_disney_visa": [
            .streaming: 3, .other: 1
        ],
    ]

    // Portal caveats: cardID + category -> note shown beneath the top recommendation
    // Only populated when the elevated rate requires booking through a specific portal
    static let portalNotes: [String: [SpendingCategory: String]] = [
        "american_express_platinum_card": [
            .airlines: "5x on flights booked through Amex Travel or directly with airlines",
            .hotels:   "5x on hotels booked through Amex Travel"
        ],
        "american_express_gold_card": [
            .airlines: "3x on flights booked directly with airlines or through Amex Travel"
        ],
        "chase_sapphire_reserve": [
            .airlines: "4x on travel purchased through Chase Travel",
            .hotels:   "4x on travel purchased through Chase Travel"
        ],
        "chase_sapphire_preferred": [
            .airlines: "2x on travel purchased through Chase Travel",
            .hotels:   "2x on travel purchased through Chase Travel"
        ],
        "chase_freedom_unlimited": [
            .airlines: "5x on travel purchased through Chase Travel"
        ],
        "chase_freedom_flex": [
            .airlines: "5x on travel purchased through Chase Travel"
        ],
        "capital_one_venture_x": [
            .hotels:   "10x on hotels booked through Capital One Travel",
            .carRentals: "10x on car rentals booked through Capital One Travel",
            .airlines: "5x on flights booked through Capital One Travel"
        ],
        "capital_one_venture": [
            .hotels:   "5x on hotels & rental cars booked through Capital One Travel"
        ],
        "citi_strata_premier": [
            .hotels:   "10x on hotels booked through CitiTravel.com",
            .carRentals: "10x on car rentals booked through CitiTravel.com"
        ],
        "usb_altitude_reserve": [
            .hotels:   "5x on hotels, airlines, and car rentals via the Rewards Center Travel portal",
            .airlines: "5x on hotels, airlines, and car rentals via the Rewards Center Travel portal",
            .carRentals: "5x on hotels, airlines, and car rentals via the Rewards Center Travel portal"
        ],
        "chase_ihg_one_rewards_premier": [
            .hotels: "10x on IHG hotel stays booked through IHG.com or the IHG app"
        ],
        "chase_ihg_one_rewards_traveler": [
            .hotels: "5x on IHG hotel stays booked through IHG.com or the IHG app"
        ],
        "chase_world_of_hyatt": [
            .hotels: "4x on Hyatt hotel stays (must be a Hyatt property)"
        ],
        "american_express_hilton_honors_aspire_card": [
            .hotels: "14x at Hilton properties worldwide"
        ],
        "american_express_hilton_honors_surpass_card": [
            .hotels: "12x at Hilton properties worldwide"
        ],
        "american_express_hilton_honors_card": [
            .hotels: "7x at Hilton properties worldwide"
        ],
        "chase_united_explorer": [
            .airlines: "2x on United purchases"
        ],
        "chase_united_quest": [
            .airlines: "3x on United purchases"
        ],
        "chase_united_gateway": [
            .airlines: "2x on United purchases"
        ],
        "chase_united_club": [
            .airlines: "4x on United purchases"
        ],
        "chase_disney_inspire_visa": [
            .streaming: "10x on Disney purchases"
        ],
    ]

    // MARK: - Best Cards Logic

    struct CardResult {
        let card: UserCard
        let multiplier: Double
        let effectiveReturnPct: Double
        let programName: String
        let cpp: Double
        let portalNote: String?
    }

    static func bestCards(
        for category: SpendingCategory,
        from userCards: [UserCard]
    ) -> [CardResult] {
        var results: [CardResult] = []

        for card in userCards {
            let cardID = card.catalogCardID
            guard let program = programs[cardID] else { continue }

            let cardRates = rates[cardID] ?? [:]
            let multiplier = cardRates[category] ?? cardRates[SpendingCategory.other] ?? 1.0
            let effectiveReturnPct = multiplier * program.cpp / 100.0
            let portalNote = portalNotes[cardID]?[category]

            results.append(CardResult(
                card: card,
                multiplier: multiplier,
                effectiveReturnPct: effectiveReturnPct,
                programName: program.name,
                cpp: program.cpp,
                portalNote: portalNote
            ))
        }

        return results.sorted { $0.effectiveReturnPct > $1.effectiveReturnPct }
    }
}

// MARK: - Recommendations View

struct RecommendationsView: View {
    @Query private var userCards: [UserCard]

    var body: some View {
        NavigationStack {
            Group {
                if userCards.isEmpty {
                    ContentUnavailableView(
                        "No Cards in Wallet",
                        systemImage: "creditcard.slash",
                        description: Text("Add credit cards to your wallet to see which card gives the best return for each spending category.")
                    )
                } else {
                    cardList
                }
            }
            .navigationTitle("Best Card")
        }
    }

    private var cardList: some View {
        List {
            ForEach(SpendingCategory.allCases, id: \.self) { category in
                let results = CardRecommendationEngine.bestCards(for: category, from: userCards)
                if !results.isEmpty {
                    Section {
                        categoryRows(for: category, results: results)
                    } header: {
                        Label(category.rawValue, systemImage: category.systemImage)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .textCase(nil)
                    }
                }
            }

            Section {
                Text("Point values are estimates based on typical transfer partner redemptions. Hilton/IHG points are worth less per point than Amex/Chase points. Cash back values are exact.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("About Point Valuations")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .textCase(nil)
            }
        }
    }

    @ViewBuilder
    private func categoryRows(for category: SpendingCategory, results: [CardRecommendationEngine.CardResult]) -> some View {
        let top = results[0]
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(top.card.name)
                        .font(.body)
                        .fontWeight(.semibold)
                    Text(top.card.issuer)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(multiplierString(top.multiplier))
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(String(format: "%.1f%% return", top.effectiveReturnPct * 100))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.green)
                }
            }
            Text(top.programName)
                .font(.caption2)
                .foregroundStyle(.tertiary)

            if let note = top.portalNote {
                Label(note, systemImage: "info.circle")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            let runnerUps = Array(results.dropFirst().prefix(2))
            if !runnerUps.isEmpty {
                Divider()
                    .padding(.vertical, 2)
                ForEach(runnerUps.indices, id: \.self) { idx in
                    let r = runnerUps[idx]
                    HStack {
                        Text(r.card.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(String(format: "%@ · %.1f%% return", multiplierString(r.multiplier), r.effectiveReturnPct * 100))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func multiplierString(_ multiplier: Double) -> String {
        if multiplier == multiplier.rounded() {
            return String(format: "%.0fx", multiplier)
        } else {
            return String(format: "%.1fx", multiplier)
        }
    }
}

#Preview {
    RecommendationsView()
        .modelContainer(for: [UserCard.self, BenefitCompletion.self, NotificationSettings.self], inMemory: true)
}
