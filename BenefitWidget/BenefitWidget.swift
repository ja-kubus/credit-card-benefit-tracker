//
//  BenefitWidget.swift
//  BenefitWidget
//

import WidgetKit
import SwiftUI

// MARK: - Entry

struct BenefitWidgetEntry: TimelineEntry {
    let date: Date
    let unclaimedCount: Int
    let remainingValue: Double
    let benefitNames: [String]
}

// MARK: - Provider

struct BenefitWidgetProvider: TimelineProvider {
    private let suiteName = "group.benefittracker.shared"

    func placeholder(in context: Context) -> BenefitWidgetEntry {
        BenefitWidgetEntry(
            date: Date(),
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
        let count = defaults?.integer(forKey: "unclaimedCount") ?? 0
        let value = defaults?.double(forKey: "remainingValue") ?? 0.0
        let names = defaults?.stringArray(forKey: "benefitNames") ?? []
        return BenefitWidgetEntry(date: Date(), unclaimedCount: count, remainingValue: value, benefitNames: names)
    }
}

// MARK: - Small View

struct BenefitWidgetSmallView: View {
    var entry: BenefitWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "creditcard.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Benefit Tracker")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(entry.unclaimedCount)")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            Text(entry.unclaimedCount == 1 ? "benefit unclaimed" : "benefits unclaimed")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            Spacer()

            Text(entry.remainingValue, format: .currency(code: "USD").precision(.fractionLength(0)))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.green)

            Text("remaining to claim")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
    }
}

// MARK: - Medium View

struct BenefitWidgetMediumView: View {
    var entry: BenefitWidgetEntry

    var body: some View {
        HStack(spacing: 0) {
            // Left: count + value
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "creditcard.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("Benefit Tracker")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("\(entry.unclaimedCount)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                Text(entry.unclaimedCount == 1 ? "benefit unclaimed" : "benefits unclaimed")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                Spacer()

                Text(entry.remainingValue, format: .currency(code: "USD").precision(.fractionLength(0)))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.green)

                Text("remaining to claim")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxHeight: .infinity, alignment: .leading)
            .padding(14)

            Divider()
                .padding(.vertical, 12)

            // Right: benefit name list
            VStack(alignment: .leading, spacing: 6) {
                Text("Unclaimed Benefits")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 2)

                if entry.benefitNames.isEmpty {
                    Text("All benefits claimed!")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else {
                    ForEach(entry.benefitNames.prefix(4), id: \.self) { name in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.orange)
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
            .padding(14)
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
        .description("See how many card benefits you still have to use.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    BenefitWidget()
} timeline: {
    BenefitWidgetEntry(date: .now, unclaimedCount: 5, remainingValue: 85.00, benefitNames: ["Uber Cash", "Dining Credit", "Streaming Credit", "Hotel Credit"])
}

#Preview(as: .systemMedium) {
    BenefitWidget()
} timeline: {
    BenefitWidgetEntry(date: .now, unclaimedCount: 5, remainingValue: 85.00, benefitNames: ["Uber Cash", "Dining Credit", "Streaming Credit", "Hotel Credit"])
}
