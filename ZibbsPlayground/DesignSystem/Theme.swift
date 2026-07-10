import SwiftUI

/// Space-explorer palette and typography. Deep blues and purples with glowing
/// accents; everything uses the rounded system font for a friendly feel.
enum Theme {
    // Backdrop
    static let deepSpace   = Color(red: 0.043, green: 0.045, blue: 0.14)
    static let midSpace    = Color(red: 0.10, green: 0.09, blue: 0.24)
    static let nebulaPurple = Color(red: 0.42, green: 0.27, blue: 0.75)
    static let cosmicBlue  = Color(red: 0.22, green: 0.45, blue: 0.95)

    // Glowing accents
    static let starYellow  = Color(red: 1.0, green: 0.83, blue: 0.26)
    static let alienGreen  = Color(red: 0.38, green: 0.87, blue: 0.55)
    static let rocketOrange = Color(red: 1.0, green: 0.55, blue: 0.25)
    static let cometPink   = Color(red: 0.96, green: 0.45, blue: 0.71)
    static let iceBlue     = Color(red: 0.55, green: 0.85, blue: 1.0)

    // Feedback
    static let successGreen = Color(red: 0.30, green: 0.82, blue: 0.48)
    static let softRed      = Color(red: 0.95, green: 0.50, blue: 0.45)

    static func rounded(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}
