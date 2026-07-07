//
//  BenefitWidget.swift
//  BenefitWidget
//

import WidgetKit
import SwiftUI

// Brand palette (widget target cannot see the app's Theme.swift)
private let brandCoral = Color(red: 0.933, green: 0.482, blue: 0.361)   // #EE7B5C
private let brandGiraffe = Color(red: 0.910, green: 0.604, blue: 0.235) // #E89A3C
private let brandLeaf = Color(red: 0.498, green: 0.749, blue: 0.353)    // #7FBF5A
import AppIntents

private let suiteName = "group.benefittracker.shared"
private let periodKeys = ["Monthly", "Quarterly", "Semi-Annually", "Annually"]
private let selectedPeriodKey = "widgetSelectedPeriod"

// MARK: - Cycle Period Intent (interactive widget button)

struct CyclePeriodIntent: AppIntent {
    static var title: LocalizedStringResource = "Change Benefit Period"
    static var description = IntentDescription("Cycles the widget between monthly, quarterly, semi-annual, and annual benefits.")

    @Parameter(title: "Forward")
    var forward: Bool

    init() { self.forward = true }
    init(forward: Bool) { self.forward = forward }

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: suiteName)
        let current = defaults?.string(forKey: selectedPeriodKey) ?? periodKeys[0]
        let index = periodKeys.firstIndex(of: current) ?? 0
        let next = forward
            ? (index + 1) % periodKeys.count
            : (index - 1 + periodKeys.count) % periodKeys.count
        defaults?.set(periodKeys[next], forKey: selectedPeriodKey)
        // WidgetKit reloads the widget automatically after an interactive intent completes.
        return .result()
    }
}

// MARK: - Entry

struct BenefitWidgetEntry: TimelineEntry {
    let date: Date
    let period: String
    let unclaimedCount: Int
    let remainingValue: Double
    let benefitNames: [String]
}

// MARK: - Provider

struct BenefitWidgetProvider: TimelineProvider {

    func placeholder(in context: Context) -> BenefitWidgetEntry {
        BenefitWidgetEntry(
            date: Date(),
            period: "Monthly",
            unclaimedCount: 5,
            remainingValue: 85.00,
            benefitNames: ["Uber Cash", "Dining Credit", "Streaming Credit", "Hotel Credit"]
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (BenefitWidgetEntry) -> Void) {
        completion(entry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BenefitWidgetEntry>) -> Void) {
        let nextRefresh = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        let timeline = Timeline(entries: [entry()], policy: .after(nextRefresh))
        completion(timeline)
    }

    private func entry() -> BenefitWidgetEntry {
        let defaults = UserDefaults(suiteName: suiteName)
        let period = defaults?.string(forKey: selectedPeriodKey) ?? periodKeys[0]
        let count = defaults?.integer(forKey: "unclaimedCount_\(period)") ?? 0
        let value = defaults?.double(forKey: "remainingValue_\(period)") ?? 0.0
        let names = defaults?.stringArray(forKey: "benefitNames_\(period)") ?? []
        return BenefitWidgetEntry(date: Date(), period: period, unclaimedCount: count, remainingValue: value, benefitNames: names)
    }
}

// MARK: - Period Arrow Column (up arrow top, down arrow bottom)

struct PeriodArrowColumn: View {
    var body: some View {
        VStack {
            Button(intent: CyclePeriodIntent(forward: false)) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .background(.quaternary, in: Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            Button(intent: CyclePeriodIntent(forward: true)) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .background(.quaternary, in: Circle())
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Small View

struct BenefitWidgetSmallView: View {
    var entry: BenefitWidgetEntry

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                // Full period name, prominent
                Text(entry.period)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(brandCoral)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Spacer()

                Text("\(entry.unclaimedCount)")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)

                Text("unclaimed")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Spacer()

                Text(entry.remainingValue, format: .currency(code: "USD").precision(.fractionLength(0)))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(brandLeaf)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text("left to claim")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            PeriodArrowColumn()
        }
        .padding(12)
    }
}

// MARK: - Medium View

struct BenefitWidgetMediumView: View {
    var entry: BenefitWidgetEntry

    var body: some View {
        HStack(spacing: 0) {
            // Left: period + count + value
            VStack(alignment: .leading, spacing: 2) {
                // Full period name, prominent
                Text(entry.period)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(brandCoral)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Spacer()

                Text("\(entry.unclaimedCount)")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                Text(entry.unclaimedCount == 1 ? "benefit unclaimed" : "benefits unclaimed")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Spacer()

                Text(entry.remainingValue, format: .currency(code: "USD").precision(.fractionLength(0)))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(brandLeaf)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text("left to claim")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxHeight: .infinity, alignment: .leading)
            .padding(.vertical, 14)
            .padding(.leading, 14)
            .padding(.trailing, 10)

            Divider()
                .padding(.vertical, 12)

            // Middle: benefit name list
            VStack(alignment: .leading, spacing: 6) {
                Text("Unclaimed Benefits")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.bottom, 2)

                if entry.benefitNames.isEmpty {
                    Text("All claimed!")
                        .font(.caption)
                        .foregroundStyle(brandLeaf)
                } else {
                    ForEach(entry.benefitNames.prefix(4), id: \.self) { name in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(brandGiraffe)
                                .frame(width: 6, height: 6)
                            Text(name)
                                .font(.caption)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.vertical, 14)
            .padding(.leading, 10)
            .padding(.trailing, 6)

            // Right: arrow column (up top, down bottom)
            PeriodArrowColumn()
                .padding(.vertical, 14)
                .padding(.trailing, 12)
        }
    }
}

// MARK: - Entry View (dispatches by family)

struct BenefitWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: BenefitWidgetEntry

    var body: some View {
        switch family {
        case .systemMedium:
            BenefitWidgetMediumView(entry: entry)
        default:
            BenefitWidgetSmallView(entry: entry)
        }
    }
}

// MARK: - Widget

struct BenefitWidget: Widget {
    let kind: String = "BenefitWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BenefitWidgetProvider()) { entry in
            BenefitWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Benefit Tracker")
        .description("See how many card benefits you still have to use. Tap the arrows to switch between monthly, quarterly, semi-annual, and annual benefits.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    BenefitWidget()
} timeline: {
    BenefitWidgetEntry(date: .now, period: "Monthly", unclaimedCount: 5, remainingValue: 85.00, benefitNames: ["Uber Cash", "Dining Credit", "Streaming Credit", "Hotel Credit"])
}

#Preview(as: .systemMedium) {
    BenefitWidget()
} timeline: {
    BenefitWidgetEntry(date: .now, period: "Monthly", unclaimedCount: 5, remainingValue: 85.00, benefitNames: ["Uber Cash", "Dining Credit", "Streaming Credit", "Hotel Credit"])
}
