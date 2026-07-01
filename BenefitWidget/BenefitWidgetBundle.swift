//
//  BenefitWidgetBundle.swift
//  BenefitWidget
//
//  Created by Jacob Michalik on 7/1/26.
//

import WidgetKit
import SwiftUI

@main
struct BenefitWidgetBundle: WidgetBundle {
    var body: some Widget {
        BenefitWidget()
        BenefitWidgetControl()
        BenefitWidgetLiveActivity()
    }
}
