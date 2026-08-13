//
//  TransferPartners.swift
//  Credit Card Benefit Tracker
//
//  Transferable-points programs (Chase UR, Amex MR, Citi ThankYou, Capital One,
//  Bilt) and their airline/hotel transfer partners + ratios. A card is mapped to
//  its program by issuer + name; co-branded cards (which earn a partner's own
//  currency, not transferable points) map to no program.
//
//  NOTE: transfer partners and ratios change over time. This is a best-effort
//  reference to verify against the issuer's site before making a transfer.
//

import Foundation

struct TransferPartner: Identifiable {
    enum Kind { case airline, hotel }
    let name: String
    /// Transfer ratio as points_you_give : miles_you_get, e.g. "1:1", "5:4".
    let ratio: String
    let kind: Kind
    var id: String { name }
}

enum TransferProgram: Identifiable {
    case chaseUR
    case amexMR
    case citiTYP
    case capitalOne
    case bilt

    var id: String { displayName }

    var displayName: String {
        switch self {
        case .chaseUR: return "Chase Ultimate Rewards"
        case .amexMR: return "Amex Membership Rewards"
        case .citiTYP: return "Citi ThankYou"
        case .capitalOne: return "Capital One Miles"
        case .bilt: return "Bilt Rewards"
        }
    }

    var partners: [TransferPartner] {
        switch self {
        case .chaseUR:
            return [
                .init(name: "Aer Lingus AerClub", ratio: "1:1", kind: .airline),
                .init(name: "Air Canada Aeroplan", ratio: "1:1", kind: .airline),
                .init(name: "Air France-KLM Flying Blue", ratio: "1:1", kind: .airline),
                .init(name: "British Airways Avios", ratio: "1:1", kind: .airline),
                .init(name: "Emirates Skywards", ratio: "1:1", kind: .airline),
                .init(name: "Iberia Avios", ratio: "1:1", kind: .airline),
                .init(name: "JetBlue TrueBlue", ratio: "1:1", kind: .airline),
                .init(name: "Singapore KrisFlyer", ratio: "1:1", kind: .airline),
                .init(name: "Southwest Rapid Rewards", ratio: "1:1", kind: .airline),
                .init(name: "United MileagePlus", ratio: "1:1", kind: .airline),
                .init(name: "Virgin Atlantic Flying Club", ratio: "1:1", kind: .airline),
                .init(name: "World of Hyatt", ratio: "1:1", kind: .hotel),
                .init(name: "IHG One Rewards", ratio: "1:1", kind: .hotel),
                .init(name: "Marriott Bonvoy", ratio: "1:1", kind: .hotel),
            ]
        case .amexMR:
            return [
                .init(name: "Aer Lingus AerClub", ratio: "1:1", kind: .airline),
                .init(name: "Aeromexico Rewards", ratio: "1:1.6", kind: .airline),
                .init(name: "Air Canada Aeroplan", ratio: "1:1", kind: .airline),
                .init(name: "Air France-KLM Flying Blue", ratio: "1:1", kind: .airline),
                .init(name: "ANA Mileage Club", ratio: "1:1", kind: .airline),
                .init(name: "Avianca LifeMiles", ratio: "1:1", kind: .airline),
                .init(name: "British Airways Avios", ratio: "1:1", kind: .airline),
                .init(name: "Cathay Pacific", ratio: "1:1", kind: .airline),
                .init(name: "Delta SkyMiles", ratio: "1:1", kind: .airline),
                .init(name: "Emirates Skywards", ratio: "1:1", kind: .airline),
                .init(name: "Etihad Guest", ratio: "1:1", kind: .airline),
                .init(name: "Hawaiian Airlines", ratio: "1:1", kind: .airline),
                .init(name: "Iberia Avios", ratio: "1:1", kind: .airline),
                .init(name: "JetBlue TrueBlue", ratio: "5:4", kind: .airline),
                .init(name: "Qantas Frequent Flyer", ratio: "1:1", kind: .airline),
                .init(name: "Qatar Privilege Club", ratio: "1:1", kind: .airline),
                .init(name: "Singapore KrisFlyer", ratio: "1:1", kind: .airline),
                .init(name: "Virgin Atlantic Flying Club", ratio: "1:1", kind: .airline),
                .init(name: "Choice Privileges", ratio: "1:1", kind: .hotel),
                .init(name: "Hilton Honors", ratio: "1:2", kind: .hotel),
                .init(name: "Marriott Bonvoy", ratio: "1:1", kind: .hotel),
            ]
        case .citiTYP:
            return [
                .init(name: "Aeromexico Rewards", ratio: "1:1", kind: .airline),
                .init(name: "Air France-KLM Flying Blue", ratio: "1:1", kind: .airline),
                .init(name: "Avianca LifeMiles", ratio: "1:1", kind: .airline),
                .init(name: "Cathay Pacific", ratio: "1:1", kind: .airline),
                .init(name: "Emirates Skywards", ratio: "1:1", kind: .airline),
                .init(name: "Etihad Guest", ratio: "1:1", kind: .airline),
                .init(name: "EVA Air Infinity MileageLands", ratio: "1:1", kind: .airline),
                .init(name: "JetBlue TrueBlue", ratio: "1:1", kind: .airline),
                .init(name: "Qantas Frequent Flyer", ratio: "1:1", kind: .airline),
                .init(name: "Qatar Privilege Club", ratio: "1:1", kind: .airline),
                .init(name: "Singapore KrisFlyer", ratio: "1:1", kind: .airline),
                .init(name: "Turkish Airlines Miles&Smiles", ratio: "1:1", kind: .airline),
                .init(name: "Virgin Atlantic Flying Club", ratio: "1:1", kind: .airline),
                .init(name: "Choice Privileges", ratio: "1:2", kind: .hotel),
                .init(name: "Wyndham Rewards", ratio: "1:1", kind: .hotel),
                .init(name: "Accor Live Limitless", ratio: "2:1", kind: .hotel),
            ]
        case .capitalOne:
            return [
                .init(name: "Aeromexico Rewards", ratio: "1:1", kind: .airline),
                .init(name: "Air Canada Aeroplan", ratio: "1:1", kind: .airline),
                .init(name: "Air France-KLM Flying Blue", ratio: "1:1", kind: .airline),
                .init(name: "Avianca LifeMiles", ratio: "1:1", kind: .airline),
                .init(name: "British Airways Avios", ratio: "1:1", kind: .airline),
                .init(name: "Cathay Pacific", ratio: "1:1", kind: .airline),
                .init(name: "Emirates Skywards", ratio: "2:1", kind: .airline),
                .init(name: "Etihad Guest", ratio: "1:1", kind: .airline),
                .init(name: "EVA Air Infinity MileageLands", ratio: "2:1.5", kind: .airline),
                .init(name: "Finnair Plus", ratio: "1:1", kind: .airline),
                .init(name: "Qantas Frequent Flyer", ratio: "1:1", kind: .airline),
                .init(name: "Singapore KrisFlyer", ratio: "1:1", kind: .airline),
                .init(name: "TAP Air Portugal Miles&Go", ratio: "1:1", kind: .airline),
                .init(name: "Turkish Airlines Miles&Smiles", ratio: "1:1", kind: .airline),
                .init(name: "Virgin Red", ratio: "1:1", kind: .airline),
                .init(name: "Accor Live Limitless", ratio: "2:1", kind: .hotel),
                .init(name: "Choice Privileges", ratio: "1:1", kind: .hotel),
                .init(name: "Wyndham Rewards", ratio: "1:1", kind: .hotel),
            ]
        case .bilt:
            return [
                .init(name: "Air Canada Aeroplan", ratio: "1:1", kind: .airline),
                .init(name: "Air France-KLM Flying Blue", ratio: "1:1", kind: .airline),
                .init(name: "Alaska Mileage Plan", ratio: "1:1", kind: .airline),
                .init(name: "Avianca LifeMiles", ratio: "1:1", kind: .airline),
                .init(name: "Cathay Pacific", ratio: "1:1", kind: .airline),
                .init(name: "Emirates Skywards", ratio: "1:1", kind: .airline),
                .init(name: "Hawaiian Airlines", ratio: "1:1", kind: .airline),
                .init(name: "Turkish Airlines Miles&Smiles", ratio: "1:1", kind: .airline),
                .init(name: "United MileagePlus", ratio: "1:1", kind: .airline),
                .init(name: "Virgin Atlantic Flying Club", ratio: "1:1", kind: .airline),
                .init(name: "World of Hyatt", ratio: "1:1", kind: .hotel),
                .init(name: "IHG One Rewards", ratio: "1:1", kind: .hotel),
                .init(name: "Marriott Bonvoy", ratio: "1:1", kind: .hotel),
            ]
        }
    }
}

