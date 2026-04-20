import SwiftUI

// Aegean palette — Nostos Redesign v2
enum NostosTheme {
    static let bg           = Color(hex: "F8F6F1")
    static let bgAlt        = Color(hex: "F2EEE6")
    static let sidebar      = Color(hex: "EAE5DC")
    static let sidebarBorder = Color(hex: "D8D2C8")
    static let surface      = Color.white
    static let surface2     = Color(hex: "F4F1EA")
    static let border       = Color(hex: "DDD8CE")
    static let borderFaint  = Color.black.opacity(0.06)

    static let accent       = Color(hex: "1B7A8A")
    static let accentLight  = Color(hex: "E8F4F6")
    static let accentHov    = Color(hex: "22909F")
    static let gold         = Color(hex: "B8892A")

    static let fg1          = Color(hex: "1A2E3C")
    static let fg2          = Color(hex: "5A6E7A")
    static let fg3          = Color(hex: "9AAEBB")

    static let green        = Color(hex: "1D8A56")
    static let orange       = Color(hex: "C07828")
    static let red          = Color(hex: "C03C3C")
    static let progressBg   = Color(hex: "D8EEF2")

    // Georgia is used as the built-in macOS serif analog for Cormorant Garamond
    static func displayFont(size: CGFloat, weight: Font.Weight = .bold) -> Font {
        Font.custom("Georgia", size: size).weight(weight)
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Foundation.Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 128, 128, 128)
        }
        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}
