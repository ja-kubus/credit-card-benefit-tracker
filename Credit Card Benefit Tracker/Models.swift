//
//  Models.swift
//  Credit Card Benefit Tracker
//
//  Created by Jacob Michalik on 4/20/26.
//

import Foundation
import SwiftUI
import SwiftData

// MARK: - Benefit Category

enum BenefitCategory: String, Codable, CaseIterable {
    case dining         = "Dining"
    case travel         = "Travel"
    case entertainment  = "Entertainment"
    case shopping       = "Shopping"
    case miscellaneous  = "Miscellaneous"
    
    var color: Color {
        switch self {
        case .dining:        return Color(red: 1.0, green: 0.7, blue: 0.5)   // Warm orange
        case .travel:        return Color(red: 0.4, green: 0.8, blue: 1.0)   // Sky blue
        case .entertainment: return Color(red: 0.9, green: 0.5, blue: 0.8)   // Purple-pink
        case .shopping:      return Color(red: 0.6, green: 1.0, blue: 0.6)   // Green
        case .miscellaneous: return Color(red: 0.8, green: 0.8, blue: 0.8)   // Gray
        }
    }
}

// MARK: - Benefit Period

enum BenefitPeriod: String, Codable, CaseIterable {
    case monthly       = "Monthly"
    case quarterly     = "Quarterly"
    case semiAnnually  = "Semi-Annually"
    case annually      = "Annually"

    /// Returns the next reset date after `from` for this period.
    func nextResetDate(from date: Date = Date()) -> Date {
        var cal = Calendar.current
        cal.timeZone = TimeZone.current
        switch self {
        case .monthly:
            return cal.date(byAdding: .month, value: 1, to: cal.startOfMonth(for: date))!
        case .quarterly:
            return cal.startOfNextQuarter(for: date)
        case .semiAnnually:
            return cal.startOfNextHalf(for: date)
        case .annually:
            let year = cal.component(.year, from: date)
            return cal.date(from: DateComponents(year: year + 1, month: 1, day: 1))!
        }
    }
}

private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let comps = dateComponents([.year, .month], from: date)
        return self.date(from: comps)!
    }

    func startOfNextQuarter(for date: Date) -> Date {
        let month = component(.month, from: date)
        let year  = component(.year, from: date)
        let nextQMonth: Int
        let nextQYear: Int
        switch month {
        case 1...3:  nextQMonth = 4;  nextQYear = year
        case 4...6:  nextQMonth = 7;  nextQYear = year
        case 7...9:  nextQMonth = 10; nextQYear = year
        default:     nextQMonth = 1;  nextQYear = year + 1
        }
        return self.date(from: DateComponents(year: nextQYear, month: nextQMonth, day: 1))!
    }

    func startOfNextHalf(for date: Date) -> Date {
        let month = component(.month, from: date)
        let year  = component(.year, from: date)
        if month <= 6 {
            return self.date(from: DateComponents(year: year, month: 7, day: 1))!
        } else {
            return self.date(from: DateComponents(year: year + 1, month: 1, day: 1))!
        }
    }
}

// MARK: - Catalog Types (not persisted)

struct CatalogBenefit: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let description: String
    let dollarAmount: Double
    let period: BenefitPeriod
    let category: BenefitCategory

    init(id: UUID = UUID(), name: String, description: String, dollarAmount: Double, period: BenefitPeriod, category: BenefitCategory = .miscellaneous) {
        self.id          = id
        self.name        = name
        self.description = description
        self.dollarAmount = dollarAmount
        self.period      = period
        self.category    = category
    }
}

struct CatalogCard: Identifiable, Hashable {
    let id: String          // stable unique ID used as catalogCardID
    let name: String
    let issuer: String
    let annualFee: Double
    let imageName: String
    let accentColor: String // hex string e.g. "#A8A9AD"
    let benefits: [CatalogBenefit]

    init(name: String, issuer: String, annualFee: Double, imageName: String, accentColor: String, benefits: [CatalogBenefit]) {
        self.id          = "\(issuer)_\(name)".lowercased().replacingOccurrences(of: " ", with: "_")
        self.name        = name
        self.issuer      = issuer
        self.annualFee   = annualFee
        self.imageName   = imageName
        self.accentColor = accentColor
        self.benefits    = benefits
    }
}

