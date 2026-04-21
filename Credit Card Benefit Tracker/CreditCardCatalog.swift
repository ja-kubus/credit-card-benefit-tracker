//
//  CreditCardCatalog.swift
//  Credit Card Benefit Tracker
//
//  Created by Jacob Michalik on 4/20/26.
//

import Foundation

struct CreditCardCatalog {
    static let all: [CatalogCard] = [

        // ─────────────────────────────────────────────────────────────────
        // AMERICAN EXPRESS
        // ─────────────────────────────────────────────────────────────────

        CatalogCard(
            name: "Platinum Card",
            issuer: "American Express",
            annualFee: 895,
            imageName: "amex_platinum",
            accentColor: "#A8A9AD",
            benefits: [
                // Monthly
                CatalogBenefit(
                    name: "Uber Cash",
                    description: "$15/month in Uber Cash for U.S. rides & Uber Eats (bonus $20 in December = $200/year total). Add Platinum Card to Uber account and select an Amex card for your transaction.",
                    dollarAmount: 15, period: .monthly),
                CatalogBenefit(
                    name: "Uber One Membership Credit",
                    description: "$10/month statement credit when you pay for auto-renewing Uber One membership with your Platinum Card ($120/year).",
                    dollarAmount: 10, period: .monthly),
                CatalogBenefit(
                    name: "Digital Entertainment Credit",
                    description: "Up to $25/month for Disney+, ESPN+, Hulu, The New York Times, Paramount+, Peacock, The Wall Street Journal, YouTube Premium, or YouTube TV ($300/year). Enrollment required.",
                    dollarAmount: 25, period: .monthly),
                CatalogBenefit(
                    name: "Walmart+ Membership Credit",
                    description: "Up to $12.95/month statement credit for one Walmart+ monthly membership (subject to auto-renewal) when you pay with the Platinum Card.",
                    dollarAmount: 12.95, period: .monthly),
                // Quarterly
                CatalogBenefit(
                    name: "Resy Dining Credit",
                    description: "Up to $100/quarter ($400/year) in statement credits for eligible purchases at U.S. Resy restaurants or other eligible Resy purchases. Enrollment required.",
                    dollarAmount: 100, period: .quarterly),
                CatalogBenefit(
                    name: "lululemon Credit",
                    description: "Up to $75/quarter ($300/year) at U.S. lululemon retail stores (excluding outlets) and lululemon.com. Enrollment required.",
                    dollarAmount: 75, period: .quarterly),
                // Semi-annually
                CatalogBenefit(
                    name: "Fine Hotels + Resorts Hotel Credit",
                    description: "Up to $300 semi-annually ($600/year) on prepaid Fine Hotels + Resorts® or The Hotel Collection bookings through American Express Travel® (Hotel Collection requires 2-night minimum stay).",
                    dollarAmount: 300, period: .semiAnnually),
                // Annually
                CatalogBenefit(
                    name: "CLEAR+ Membership Credit",
                    description: "Up to $209/year toward a CLEAR+ membership after paying with your Platinum Card. Helps you get through airport security faster at 55+ airports.",
                    dollarAmount: 209, period: .annually),
                CatalogBenefit(
                    name: "Airline Fee Credit",
                    description: "Up to $200/year in statement credits for incidental airline fees (checked bags, in-flight refreshments, etc.) charged to your Platinum Card. Select one qualifying airline.",
                    dollarAmount: 200, period: .annually),
                CatalogBenefit(
                    name: "Global Entry / TSA PreCheck Credit",
                    description: "Up to $120 statement credit every 4.5 years for Global Entry application fee ($100) or TSA PreCheck® application fee ($85).",
                    dollarAmount: 120, period: .annually),
                CatalogBenefit(
                    name: "Saks Fifth Avenue Credit",
                    description: "Up to $50 in statement credits at Saks Fifth Avenue or saks.com January–June, and up to $50 July–December ($100/year). Enrollment required.",
                    dollarAmount: 50, period: .semiAnnually),
            ]
        ),

        CatalogCard(
            name: "Gold Card",
            issuer: "American Express",
            annualFee: 325,
            imageName: "amex_gold",
            accentColor: "#C6973F",
            benefits: [
                CatalogBenefit(
                    name: "Uber Cash",
                    description: "$10/month in Uber Cash for U.S. Uber rides or Uber Eats orders ($120/year). Add your Gold Card to your Uber account and select an Amex card for your transaction.",
                    dollarAmount: 10, period: .monthly),
                CatalogBenefit(
                    name: "Dining Credit",
                    description: "Up to $10/month ($120/year) in statement credits at Grubhub, The Cheesecake Factory, Goldbelly, Wine.com, and Five Guys. Enrollment required.",
                    dollarAmount: 10, period: .monthly),
                CatalogBenefit(
                    name: "Dunkin' Credit",
                    description: "Up to $7/month ($84/year) in statement credits at U.S. Dunkin' locations after enrollment.",
                    dollarAmount: 7, period: .monthly),
                CatalogBenefit(
                    name: "Resy Credit",
                    description: "Up to $50 semi-annually ($100/year) in statement credits at U.S. Resy restaurants. Enrollment required.",
                    dollarAmount: 50, period: .semiAnnually),
            ]
        ),

        CatalogCard(
            name: "Blue Cash Preferred",
            issuer: "American Express",
            annualFee: 95,
            imageName: "amex_bcp",
            accentColor: "#007BC1",
            benefits: [
                CatalogBenefit(
                    name: "Disney Bundle Credit",
                    description: "Up to $10/month ($120/year) in statement credits for Disney+, Hulu, or ESPN+ bundle subscription purchases at DisneyPlus.com, Hulu.com, or Stream.ESPN.com. Enrollment required.",
                    dollarAmount: 10, period: .monthly),
            ]
        ),

        // Hilton Honors Cards
        CatalogCard(
            name: "Hilton Honors Aspire Card",
            issuer: "American Express",
            annualFee: 550,
            imageName: "amex_hilton_aspire",
            accentColor: "#1A2B5E",
            benefits: [
                CatalogBenefit(
                    name: "Hilton Resort Credit",
                    description: "Up to $200 in statement credits semi-annually ($400/year) for eligible purchases at Hilton Resorts worldwide charged to your Aspire Card.",
                    dollarAmount: 200, period: .semiAnnually),
                CatalogBenefit(
                    name: "Flight Credit",
                    description: "Up to $100 semi-annually ($200/year) in statement credits for eligible flight purchases booked directly with airlines or through amextravel.com.",
                    dollarAmount: 100, period: .semiAnnually),
                CatalogBenefit(
                    name: "Free Night Reward",
                    description: "Earn one Free Night Reward each card anniversary year. Redeemable at most Hilton portfolio properties worldwide.",
                    dollarAmount: 0, period: .annually),
            ]
        ),

        CatalogCard(
            name: "Hilton Honors Surpass Card",
            issuer: "American Express",
            annualFee: 150,
            imageName: "amex_hilton_surpass",
            accentColor: "#2A4078",
            benefits: [
                CatalogBenefit(
                    name: "Hilton Honors Free Night Reward",
                    description: "Earn one Free Night Reward after spending $15,000 on eligible purchases on your Card in a calendar year (up to 100,000 Hilton Honors points value).",
                    dollarAmount: 100, period: .annually),
                CatalogBenefit(
                    name: "Hilton Credit",
                    description: "Up to $50/quarter ($200/year) in statement credits for eligible purchases at Hilton Honors participating hotels, including rooms, dining, and spa, when using your Surpass Card.",
                    dollarAmount: 50, period: .quarterly),
            ]
        ),

        CatalogCard(
            name: "Hilton Honors Card",
            issuer: "American Express",
            annualFee: 0,
            imageName: "amex_hilton_honors",
            accentColor: "#3C5A9A",
            benefits: []
        ),

        // ─────────────────────────────────────────────────────────────────
        // CHASE
        // ─────────────────────────────────────────────────────────────────

        CatalogCard(
            name: "Sapphire Reserve",
            issuer: "Chase",
            annualFee: 795,
            imageName: "chase_csr",
            accentColor: "#1A1A2E",
            benefits: [
                // Annually
                CatalogBenefit(
                    name: "Annual Travel Credit",
                    description: "Up to $300/year in statement credits automatically applied to travel purchases (taxis, Uber, trains, flights, hotels, campground fees, and more).",
                    dollarAmount: 300, period: .annually),
                CatalogBenefit(
                    name: "Global Entry / TSA PreCheck / NEXUS Credit",
                    description: "Up to $120 statement credit every 4 years for Global Entry, TSA PreCheck®, or NEXUS application fee.",
                    dollarAmount: 120, period: .annually),
                // Semi-annually
                CatalogBenefit(
                    name: "The Edit Hotel Credit",
                    description: "Up to $250 semi-annually ($500/year) toward bookings at The Edit — 1,000+ high-end hotels and resorts through Chase Travel.",
                    dollarAmount: 250, period: .semiAnnually),
                CatalogBenefit(
                    name: "Sapphire Reserve Exclusive Tables Dining Credit",
                    description: "Up to $150 semi-annually ($300/year) for dining at restaurants participating in the Sapphire Reserve Exclusive Tables program.",
                    dollarAmount: 150, period: .semiAnnually),
                CatalogBenefit(
                    name: "StubHub / viagogo Credit",
                    description: "Up to $150 semi-annually ($300/year) for ticket purchases on StubHub and viagogo.",
                    dollarAmount: 150, period: .semiAnnually),
                CatalogBenefit(
                    name: "Apple TV+ & Apple Music Credit",
                    description: "Up to $125 semi-annually ($250/year) toward Apple TV+ and Apple Music subscriptions.",
                    dollarAmount: 125, period: .semiAnnually),
                // Monthly
                CatalogBenefit(
                    name: "Lyft Credit",
                    description: "Up to $10/month ($120/year) in Lyft credits through September 30, 2027.",
                    dollarAmount: 10, period: .monthly),
                CatalogBenefit(
                    name: "DoorDash Restaurant Credit",
                    description: "$5/month promo on restaurant DoorDash orders (plus free DashPass subscription valued at ~$120/year). Activate DashPass to unlock.",
                    dollarAmount: 5, period: .monthly),
                CatalogBenefit(
                    name: "DoorDash Non-Restaurant Credit",
                    description: "Two $10/month promos ($20/month) on non-restaurant DoorDash orders (groceries, beauty, electronics, etc.).",
                    dollarAmount: 20, period: .monthly),
                CatalogBenefit(
                    name: "Peloton Credit",
                    description: "Up to $10/month ($120/year) toward an eligible Peloton membership.",
                    dollarAmount: 10, period: .monthly),
            ]
        ),

        CatalogCard(
            name: "Sapphire Preferred",
            issuer: "Chase",
            annualFee: 95,
            imageName: "chase_csp",
            accentColor: "#4A90D9",
            benefits: [
                CatalogBenefit(
                    name: "Annual Hotel Credit",
                    description: "Up to $50/year in statement credits for hotel stays purchased through Chase Travel℠. Applied each account anniversary year.",
                    dollarAmount: 50, period: .annually),
                CatalogBenefit(
                    name: "DoorDash DashPass Credit",
                    description: "Complimentary DashPass subscription (value ~$10/month) unlocking $0 delivery fees and lower service fees. Activate by 12/31/27.",
                    dollarAmount: 10, period: .monthly),
            ]
        ),

        CatalogCard(
            name: "Freedom Unlimited",
            issuer: "Chase",
            annualFee: 0,
            imageName: "chase_cfu",
            accentColor: "#2C5F8A",
            benefits: []
        ),

        CatalogCard(
            name: "Freedom Flex",
            issuer: "Chase",
            annualFee: 0,
            imageName: "chase_cff",
            accentColor: "#1A4B73",
            benefits: [
                CatalogBenefit(
                    name: "5% Quarterly Rotating Categories",
                    description: "5% cash back on up to $1,500 in combined purchases in rotating quarterly categories (e.g., grocery stores, gas stations, select streaming, Amazon, etc.). Activation required each quarter.",
                    dollarAmount: 75, period: .quarterly),
            ]
        ),

        CatalogCard(
            name: "Amazon Prime Visa",
            issuer: "Chase",
            annualFee: 0,
            imageName: "chase_amazon_prime",
            accentColor: "#FF9900",
            benefits: []
        ),

        // ─────────────────────────────────────────────────────────────────
        // CAPITAL ONE
        // ─────────────────────────────────────────────────────────────────

        CatalogCard(
            name: "Venture X",
            issuer: "Capital One",
            annualFee: 395,
            imageName: "cap1_venturex",
            accentColor: "#CC0001",
            benefits: [
                CatalogBenefit(
                    name: "Annual Travel Credit",
                    description: "Up to $300/year credit for bookings through Capital One Travel portal. Applied automatically.",
                    dollarAmount: 300, period: .annually),
                CatalogBenefit(
                    name: "Anniversary Miles Bonus",
                    description: "Earn 10,000 bonus miles (= $100 toward travel) every year starting on your first anniversary.",
                    dollarAmount: 100, period: .annually),
                CatalogBenefit(
                    name: "Global Entry / TSA PreCheck Credit",
                    description: "Up to $120 statement credit every 4 years for Global Entry or TSA PreCheck® application fee.",
                    dollarAmount: 120, period: .annually),
            ]
        ),

        CatalogCard(
            name: "Venture",
            issuer: "Capital One",
            annualFee: 95,
            imageName: "cap1_venture",
            accentColor: "#9B0000",
            benefits: [
                CatalogBenefit(
                    name: "Global Entry / TSA PreCheck Credit",
                    description: "Up to $120 statement credit every 4 years for Global Entry or TSA PreCheck® application fee.",
                    dollarAmount: 120, period: .annually),
            ]
        ),

        CatalogCard(
            name: "SavorOne",
            issuer: "Capital One",
            annualFee: 0,
            imageName: "cap1_savorone",
            accentColor: "#7B2D8B",
            benefits: []
        ),

        // ─────────────────────────────────────────────────────────────────
        // CITI
        // ─────────────────────────────────────────────────────────────────

        CatalogCard(
            name: "Strata Premier",
            issuer: "Citi",
            annualFee: 95,
            imageName: "citi_strata_premier",
            accentColor: "00529B",
            benefits: [
                CatalogBenefit(
                    name: "Annual Hotel Savings Benefit",
                    description: "$100 off a single hotel stay of $500 or more (excluding taxes and fees) booked through thankyou.com once per calendar year.",
                    dollarAmount: 100, period: .annually),
            ]
        ),

        CatalogCard(
            name: "Double Cash",
            issuer: "Citi",
            annualFee: 0,
            imageName: "citi_doublecash",
            accentColor: "#003087",
            benefits: []
        ),

        // ─────────────────────────────────────────────────────────────────
        // APPLE
        // ─────────────────────────────────────────────────────────────────

        CatalogCard(
            name: "Apple Card",
            issuer: "Apple",
            annualFee: 0,
            imageName: "apple_card",
            accentColor: "#888888",
            benefits: []
        ),

        // ─────────────────────────────────────────────────────────────────
        // DISCOVER
        // ─────────────────────────────────────────────────────────────────

        CatalogCard(
            name: "it Cash Back",
            issuer: "Discover",
            annualFee: 0,
            imageName: "discover_it",
            accentColor: "#FF6600",
            benefits: [
                CatalogBenefit(
                    name: "5% Quarterly Rotating Categories",
                    description: "5% cash back on up to $1,500 in purchases each quarter in rotating categories (e.g., grocery stores, restaurants, gas stations, Amazon). Activation required each quarter.",
                    dollarAmount: 75, period: .quarterly),
            ]
        ),

        // ─────────────────────────────────────────────────────────────────
        // WELLS FARGO
        // ─────────────────────────────────────────────────────────────────

        CatalogCard(
            name: "Autograph Journey",
            issuer: "Wells Fargo",
            annualFee: 95,
            imageName: "wf_autograph_journey",
            accentColor: "#CD1409",
            benefits: [
                CatalogBenefit(
                    name: "Annual Airline Credit",
                    description: "Up to $50/year in statement credits toward airline purchases (airfare, seat upgrades, in-flight purchases, and more).",
                    dollarAmount: 50, period: .annually),
                CatalogBenefit(
                    name: "Annual Hotel Credit",
                    description: "Earn an additional $50 statement credit when you spend $50 or more on hotel purchases in a calendar year.",
                    dollarAmount: 50, period: .annually),
            ]
        ),

        // ─────────────────────────────────────────────────────────────────
        // BANK OF AMERICA
        // ─────────────────────────────────────────────────────────────────

        CatalogCard(
            name: "Premium Rewards Elite",
            issuer: "Bank of America",
            annualFee: 550,
            imageName: "boa_premium_elite",
            accentColor: "#E31837",
            benefits: [
                CatalogBenefit(
                    name: "Airline Incidental Credit",
                    description: "Up to $300/year in statement credits for incidental airline purchases (seat upgrades, baggage fees, lounge day passes, etc.).",
                    dollarAmount: 300, period: .annually),
                CatalogBenefit(
                    name: "Lifestyle Credit",
                    description: "Up to $150/year for qualifying lifestyle purchases (fitness clubs, streaming services, and more).",
                    dollarAmount: 150, period: .annually),
                CatalogBenefit(
                    name: "Global Entry / TSA PreCheck Credit",
                    description: "Up to $100 credit every 4 years for Global Entry or TSA PreCheck® application fee.",
                    dollarAmount: 100, period: .annually),
            ]
        ),

        // ─────────────────────────────────────────────────────────────────
        // U.S. BANK
        // ─────────────────────────────────────────────────────────────────

        CatalogCard(
            name: "Altitude Reserve",
            issuer: "U.S. Bank",
            annualFee: 400,
            imageName: "usb_altitude_reserve",
            accentColor: "#002244",
            benefits: [
                CatalogBenefit(
                    name: "Real-Time Mobile Wallet & Travel Credit",
                    description: "Up to $325/year in statement credits for eligible mobile wallet (Apple Pay, Google Pay, Samsung Pay) and travel purchases. Automatically applied.",
                    dollarAmount: 325, period: .annually),
            ]
        ),
    ]

    /// Returns catalog cards not yet in the user's wallet
    static func available(excluding ownedIDs: Set<String>) -> [CatalogCard] {
        all.filter { !ownedIDs.contains("\($0.issuer):\($0.name)") }
    }
}
