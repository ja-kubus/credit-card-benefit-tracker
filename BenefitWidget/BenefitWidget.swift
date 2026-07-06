//
//  BenefitWidget.swift
//  BenefitWidget
//

import WidgetKit
import SwiftUI
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

// MARK: - Period Switcher (chevron buttons + label)

struct PeriodSwitcher: View {
    let period: String
    var compact = false

    var body: some View {
        HStack(spacing: compact ? 4 : 6) {
            Button(intent: CyclePeriodIntent(forward: false)) {
                Image(systemName: "chevron.up")
                    .font(.system(size: compact ? 9 : 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: compact ? 16 : 20, height: compact ? 16 : 20)
                    .background(.quaternary, in: Circle())
            }
            .buttonStyle(.plain)

            Text(period)
                .font(compact ? .caption2.weight(.bold) : .caption.weight(.bold))
                .foregroundStyle(.blue)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Button(intent: CyclePeriodIntent(forward: true)) {
                Image(systemName: "chevron.down")
                    .font(.system(size: compact ? 9 : 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: compact ? 16 : 20, height: compact ? 16 : 20)
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
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "creditcard.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                PeriodSwitcher(period: entry.period, compact: true)
            }

            Spacer()

            Text("\(entry.unclaimedCount)")
                .font(.system(size: 40, weight: .bold, design: .rounded))
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

            // Right: period switcher + benefit name list
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Unclaimed")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    PeriodSwitcher(period: entry.period, compact: true)
                }
                .padding(.bottom, 2)

                if entry.benefitNames.isEmpty {
                    Text("All \(entry.period.lowercased()) benefits claimed!")
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