// MARK: - SwiftData Models

@Model
final class UserCard {
    var catalogCardID: String
    var name: String
    var issuer: String
    var annualFee: Double
    var imageName: String
    var accentColor: String
    var dateAdded: Date
    var notificationsEnabled: Bool = true

    @Relationship(deleteRule: .cascade) var completions: [BenefitCompletion] = []

    init(from catalog: CatalogCard) {
        self.catalogCardID = catalog.id
        self.name          = catalog.name
        self.issuer        = catalog.issuer
        self.annualFee     = catalog.annualFee
        self.imageName     = catalog.imageName
        self.accentColor   = catalog.accentColor
        self.dateAdded     = Date()
    }
}

@Model
final class BenefitCompletion {
    var cardID: String
    var benefitID: String
    var benefitName: String
    var benefitDescription: String
    var dollarAmount: Double
    var period: String          // BenefitPeriod.rawValue
    var isCompleted: Bool
    var resetDate: Date
    var missedCount: Int = 0    // Tracks how many times benefit wasn't used before reset
    var partialUsage: String = ""  // e.g., "250" for $250 used out of available
    var isIgnored: Bool = false    // When true, benefit is not counted in missed notifications
    var benefitStartDate: Date?     // Anniversary date for annual benefits (e.g., card opening date)

    init(cardID: String, benefit: CatalogBenefit) {
        self.cardID             = cardID
        self.benefitID          = benefit.id.uuidString
        self.benefitName        = benefit.name
        self.benefitDescription = benefit.description
        self.dollarAmount       = benefit.dollarAmount
        self.period             = benefit.period.rawValue
        self.isCompleted        = false
        self.resetDate          = benefit.period.nextResetDate()
        self.partialUsage       = ""
        self.isIgnored          = false
        self.benefitStartDate   = nil
    }

    var benefitPeriod: BenefitPeriod {
        BenefitPeriod(rawValue: period) ?? .annually
    }
    
    /// Returns true if the benefit has any usage (completed or partial usage entered)
    var hasAnyUsage: Bool {
        isCompleted || !partialUsage.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    /// For annual benefits, calculates the next reset date based on the anniversary date
    func getNextAnniversaryDate(from date: Date = Date()) -> Date {
        guard benefitPeriod == .annually, let startDate = benefitStartDate else {
            return benefitPeriod.nextResetDate(from: date)
        }
        
        let calendar = Calendar.current
        let startMonth = calendar.component(.month, from: startDate)
        let startDay = calendar.component(.day, from: startDate)
        let currentYear = calendar.component(.year, from: date)
        
        // Try to create anniversary date this year
        var components = DateComponents(year: currentYear, month: startMonth, day: startDay)
        if let anniversaryThisYear = calendar.date(from: components), anniversaryThisYear > date {
            return anniversaryThisYear
        }
        
        // Otherwise, use next year
        components.year = currentYear + 1
        return calendar.date(from: components) ?? benefitPeriod.nextResetDate(from: date)
    }

    /// Resets the checkbox if the current date has passed the resetDate.
    /// Increments missedCount if the benefit was not completed before reset (and not ignored).
    func resetIfNeeded() {
        guard Date() >= resetDate else { return }
        // If benefit wasn't used and not ignored, increment missed count
        if !hasAnyUsage && !isIgnored {
            missedCount += 1
        }
        isCompleted = false
        partialUsage = ""
        
        // Use anniversary date for annual benefits if set, otherwise use period-based reset
        if benefitPeriod == .annually, let _ = benefitStartDate {
            resetDate = getNextAnniversaryDate(from: resetDate)
        } else {
            resetDate = benefitPeriod.nextResetDate(from: resetDate)
        }
    }
}

@Model
final class NotificationSettings {
    var notificationsEnabled: Bool = true
    var rememberNotificationPreference: Bool = false
    
    init() {}
}

// MARK: - Color Helper

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
    }
}
