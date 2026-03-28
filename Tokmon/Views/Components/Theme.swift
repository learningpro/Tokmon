import SwiftUI

// Design system colors matching the mockup
struct Theme {
    // Backgrounds
    static let sidebarBg = Color(red: 0.10, green: 0.10, blue: 0.18)       // #1a1a2e
    static let mainBg = Color(red: 0.12, green: 0.12, blue: 0.18)          // #1e1e2e
    static let cardBg = Color(red: 0.15, green: 0.15, blue: 0.22)          // #262638
    static let cardBorder = Color.white.opacity(0.06)

    // Accents
    static let accentBlue = Color(red: 0.30, green: 0.50, blue: 1.0)       // #4d80ff
    static let accentPurple = Color(red: 0.60, green: 0.40, blue: 1.0)     // #9966ff
    static let accentTeal = Color(red: 0.20, green: 0.85, blue: 0.80)      // #33d9cc
    static let accentGreen = Color(red: 0.30, green: 0.85, blue: 0.50)     // #4dd980
    static let accentOrange = Color(red: 1.0, green: 0.60, blue: 0.30)     // #ff994d
    static let accentPink = Color(red: 1.0, green: 0.40, blue: 0.60)       // #ff6699

    // Chart colors
    static let chartGradient = [accentBlue, accentPurple]
    static let projectColors: [Color] = [accentBlue, accentPurple, accentTeal, accentOrange, accentPink]
    static let modelColors: [Color] = [accentPurple, accentBlue, accentTeal, accentOrange, accentPink, accentGreen]

    // Text
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.6)
    static let textTertiary = Color.white.opacity(0.35)
}
