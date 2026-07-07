//
//  Theme.swift
//  Credit Card Benefit Tracker
//
//  App-wide palette derived from the mascot icon: a giraffe concierge at a
//  coral reception desk on a sage-green background, with a cream countertop,
//  yellow service bell, and leafy plant.
//

import SwiftUI

extension Color {
    /// Coral — the reception desk. Primary brand/action color (matches AccentColor).
    static let appCoral = Color(red: 0.933, green: 0.482, blue: 0.361)      // #EE7B5C

    /// Deeper coral for pressed states and the desk's shadowed base.
    static let appCoralDark = Color(red: 0.851, green: 0.373, blue: 0.271)  // #D95F45

    /// Giraffe orange — secondary highlight (counts, warm accents).
    static let appGiraffe = Color(red: 0.910, green: 0.604, blue: 0.235)    // #E89A3C

    /// Service-bell yellow — attention accents (badges, stars).
    static let appBell = Color(red: 0.949, green: 0.761, blue: 0.188)       // #F2C230

    /// Leaf green — positive states (money, success, break-even).
    static let appLeaf = Color(red: 0.498, green: 0.749, blue: 0.353)       // #7FBF5A

    /// Sage — the icon's background. Soft screen/section background tint.
    static let appSage = Color(red: 0.855, green: 0.906, blue: 0.847)       // #DAE7D8

    /// Cream — the countertop. Card/surface background tint.
    static let appCream = Color(red: 0.949, green: 0.914, blue: 0.804)      // #F2E9CD
}