enum TransferPartnerCatalog {
    /// The transferable-points program a card earns into, or nil for cash-back /
    /// co-branded cards (which earn a partner's own currency and can't transfer).
    static func program(for card: UserCard) -> TransferProgram? {
        let issuer = card.issuer.lowercased()
        let name = card.name.lowercased()

        if issuer.contains("chase") {
            if name.contains("sapphire") || name.contains("ink") || name.contains("freedom") {
                return .chaseUR
            }
        } else if issuer.contains("american express") || issuer.contains("amex") {
            // Co-brands (Delta, Hilton, Marriott) earn the partner's currency, not MR.
            if name.contains("delta") || name.contains("hilton")
                || name.contains("marriott") || name.contains("bonvoy") {
                return nil
            }
            if name.contains("platinum") || name.contains("gold") || name.contains("green")
                || name.contains("everyday") || name.contains("business")
                || name.contains("rewards") {
                return .amexMR
            }
        } else if issuer.contains("citi") {
            if name.contains("premier") || name.contains("prestige") || name.contains("strata")
                || name.contains("thankyou") || name.contains("rewards+")
                || name.contains("double cash") || name.contains("custom cash") {
                return .citiTYP
            }
        } else if issuer.contains("capital one") {
            // Miles-earning families transfer; cash-back cards (Quicksilver/Savor) don't.
            if name.contains("venture") || name.contains("spark miles") {
                return .capitalOne
            }
        } else if issuer.contains("bilt") {
            return .bilt
        }
        return nil
    }
}
