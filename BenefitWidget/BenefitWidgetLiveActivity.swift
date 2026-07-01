//
//  BenefitWidgetLiveActivity.swift
//  BenefitWidget
//
//  Created by Jacob Michalik on 7/1/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct BenefitWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct BenefitWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BenefitWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension BenefitWidgetAttributes {
    fileprivate static var preview: BenefitWidgetAttributes {
        BenefitWidgetAttributes(name: "World")
    }
}

extension BenefitWidgetAttributes.ContentState {
    fileprivate static var smiley: BenefitWidgetAttributes.ContentState {
        BenefitWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: BenefitWidgetAttributes.ContentState {
         BenefitWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: BenefitWidgetAttributes.preview) {
   BenefitWidgetLiveActivity()
} contentStates: {
    BenefitWidgetAttributes.ContentState.smiley
    BenefitWidgetAttributes.ContentState.starEyes
}
