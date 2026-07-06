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
                    dollarAmount: 15, period: .monthly, category: .miscellaneous),
                CatalogBenefit(
                    name: "Uber One Membership Credit",
                    description: "$10/month statement credit when you pay for auto-renewing Uber One membership with your Platinum Card ($120/year).",
                    dollarAmount: 10, period: .monthly, category: .miscellaneous),
                CatalogBenefit(
                    name: "Digital Entertainment Credit",
                    description: "Up to $25/month for Disney+, ESPN+, Hulu, The New York Times, Paramount+, Peacock, The Wall Street Journal, YouTube Premium, or YouTube TV ($300/year). Enrollment required.",
                    dollarAmount: 25, period: .monthly, category: .entertainment),
                CatalogBenefit(
                    name: "Walmart+ Membership Credit",
                    description: "Up to $12.95/month statement credit for one Walmart+ monthly membership (subject to auto-renewal) when you pay with the Platinum Card.",
                    dollarAmount: 12.95, period: .monthly, category: .shopping),
                // Quarterly
                CatalogBenefit(
                    name: "Resy Dining Credit",
                    description: "Up to $100/quarter ($400/year) in statement credits for eligible purchases at U.S. Resy restaurants or other eligible Resy purchases. Enrollment required.",
                    dollarAmount: 100, period: .quarterly, category: .dining),
                CatalogBenefit(
                    name: "lululemon Credit",
                    description: "Up to $75/quarter ($300/year) at U.S. lululemon retail stores (excluding outlets) and lululemon.com. Enrollment required.",
                    dollarAmount: 75, period: .quarterly, category: .shopping),
                // Semi-annually
                CatalogBenefit(
                    name: "Fine Hotels + Resorts Hotel Credit",
                    description: "Up to $300 semi-annually ($600/year) on prepaid Fine Hotels + Resorts® or The Hotel Collection bookings through American Express Travel® (Hotel Collection requires 2-night minimum stay).",
                    dollarAmount: 300, period: .semiAnnually, category: .travel),
                // Annually
                CatalogBenefit(
                    name: "CLEAR+ Membership Credit",
                    description: "Up to $209/year toward a CLEAR+ membership after paying with your Platinum Card. Helps you get through airport security faster at 55+ airports.",
                    dollarAmount: 209, period: .annually, category: .travel),
                CatalogBenefit(
                    name: "Airline Fee Credit",
                    description: "Up to $200/year in statement credits for incidental airline fees (checked bags, in-flight refreshments, etc.) charged to your Platinum Card. Select one qualifying airline.",
                    dollarAmount: 200, period: .annually, category: .travel),
                CatalogBenefit(
                    name: "Global Entry / TSA PreCheck Credit",
                    description: "Up to $120 statement credit every 4.5 years for Global Entry application fee ($100) or TSA PreCheck® application fee ($85).",
                    dollarAmount: 120, period: .annually, category: .travel),
                CatalogBenefit(
                    name: "Saks Fifth Avenue Credit",
                    description: "Up to $50 in statement credits at Saks Fifth Avenue or saks.com January–June, and up to $50 July–December ($100/year). Enrollment required.",
                    dollarAmount: 50, period: .semiAnnually, category: .shopping),
                CatalogBenefit(name: "Delta Sky Club Visits", description: "Up to 10 Delta Sky Club visits when flying on an eligible Delta flight.", dollarAmount: 0, period: .annually, category: .travel),
                CatalogBenefit(name: "Marriott Bonvoy Gold Elite Status", description: "Enjoy complimentary Marriott Bonvoy Gold Elite Status.", dollarAmount: 0, period: .annually, category: .travel),
                CatalogBenefit(name: "Hilton Honors Gold Status", description: "Enjoy complimentary Hilton Honors Gold Status.", dollarAmount: 0, period: .annually, category: .travel),
                CatalogBenefit(name: "Platinum Member Airfares", description: "Explore select seats with over 30 participating airlines on designated flights with Platinum Member Airfares when booked through Amex Travel.", dollarAmount: 0, period: .annually, category: .travel),
                CatalogBenefit(name: "Fine Hotels + Resorts Benefits", description: "Enjoy 12 PM Check-In, $100 credit towards eligible charges, room upgrade upon arrival, wifi, breakfast for two, and guaranteed 4pm check-out at Fine Hotels + Resorts.", dollarAmount: 0, period: .annually, category: .travel),
            ]
        ),

        CatalogCard(
            name: "Gold Card",
            issuer: "American Express",
            annualFee: 325,
            imageName: "amex_gold",
            accentColor: "#C6973F",
            benefits: [
                //monthly
                CatalogBenefit(
                    name: "Uber Cash",
                    description: "$10/month in Uber Cash for U.S. Uber rides or Uber Eats orders ($120/year). Add your Gold Card to your Uber account and select an Amex card for your transaction.",
                    dollarAmount: 10, period: .monthly, category: .miscellaneous),
                CatalogBenefit(
                    name: "Dining Credit",
                    description: "Up to $10/month ($120/year) in statement credits at Grubhub, The Cheesecake Factory, Goldbelly, Wine.com, and Five Guys. Enrollment required.",
                    dollarAmount: 10, period: .monthly, category: .dining),
                CatalogBenefit(
                    name: "Dunkin' Credit",
                    description: "Up to $7/month ($84/year) in statement credits at U.S. Dunkin' locations after enrollment.",
                    dollarAmount: 7, period: .monthly, category: .dining),
                
                //semi-annually
                CatalogBenefit(
                    name: "Resy Credit",
                    description: "Up to $50 semi-annually ($100/year) in statement credits at U.S. Resy restaurants. Enrollment required.",
                    dollarAmount: 50, period: .semiAnnually, category: .dining),
                
                //annually
                CatalogBenefit(name: "Hertz Five Star Status", description: "Complimentary Hertz Five Star Status", dollarAmount: 0, period: .annually, category: .miscellaneous),
                CatalogBenefit(name: "The Hotel Collection", description: "Enjoy $100 credit for eligible charges at hotels part of The Hotel Collection during a two-night minimum stay.", dollarAmount: 100, period: .annually, category: .travel),
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
                    dollarAmount: 10, period: .monthly, category: .entertainment),
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
                    dollarAmount: 200, period: .semiAnnually, category: .travel),
                CatalogBenefit(
                    name: "Flight Credit",
                    description: "Up to $50 each quarter ($200/year) in statement credits for eligible flight purchases booked directly with airlines or through amextravel.com.",
                    dollarAmount: 50, period: .quarterly, category: .travel),
                CatalogBenefit(
                    name: "Free Night Reward",
                    description: "Earn one Free Night Reward each card anniversary year. Redeemable at most Hilton portfolio properties worldwide.",
                    dollarAmount: 0, period: .annually, category: .miscellaneous),
                CatalogBenefit(name: "CLEAR+ Credit", description: "$209 annually for CLEAR+. See terms and conditions.", dollarAmount: 209, period: .annually, category: .travel),
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
                    dollarAmount: 0, period: .annually, category: .travel),
                CatalogBenefit(
                    name: "Hilton Credit",
                    description: "Up to $50/quarter ($200/year) in statement credits for eligible purchases at Hilton Honors participating hotels, including rooms, dining, and spa, when using your Surpass Card.",
                    dollarAmount: 50, period: .quarterly, category: .miscellaneous),
                CatalogBenefit(name: "Nation Car Rental Emerald Clb Executive Status", description: "Earn complimentary status with National Car Rental including perks like Execute Area Access.", dollarAmount: 0, period: .annually, category: .travel),
            ]
        ),

        CatalogCard(
            name: "Hilton Honors Card",
            issuer: "American Express",
            annualFee: 0,
            imageName: "amex_hilton_honors",
            accentColor: "#3C5A9A",
            benefits: [
                CatalogBenefit(name: "Hilton Honors Silver Status", description: "Enjoy complimentary Hilton Honors Silver Status", dollarAmount: 0, period: .annually, category: .travel),
            ]
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
                    dollarAmount: 300, period: .annually, category: .travel),
                CatalogBenefit(
                    name: "Global Entry / TSA PreCheck / NEXUS Credit",
                    description: "Up to $120 statement credit every 4 years for Global Entry, TSA PreCheck®, or NEXUS application fee.",
                    dollarAmount: 120, period: .annually, category: .travel),
                // Semi-annually
                CatalogBenefit(
                    name: "The Edit Hotel Credit",
                    description: "Up to $500 toward bookings at The Edit — 1,000+ high-end hotels and resorts through Chase Travel, with complimentary benefits like $100 property credit, breakfast for two, a room upgrade and more. Two-night minimum, max of $250 per transaction.",
                    dollarAmount: 500, period: .annually, category: .travel),
                CatalogBenefit(
                    name: "Sapphire Reserve Exclusive Tables Dining Credit",
                    description: "Up to $150 semi-annually ($300/year) for dining at restaurants participating in the Sapphire Reserve Exclusive Tables program.",
                    dollarAmount: 150, period: .semiAnnually, category: .dining),
                CatalogBenefit(name: "$250 Credit Chase Travel Hotels", description: "$250 in statement credit for stays with IHG, Montage, Pendy, Omni, and more. Two-night minimum required. Can stack with the Edit!", dollarAmount: 250, period: .annually, category: .travel),
                CatalogBenefit(name: "IHG One Rewards Platinum Elite Status", description: "Enjoy Platinum Elite Status by linking your IHG One Rewards membership.", dollarAmount: 0, period: .annually, category: .travel),
                CatalogBenefit(name: "Global Entry, TSA PreCheck, or NEXUS credit", description: "Receive $120 every four years as a reimbursement for the application fee at any of these partners.", dollarAmount: 120, period: .annually, category: .travel),
                CatalogBenefit(
                    name: "StubHub / viagogo Credit",
                    description: "Up to $150 semi-annually ($300/year) for ticket purchases on StubHub and viagogo.",
                    dollarAmount: 150, period: .semiAnnually, category: .entertainment),
                CatalogBenefit(
                    name: "Apple TV+ & Apple Music Credit",
                    description: "Complimentary subscriptions to Apple TV and Apple Music, a value of $288 annually.",
                    dollarAmount: 288, period: .annually, category: .entertainment),
                // Monthly
                CatalogBenefit(
                    name: "Lyft Credit",
                    description: "Up to $10/month ($120/year) in Lyft credits through September 30, 2027.",
                    dollarAmount: 10, period: .monthly, category: .travel),
                CatalogBenefit(
                    name: "DoorDash Restaurant Credit",
                    description: "$5/month promo on restaurant DoorDash orders.",
                    dollarAmount: 5, period: .monthly, category: .dining),
                CatalogBenefit(
                    name: "DoorDash Non-Restaurant Credit",
                    description: "Two $10/month promos ($20/month) on non-restaurant DoorDash orders (groceries, beauty, electronics, etc.).",
                    dollarAmount: 20, period: .monthly, category: .miscellaneous),
                CatalogBenefit(name: "Complimentary DashPass", description: "Complimentary DashPass subscription (value ~$10/month) unlocking $0 delivery fees and lower service fees. Activate by 12/31/27.", dollarAmount: 120, period: .annually, category: .miscellaneous),
                CatalogBenefit(
                    name: "Peloton Credit",
                    description: "Up to $10/month ($120/year) toward an eligible Peloton membership.",
                    dollarAmount: 10, period: .monthly, category: .shopping),
                CatalogBenefit(name: "Chase Sapphire Reserve Lounge Network", description: "Enjoy complimentary access to every Chase Sapphire Lounge by The Club with up to two guests, plus access to 1,300+ Priority Pass lounges worldwide.", dollarAmount: 0, period: .annually, category: .travel),
                
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
                    description: "Up to $100/year in statement credits for hotel stays purchased through Chase Travel℠. Applied each account anniversary year. (Doubled from $50 in the June 2026 refresh.)",
                    dollarAmount: 100, period: .annually, category: .travel),
                CatalogBenefit(
                    name: "Global Entry / TSA PreCheck / NEXUS Credit",
                    description: "Up to $120 statement credit every 4 years for Global Entry, TSA PreCheck®, or NEXUS application fee. Added in the June 2026 refresh.",
                    dollarAmount: 120, period: .annually, category: .travel),
                CatalogBenefit(
                    name: "Apple TV+ Subscription",
                    description: "Complimentary Apple TV+ subscription for one year. Must activate by 12/31/2026.",
                    dollarAmount: 0, period: .annually, category: .entertainment),
                CatalogBenefit(
                    name: "DoorDash DashPass Credit",
                    description: "Complimentary DashPass subscription (value ~$10/month) unlocking $0 delivery fees and lower service fees. Activate by 12/31/27.",
                    dollarAmount: 10, period: .monthly, category: .miscellaneous),
                CatalogBenefit(name: "DashPass Spend Credit", description: "Enjoy $10 a month to save on orders through DoorDash.", dollarAmount: 10, period: .monthly, category: .miscellaneous),
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
                    dollarAmount: 75, period: .quarterly, category: .shopping),
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
                    dollarAmount: 300, period: .annually, category: .travel),
                CatalogBenefit(
                    name: "Anniversary Miles Bonus",
                    description: "Earn 10,000 bonus miles (= $100 toward travel) every year starting on your first anniversary.",
                    dollarAmount: 100, period: .annually, category: .travel),
                CatalogBenefit(
                    name: "Global Entry / TSA PreCheck Credit",
                    description: "Up to $120 statement credit every 4 years for Global Entry or TSA PreCheck® application fee.",
                    dollarAmount: 120, period: .annually, category: .travel),
                CatalogBenefit(name: "Capital One Lounge Network", description: "Complimentary access to the Capital One Lounge and Priority Pass Lounges.", dollarAmount: 0, period: .annually, category: .travel),
                CatalogBenefit(name: "Herz President's Circle Status", description: "Enjoy complimentary access to the Hertz President's Circle.", dollarAmount: 0, period: .annually, category: .travel),
                CatalogBenefit(name: "Premier Hotel $100 Credit", description: "Enjoy $100 credit for experiences at eligible hotels.", dollarAmount: 100, period: .annually, category: .travel),
                CatalogBenefit(name: "Lifestyle Hotel $50 Credit", description: "Enjoy $50 credit for experiences at eligible hotels.", dollarAmount: 50, period: .annually, category: .travel),
                CatalogBenefit(name: "PRIOR Subscription", description: "Enjoy a complimentary subscription to PRIOR magazine.", dollarAmount: 149, period: .annually, category: .shopping),
                CatalogBenefit(name: "Discounted Membership to the Cultivist", description: "50% off the Enthusiast membership for up to two years.", dollarAmount: 220, period: .annually, category: .shopping),
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
                    dollarAmount: 120, period: .annually, category: .travel),
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
                    dollarAmount: 100, period: .annually, category: .travel),
                CatalogBenefit(name: "The Reserve from Citi", description: "$100 experience credit, breakfast for two, and free wifi at select hotels.", dollarAmount: 100, period: .annually, category: .travel),
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
                    dollarAmount: 75, period: .quarterly, category: .shopping),
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
                    dollarAmount: 50, period: .annually, category: .travel),
                CatalogBenefit(
                    name: "Annual Hotel Credit",
                    description: "Earn an additional $50 statement credit when you spend $50 or more on hotel purchases in a calendar year.",
                    dollarAmount: 50, period: .annually, category: .travel),
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
                    dollarAmount: 300, period: .annually, category: .travel),
                CatalogBenefit(
                    name: "Lifestyle Credit",
                    description: "Up to $150/year for qualifying lifestyle purchases (fitness clubs, streaming services, and more).",
                    dollarAmount: 150, period: .annually, category: .shopping),
                CatalogBenefit(
                    name: "Global Entry / TSA PreCheck Credit",
                    description: "Up to $100 credit every 4 years for Global Entry or TSA PreCheck® application fee.",
                    dollarAmount: 100, period: .annually, category: .travel),
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
                    dollarAmount: 325, period: .annually, category: .travel),
            ]
        ),
    ] + supplementalCards

    private static let supplementalCards: [CatalogCard] = [

        // ─────────────────────────────────────────────────────────────────
        // AMERICAN EXPRESS
        // ─────────────────────────────────────────────────────────────────

        CatalogCard(
            name: "Blue Cash Everyday",
            issuer: "American Express",
            annualFee: 0,
            imageName: "amex_blue_cash_everyday",
            accentColor: "#007BC1",
            benefits: []
        ),

        CatalogCard(
            name: "Green Card",
            issuer: "American Express",
            annualFee: 150,
            imageName: "amex_green",
            accentColor: "#0B5D3B",
            benefits: []
        ),

        CatalogCard(
            name: "Delta SkyMiles Reserve",
            issuer: "American Express",
            annualFee: 650,
            imageName: "amex_delta_reserve",
            accentColor: "#1A2B5E",
            benefits: [
                CatalogBenefit(name: "Annual Companion Certificate", description: "Receive an annual companion certificate after renewal, valid on eligible Delta flights. Terms apply.", dollarAmount: 0, period: .annually, category: .travel),
            ]
        ),

        CatalogCard(
            name: "Delta SkyMiles Platinum",
            issuer: "American Express",
            annualFee: 350,
            imageName: "amex_delta_platinum",
            accentColor: "#2B4A7A",
            benefits: [
                CatalogBenefit(name: "Rideshare Credit", description: "Up to $10/month in statement credits for eligible U.S. rideshare purchases.", dollarAmount: 10, period: .monthly, category: .travel),
                CatalogBenefit(name: "Annual Companion Certificate", description: "Receive an annual companion certificate after renewal, valid on eligible Delta flights. Terms apply.", dollarAmount: 0, period: .annually, category: .travel),
            ]
        ),

        CatalogCard(
            name: "Delta SkyMiles Gold",
            issuer: "American Express",
            annualFee: 150,
            imageName: "amex_delta_gold",
            accentColor: "#B38A2E",
            benefits: []
        ),

        CatalogCard(
            name: "Marriott Bonvoy Boundless",
            issuer: "Chase",
            annualFee: 95,
            imageName: "chase_marriott_boundless",
            accentColor: "#B08D57",
            benefits: [
                CatalogBenefit(name: "Annual Free Night Award", description: "Receive one Free Night Award each card anniversary year. Redeemable at eligible Marriott Bonvoy properties, subject to terms.", dollarAmount: 0, period: .annually, category: .travel),
            ]
        ),

        CatalogCard(
            name: "Marriott Bonvoy Bountiful",
            issuer: "Chase",
            annualFee: 250,
            imageName: "chase_marriott_bountiful",
            accentColor: "#8C6A3D",
            benefits: [
                CatalogBenefit(name: "Annual Free Night Award", description: "Receive one Free Night Award each card anniversary year. Redeemable at eligible Marriott Bonvoy properties, subject to terms.", dollarAmount: 0, period: .annually, category: .travel),
            ]
        ),

        CatalogCard(
            name: "Marriott Bonvoy Bold",
            issuer: "Chase",
            annualFee: 0,
            imageName: "chase_marriott_bold",
            accentColor: "#6B4E2E",
            benefits: []
        ),

        CatalogCard(
            name: "Marriott Bonvoy Bevy",
            issuer: "American Express",
            annualFee: 250,
            imageName: "amex_marriott_bevy",
            accentColor: "#7A5A44",
            benefits: [
                CatalogBenefit(name: "Annual Free Night Award", description: "Receive an annual Free Night Award after account anniversary, subject to terms and eligible properties.", dollarAmount: 0, period: .annually, category: .travel),
            ]
        ),

        CatalogCard(
            name: "Marriott Bonvoy Brilliant",
            issuer: "American Express",
            annualFee: 650,
            imageName: "amex_marriott_brilliant",
            accentColor: "#4C3A2D",
            benefits: [
                CatalogBenefit(name: "Annual Free Night Award", description: "Receive an annual Free Night Award after account anniversary, subject to terms and eligible properties.", dollarAmount: 0, period: .annually, category: .travel),
            ]
        ),

        // ─────────────────────────────────────────────────────────────────
        // CAPITAL ONE
        // ─────────────────────────────────────────────────────────────────

        CatalogCard(name: "Platinum", issuer: "Capital One", annualFee: 0, imageName: "cap1_platinum", accentColor: "#B3B3B3", benefits: []),
        CatalogCard(name: "Quicksilver", issuer: "Capital One", annualFee: 0, imageName: "cap1_quicksilver", accentColor: "#2E5B87", benefits: []),
        CatalogCard(name: "QuicksilverOne", issuer: "Capital One", annualFee: 39, imageName: "cap1_quicksilverone", accentColor: "#355C7D", benefits: []),
        CatalogCard(name: "Savor", issuer: "Capital One", annualFee: 0, imageName: "cap1_savor", accentColor: "#8A1F44", benefits: []),

        CatalogCard(
            name: "VentureOne",
            issuer: "Capital One",
            annualFee: 0,
            imageName: "cap1_ventureone",
            accentColor: "#A00000",
            benefits: []
        ),

        CatalogCard(name: "Quicksilver Secured Rewards", issuer: "Capital One", annualFee: 0, imageName: "cap1_quicksilver_secured", accentColor: "#4C6A8A", benefits: []),
        CatalogCard(name: "Platinum Secured", issuer: "Capital One", annualFee: 0, imageName: "cap1_platinum_secured", accentColor: "#8F8F8F", benefits: []),
        CatalogCard(name: "T-Mobile Visa", issuer: "Capital One", annualFee: 0, imageName: "cap1_tmobile_visa", accentColor: "#E20074", benefits: []),
        CatalogCard(name: "Kohl's Rewards Visa", issuer: "Capital One", annualFee: 0, imageName: "cap1_kohls_rewards", accentColor: "#5B3E96", benefits: []),
        CatalogCard(name: "REI Co-op Mastercard", issuer: "Capital One", annualFee: 0, imageName: "cap1_rei_coop", accentColor: "#2D5B3A", benefits: []),
        CatalogCard(name: "Pottery Barn Key Rewards Visa", issuer: "Capital One", annualFee: 0, imageName: "cap1_pottery_barn_key_rewards", accentColor: "#9B6B4A", benefits: []),
        CatalogCard(name: "Williams Sonoma Key Rewards Visa", issuer: "Capital One", annualFee: 0, imageName: "cap1_williams_sonoma_key_rewards", accentColor: "#6B4E3D", benefits: []),
        CatalogCard(name: "West Elm Key Rewards Visa", issuer: "Capital One", annualFee: 0, imageName: "cap1_west_elm_key_rewards", accentColor: "#8B6B4A", benefits: []),
        CatalogCard(name: "Key Rewards Visa", issuer: "Capital One", annualFee: 0, imageName: "cap1_key_rewards", accentColor: "#7B5B3A", benefits: []),

        // ─────────────────────────────────────────────────────────────────
        // CITI
        // ─────────────────────────────────────────────────────────────────

        CatalogCard(
            name: "Diamond Preferred",
            issuer: "Citi",
            annualFee: 0,
            imageName: "citi_diamond_preferred",
            accentColor: "#6A7BA2",
            benefits: []
        ),

        CatalogCard(
            name: "Strata",
            issuer: "Citi",
            annualFee: 0,
            imageName: "citi_strata",
            accentColor: "#0A6CB6",
            benefits: []
        ),

        CatalogCard(
            name: "Custom Cash",
            issuer: "Citi",
            annualFee: 0,
            imageName: "citi_custom_cash",
            accentColor: "#0E8A66",
            benefits: []
        ),

        CatalogCard(
            name: "AAdvantage Platinum Select",
            issuer: "Citi",
            annualFee: 99,
            imageName: "citi_aadvantage_platinum_select",
            accentColor: "#0057A8",
            benefits: [
                CatalogBenefit(name: "Preferred Boarding", description: "Preferred boarding on eligible American Airlines flights.", dollarAmount: 0, period: .annually, category: .travel),
            ]
        ),

        CatalogCard(
            name: "AAdvantage MileUp",
            issuer: "Citi",
            annualFee: 0,
            imageName: "citi_aadvantage_mileup",
            accentColor: "#7A4E2D",
            benefits: []
        ),

        CatalogCard(
            name: "Simplicity",
            issuer: "Citi",
            annualFee: 0,
            imageName: "citi_simplicity",
            accentColor: "#7A7A7A",
            benefits: []
        ),

        CatalogCard(
            name: "Costco Anywhere Visa",
            issuer: "Citi",
            annualFee: 0,
            imageName: "citi_costco_anywhere",
            accentColor: "#00558C",
            benefits: []
        ),

        CatalogCard(
            name: "Secured Mastercard",
            issuer: "Citi",
            annualFee: 0,
            imageName: "citi_secured_mastercard",
            accentColor: "#5E6A71",
            benefits: []
        ),

        CatalogCard(
            name: "AT&T Points Plus",
            issuer: "Citi",
            annualFee: 0,
            imageName: "citi_att_points_plus",
            accentColor: "#0057B8",
            benefits: []
        ),

        // ─────────────────────────────────────────────────────────────────
        // CHASE
        // ─────────────────────────────────────────────────────────────────

        CatalogCard(name: "Freedom Rise", issuer: "Chase", annualFee: 0, imageName: "chase_freedom_rise", accentColor: "#4A7BA7", benefits: []),
        CatalogCard(name: "Slate", issuer: "Chase", annualFee: 0, imageName: "chase_slate", accentColor: "#8A8F95", benefits: []),
        CatalogCard(name: "Slate Edge", issuer: "Chase", annualFee: 0, imageName: "chase_slate_edge", accentColor: "#67727E", benefits: []),

        CatalogCard(
            name: "United Explorer",
            issuer: "Chase",
            annualFee: 150,
            imageName: "chase_united_explorer",
            accentColor: "#005DAA",
            benefits: [
                CatalogBenefit(name: "Annual United Club Passes", description: "Receive 2 United Club one-time passes each year.", dollarAmount: 0, period: .annually, category: .miscellaneous),
            ]
        ),

        CatalogCard(
            name: "United Quest",
            issuer: "Chase",
            annualFee: 350,
            imageName: "chase_united_quest",
            accentColor: "#003A70",
            benefits: [
                CatalogBenefit(name: "United Travel Credit", description: "Receive a $200 United travel credit each cardmember year.", dollarAmount: 200, period: .annually, category: .travel),
                CatalogBenefit(name: "Annual Award Flight Discount", description: "Receive an annual 10,000-mile award flight discount.", dollarAmount: 0, period: .annually, category: .travel),
            ]
        ),

        CatalogCard(
            name: "United Gateway",
            issuer: "Chase",
            annualFee: 0,
            imageName: "chase_united_gateway",
            accentColor: "#005DAA",
            benefits: []
        ),

        CatalogCard(
            name: "United Club",
            issuer: "Chase",
            annualFee: 695,
            imageName: "chase_united_club",
            accentColor: "#002B49",
            benefits: []
        ),

        CatalogCard(
            name: "Southwest Rapid Rewards Plus",
            issuer: "Chase",
            annualFee: 99,
            imageName: "chase_southwest_plus",
            accentColor: "#0078BE",
            benefits: []
        ),

        CatalogCard(
            name: "Southwest Rapid Rewards Priority",
            issuer: "Chase",
            annualFee: 229,
            imageName: "chase_southwest_priority",
            accentColor: "#00529B",
            benefits: []
        ),

        CatalogCard(
            name: "Southwest Rapid Rewards Premier",
            issuer: "Chase",
            annualFee: 149,
            imageName: "chase_southwest_premier",
            accentColor: "#004A99",
            benefits: []
        ),

        CatalogCard(
            name: "IHG One Rewards Premier",
            issuer: "Chase",
            annualFee: 99,
            imageName: "chase_ihg_premier",
            accentColor: "#002F6C",
            benefits: [
                CatalogBenefit(name: "Annual Free Night Reward", description: "Receive a Free Night Reward each card anniversary year, subject to program terms.", dollarAmount: 0, period: .annually, category: .miscellaneous),
            ]
        ),

        CatalogCard(
            name: "IHG One Rewards Traveler",
            issuer: "Chase",
            annualFee: 0,
            imageName: "chase_ihg_traveler",
            accentColor: "#0C4DA2",
            benefits: []
        ),

        CatalogCard(
            name: "World of Hyatt",
            issuer: "Chase",
            annualFee: 95,
            imageName: "chase_world_of_hyatt",
            accentColor: "#0D6DB6",
            benefits: [
                CatalogBenefit(name: "Annual Free Night Award", description: "Receive one Free Night Award each card anniversary year.", dollarAmount: 0, period: .annually, category: .miscellaneous),
                CatalogBenefit(name: "Tier-Qualifying Night Credits", description: "Receive 5 tier-qualifying night credits each year.", dollarAmount: 0, period: .annually, category: .miscellaneous),
            ]
        ),

        CatalogCard(name: "Disney Inspire Visa", issuer: "Chase", annualFee: 149, imageName: "chase_disney_inspire", accentColor: "#1E5AA8", benefits: []),
        CatalogCard(name: "Disney Premier Visa", issuer: "Chase", annualFee: 49, imageName: "chase_disney_premier", accentColor: "#4A90E2", benefits: []),
        CatalogCard(name: "Disney Visa", issuer: "Chase", annualFee: 0, imageName: "chase_disney_visa", accentColor: "#7A7A7A", benefits: []),
        CatalogCard(name: "Aeroplan", issuer: "Chase", annualFee: 95, imageName: "chase_aeroplan", accentColor: "#D71920", benefits: []),
        CatalogCard(name: "British Airways Visa Signature", issuer: "Chase", annualFee: 95, imageName: "chase_british_airways", accentColor: "#1B3A6B", benefits: []),
        CatalogCard(name: "Aer Lingus Visa Signature", issuer: "Chase", annualFee: 95, imageName: "chase_aer_lingus", accentColor: "#0B7A75", benefits: []),
        CatalogCard(name: "Iberia Visa Signature", issuer: "Chase", annualFee: 95, imageName: "chase_iberia", accentColor: "#C8102E", benefits: []),
        CatalogCard(name: "DoorDash Rewards Mastercard", issuer: "Chase", annualFee: 0, imageName: "chase_doordash", accentColor: "#FF3008", benefits: [CatalogBenefit(name: "DashPass", description: "Receive a complimentary DashPass membership, valued at $96/year.", dollarAmount: 96, period: .annually, category: .miscellaneous)]),
        CatalogCard(name: "Instacart Mastercard", issuer: "Chase", annualFee: 0, imageName: "chase_instacart", accentColor: "#43B02A", benefits: [CatalogBenefit(name: "Approval Credit", description: "Receive a $50 Instacart credit automatically upon approval.", dollarAmount: 50, period: .annually, category: .miscellaneous)]),
    ]
    /// Returns catalog cards not yet in the user's wallet
    static func available(excluding ownedIDs: Set<String>) -> [CatalogCard] {
        all.filter { !ownedIDs.contains("\($0.issuer):\($0.name)") }
    }

    static func earningHighlights(for card: CatalogCard) -> [String] {
        switch card.id {
        case "american_express_platinum_card":
            return [
                "5x points on flights booked directly with airlines or through Amex Travel.",
                "5x points on prepaid hotels booked through Amex Travel."
            ]
        case "american_express_gold_card":
            return [
                "4x points at restaurants worldwide.",
                "4x points at U.S. supermarkets (up to the card's published limit).",
                "3x points on flights booked directly with airlines or through Amex Travel."
            ]
        case "american_express_blue_cash_preferred":
            return [
                "6% cash back at U.S. supermarkets (up to the card's published limit).",
                "6% cash back on select U.S. streaming subscriptions.",
                "3% cash back at U.S. gas stations and on transit."
            ]
        case "american_express_hilton_honors_aspire_card":
            return [
                "14x points at Hilton hotels and resorts.",
                "7x points on flights booked directly with airlines or through Amex Travel.",
                "7x points on select car rentals booked directly with eligible agencies."
            ]
        case "american_express_hilton_honors_surpass_card":
            return [
                "12x points at Hilton hotels and resorts.",
                "6x points at U.S. restaurants, U.S. supermarkets, and U.S. gas stations."
            ]
        case "american_express_hilton_honors_card":
            return [
                "7x points at Hilton hotels and resorts.",
                "5x points at U.S. restaurants, U.S. supermarkets, and U.S. gas stations."
            ]
        case "chase_sapphire_reserve":
            return [
                "8x points on Chase Travel purchases.",
                "4x points on flights and hotels booked direct.",
                "3x points on dining worldwide.",
                "1x point on other purchases."
            ]
        case "chase_sapphire_preferred":
            return [
                "5x points on travel purchased through Chase Travel.",
                "3x points on dining.",
                "2x points on other travel purchases.",
                "1x point on other purchases."
            ]
        case "chase_freedom_unlimited":
            return [
                "5% cash back on travel purchased through Chase Travel.",
                "3% cash back on dining and drugstore purchases.",
                "1.5% cash back on all other purchases."
            ]
        case "chase_freedom_flex":
            return [
                "5% cash back on up to $1,500 in rotating quarterly categories when activated.",
                "5% cash back on travel purchased through Chase Travel.",
                "3% cash back on dining and drugstore purchases.",
                "1% cash back on all other purchases."
            ]
        case "chase_amazon_prime_visa":
            return [
                "5% cash back at Amazon.com, Whole Foods Market, Amazon Fresh, and Chase Travel with eligible Prime membership.",
                "2% cash back at gas stations, restaurants, and local transit/commuting.",
                "1% cash back on all other purchases."
            ]
        case "capital_one_venture_x":
            return [
                "10x miles on hotels and rental cars booked through Capital One Travel.",
                "5x miles on flights and vacation rentals booked through Capital One Travel.",
                "2x miles on every eligible purchase."
            ]
        case "capital_one_venture":
            return ["2x miles on every purchase."]
        case "capital_one_savorone":
            return [
                "3% cash back on dining, entertainment, grocery stores, and popular streaming services.",
                "5% cash back on hotels and rental cars booked through Capital One Travel."
            ]
        case "citi_strata_premier":
            return [
                "10x points on hotels, car rentals, and attractions booked through Citi Travel.",
                "3x points on air travel, restaurants, supermarkets, gas stations, and EV charging.",
                "1x point on other purchases."
            ]
        case "citi_double_cash":
            return ["2% total cash back on every purchase: 1% when you buy and 1% when you pay."]
        case "citi_custom_cash":
            return [
                "5% cash back on your top eligible spend category each billing cycle, up to the card's published cap.",
                "1% cash back on all other purchases."
            ]
        case "citi_aadvantage_platinum_select_world_elite_mastercard":
            return [
                "2x AAdvantage miles at restaurants and gas stations.",
                "1x mile on other purchases."
            ]
        case "citi_aadvantage_mile_up_credit_card":
            return [
                "2x AAdvantage miles at grocery stores.",
                "1x mile on other purchases."
            ]
        case "discover_it_cash_back":
            return [
                "5% cash back on up to $1,500 in rotating quarterly categories when activated.",
                "1% cash back on all other purchases."
            ]
        case "wf_autograph_journey":
            return [
                "5x points on hotels.",
                "4x points on airlines.",
                "3x points on dining, travel, gas stations, transit, and select streaming services."
            ]
        case "boa_premium_rewards_elite":
            return [
                "2x points on travel and dining purchases.",
                "1.5x points on all other purchases."
            ]
        case "usb_altitude_reserve":
            return [
                "5x points on prepaid hotels and car rentals booked directly in the Altitude Rewards Center.",
                "5x points on eligible travel booked directly through the Altitude Rewards Center.",
                "1x point on all other purchases."
            ]
        case "chase_united_explorer":
            return [
                "2x miles on United purchases, dining, and hotel stays.",
                "1x mile on other purchases."
            ]
        case "chase_united_quest":
            return [
                "3x miles on United purchases.",
                "2x miles on travel, dining, and select streaming services.",
                "1x mile on other purchases."
            ]
        case "chase_united_gateway":
            return [
                "2x miles on United purchases, gas stations, local transit, and commuting.",
                "1x mile on other purchases."
            ]
        case "chase_united_club":
            return [
                "4x miles on United purchases.",
                "2x miles on dining and all other travel.",
                "1x mile on other purchases."
            ]
        case "chase_southwest_rapid_rewards_plus":
            return [
                "2x points on Southwest purchases.",
                "1x point on all other purchases."
            ]
        case "chase_southwest_rapid_rewards_priority":
            return [
                "4x points on Southwest purchases.",
                "2x points at gas stations and restaurants.",
                "1x point on all other purchases."
            ]
        case "chase_southwest_rapid_rewards_premier":
            return [
                "3x points on Southwest purchases.",
                "2x points on transit and select rideshare purchases.",
                "1x point on all other purchases."
            ]
        case "chase_ihg_one_rewards_premier":
            return [
                "10x points at IHG hotels and resorts.",
                "5x points on travel, gas stations, and dining.",
                "3x points on all other purchases."
            ]
        case "chase_ihg_one_rewards_traveler":
            return [
                "5x points at IHG hotels and resorts.",
                "2x points on travel, gas stations, and restaurants.",
                "1x point on other purchases."
            ]
        case "chase_world_of_hyatt":
            return [
                "4x points at Hyatt hotels and resorts.",
                "2x points on local transit, commuting, and fitness clubs.",
                "1x point on other purchases."
            ]
        case "chase_disney_inspire_visa":
            return [
                "10% Disney Rewards Dollars on eligible Disney+, Hulu, and ESPN+ purchases.",
                "3% on qualifying gas station and most Disney U.S. location purchases.",
                "2% on grocery stores and restaurants.",
                "1% on all other purchases."
            ]
        case "chase_disney_premier_visa":
            return [
                "5% Disney Rewards Dollars on eligible Disney+ / Hulu / ESPN+ purchases.",
                "2% on select Disney purchases and airline purchases.",
                "1% on all other purchases."
            ]
        case "chase_disney_visa":
            return [
                "3% Disney Rewards Dollars on eligible Disney+ / Hulu / ESPN+ purchases.",
                "1% on all other purchases."
            ]
        case "chase_aeroplan":
            return [
                "3x points at grocery stores, dining (including takeout and delivery), and Air Canada purchases.",
                "1x point on other purchases."
            ]
        case "chase_british_airways_visa_signature":
            return [
                "3 Avios per $1 on British Airways, Aer Lingus, and Iberia flight purchases.",
                "2 Avios per $1 on hotel accommodations.",
                "1 Avios per $1 on other purchases."
            ]
        case "chase_aer_lingus_visa_signature":
            return [
                "3 Avios per $1 on Aer Lingus, British Airways, and Iberia flight purchases.",
                "2 Avios per $1 on hotel accommodations.",
                "1 Avios per $1 on other purchases."
            ]
        case "chase_iberia_visa_signature":
            return [
                "3 Avios per $1 on Iberia, British Airways, and Aer Lingus flight purchases.",
                "2 Avios per $1 on hotel accommodations.",
                "1 Avios per $1 on other purchases."
            ]
        case "chase_doordash_rewards_mastercard":
            return [
                "4% cash back on DoorDash and Caviar orders.",
                "3% cash back on dining purchased directly from a restaurant.",
                "2% cash back on grocery stores.",
                "1% cash back on other purchases."
            ]
        case "chase_instacart_mastercard":
            return [
                "5% cash back on qualifying Instacart purchases up to the annual limit.",
                "5% cash back on Chase Travel purchases.",
                "2% cash back at restaurants, gas stations, and select streaming services.",
                "1% cash back on other purchases."
            ]
        case "apple_apple_card":
            return [
                "3x cash back on Apple and rotating categories.",
                "2x cash back on purchases made with Apple Pay.",
                "1x cash back on the physical Apple Card."
            ]
        default:
            return []
        }
    }
}
