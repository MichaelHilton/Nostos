import SwiftUI

// Minimal design-system stubs to satisfy Xcode build when files aren't included in the project
struct NostosSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 14
    static let xl: CGFloat = 16
    static let xxxl: CGFloat = 24
    static let pagePadding: CGFloat = 26
}

struct NostosRadii {
    static let sm: CGFloat = 4
    static let md: CGFloat = 6
    static let lg: CGFloat = 8
    static let xl: CGFloat = 9
}

extension Color {
    static let nostosGreen = Color.green
    static let nostosBorder = Color.gray
    static let nostosOrange = Color.orange
    static let nostosRed = Color.red
    static let nostosSurface = Color.white
    static let nostosSurface2 = Color(white: 0.95)
    static let nostosFg1 = Color.primary
    static let nostosFg3 = Color.secondary
    static let nostosProgressBg = Color.blue.opacity(0.2)
}

struct DiamondAccent: View {
    let size: CGFloat

    init(size: CGFloat = 6) { self.size = size }

    var body: some View { RoundedRectangle(cornerRadius: size / 4).fill(Color.nostosGreen).frame(width: size, height: size).rotationEffect(.degrees(45)) }
}

struct StarDotBackground: View {
    var body: some View { Color.clear }
}

struct ScannerIcon: View { let active: Bool; var body: some View { Image(systemName: "scanner") } }
struct GalleryIcon: View { let active: Bool; var body: some View { Image(systemName: "photo.on.rectangle") } }
struct DuplicatesIcon: View { let active: Bool; var body: some View { Image(systemName: "doc.on.doc") } }
struct VaultIcon: View { let active: Bool; var body: some View { Image(systemName: "lock.shield") } }

struct PageHeaderView: View {
    let title: String
    let subtitle: String?
    let actions: [AnyView]?

    init(title: String, subtitle: String? = nil, @ViewBuilder actions: () -> [AnyView] = { [] }) {
        self.title = title
        self.subtitle = subtitle
        self.actions = actions()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.title).foregroundColor(.nostosFg1)
                    if let subtitle {
                        Text(subtitle).font(.subheadline).foregroundColor(.nostosFg3)
                    }
                }
                Spacer()

                if let actions {
                    HStack(spacing: 8) {
                        ForEach(Array(actions!.enumerated()), id: \.offset) { _, action in
                            action
                        }
                    }
                }
            }
            .padding(.horizontal, NostosSpacing.pagePadding)
            .padding(.vertical, NostosSpacing.xxxl)

            // simple divider fallback
            Rectangle().frame(height: 1).foregroundColor(.nostosBorder)
                .padding(.horizontal, NostosSpacing.pagePadding)
                .padding(.bottom, NostosSpacing.xxxl)
        }
    }
}

// Provide a simple WaveLensLogo fallback in case original isn't compiled
struct WaveLensLogo: View {
    var body: some View { Text("WL") }
}

// Basic UI building blocks used throughout the app
struct CardView<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        VStack { content }
            .padding(NostosSpacing.md)
            .background(Color.nostosSurface)
            .cornerRadius(NostosRadii.md)
            .overlay(RoundedRectangle(cornerRadius: NostosRadii.md).stroke(Color.nostosBorder))
    }
}

struct SectionLabel: View {
    let text: String
    var body: some View { Text(text).font(.headline).foregroundColor(.nostosFg1) }
}

struct Stat: View {
    let value: String
    let label: String
    init(_ value: String, label: String) { self.value = value; self.label = label }
    var body: some View { VStack { Text(value).font(.title2); Text(label).font(.caption) } }
}

struct NostosStatCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View { CardView { content } }
}

struct NostosProgressBar: View {
    var value: Double
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4).fill(Color.nostosProgressBg).frame(height: 8)
                RoundedRectangle(cornerRadius: 4).fill(Color.nostosGreen).frame(width: max(0, CGFloat(value) * g.size.width), height: 8)
            }
        }.frame(height: 8)
    }
}

extension Color {
    static let nostosGold = Color.yellow
}

extension Font {
    static func nostosDisplay(_ size: CGFloat = 20, weight: Font.Weight = .regular) -> Font {
        return .system(size: size, weight: weight)
    }
}
