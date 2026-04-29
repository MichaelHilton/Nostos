import SwiftUI

// MARK: - Colors
extension Color {
    static let nostosAccent = Color(red: 0x1B/255, green: 0x7A/255, blue: 0x8A/255)
    static let nostosAccentLight = Color(red: 0xE8/255, green: 0xF4/255, blue: 0xF6/255)
    static let nostosGold = Color(red: 0xB8/255, green: 0x89/255, blue: 0x2A/255)
    static let nostosGreen = Color(red: 0x1D/255, green: 0x8A/255, blue: 0x56/255)
    static let nostosOrange = Color(red: 0xC0/255, green: 0x78/255, blue: 0x28/255)
    static let nostosRed = Color(red: 0xC0/255, green: 0x3C/255, blue: 0x3C/255)

    static let nostosBg = Color(red: 0xF8/255, green: 0xF6/255, blue: 0xF1/255)
    static let nostosSidebar = Color(red: 0xEA/255, green: 0xE5/255, blue: 0xDC/255)
    static let nostosSidebarBorder = Color(red: 0xD8/255, green: 0xD2/255, blue: 0xC8/255)

    static let nostosSurface = Color(red: 1.0, green: 1.0, blue: 1.0)
    static let nostosSurface2 = Color(red: 0xF4/255, green: 0xF1/255, blue: 0xEA/255)
    static let nostosBorder = Color(red: 0xDD/255, green: 0xD8/255, blue: 0xCE/255)

    static let nostosFg1 = Color(red: 0x1A/255, green: 0x2E/255, blue: 0x3C/255)
    static let nostosFg2 = Color(red: 0x5A/255, green: 0x6E/255, blue: 0x7A/255)
    static let nostosFg3 = Color(red: 0x9A/255, green: 0xAE/255, blue: 0xBB/255)

    static let nostosProgressBg = Color(red: 0xD8/255, green: 0xEE/255, blue: 0xF2/255)
}

// MARK: - Typography
extension Font {
    static func nostosDisplay(size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .custom("Cormorant Garamond", size: size).weight(weight)
    }

    static let nostosTitle = Font.system(size: 34, weight: .bold, design: .default)
    static let nostosSubtitle = Font.system(size: 12, weight: .regular, design: .default)
    static let nostosLabel = Font.system(size: 10, weight: .semibold, design: .default)
    static let nostosBody = Font.system(size: 13, weight: .regular, design: .default)
    static let nostosCaption = Font.system(size: 11, weight: .regular, design: .default)
}

// MARK: - Spacing
struct NostosSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 14
    static let xl: CGFloat = 16
    static let xxl: CGFloat = 20
    static let xxxl: CGFloat = 24
    static let pagePadding: CGFloat = 26
}

// MARK: - Radii
struct NostosRadii {
    static let sm: CGFloat = 4
    static let md: CGFloat = 6
    static let lg: CGFloat = 8
    static let xl: CGFloat = 9
    static let xxl: CGFloat = 14
}
