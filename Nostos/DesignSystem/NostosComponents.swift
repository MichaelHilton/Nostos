import SwiftUI

// MARK: - PageHeaderView
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
                    Text(title)
                        .font(.nostosDisplay(size: 34, weight: .bold))
                        .foregroundColor(.nostosFg1)

                    if let subtitle {
                        Text(subtitle)
                            .font(.nostosSubtitle)
                            .foregroundColor(.nostosFg3)
                    }
                }
                Spacer()

                if let actions {
                    HStack(spacing: 8) {
                        ForEach(Array(actions.enumerated()), id: \.offset) { _, action in
                            action
                        }
                    }
                }
            }
            .padding(.horizontal, NostosSpacing.pagePadding)
            .padding(.vertical, NostosSpacing.xxxl)

            MeanderDivider()
                .frame(height: 7)
                .padding(.horizontal, NostosSpacing.pagePadding)
                .padding(.bottom, NostosSpacing.xxxl)
        }
    }
}

// MARK: - CardView
struct CardView<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .background(Color.nostosSurface)
        .border(Color.nostosBorder, width: 1)
        .cornerRadius(NostosRadii.xl)
        .padding(.horizontal, NostosSpacing.xxxl)
    }
}

// MARK: - SectionLabel
struct SectionLabel: View {
    let text: String
    let diamond: Bool

    init(_ text: String, diamond: Bool = false) {
        self.text = text
        self.diamond = diamond
    }

    var body: some View {
        HStack(spacing: 6) {
            if diamond {
                DiamondAccent(size: 4)
            }
            Text(text)
                .font(.nostosLabel)
                .foregroundColor(.nostosFg3)
                .textCase(.uppercase)
        }
        .padding(.bottom, NostosSpacing.md)
    }
}

// MARK: - NostosStatCard
struct NostosStatCard: View {
    let label: String
    let value: String
    let color: Color

    init(_ label: String, value: String, color: Color = .nostosFg1) {
        self.label = label
        self.value = value
        self.color = color
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.nostosLabel)
                .foregroundColor(.nostosFg3)
                .textCase(.uppercase)

            Text(value)
                .font(.nostosDisplay(size: 28, weight: .bold))
                .foregroundColor(color)
                .lineLimit(1)
        }
        .padding(NostosSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.nostosSurface)
        .border(Color.nostosBorder, width: 1)
        .cornerRadius(NostosRadii.xl)
    }
}

// MARK: - NostosProgressBar
struct NostosProgressBar: View {
    let value: Double
    let total: Double
    let color: Color

    init(_ value: Double, total: Double = 100, color: Color = .nostosAccent) {
        self.value = value
        self.total = total
        self.color = color
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.nostosProgressBg)

                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: geo.size.width * min(value / total, 1.0))
                    .animation(.linear(duration: 0.18), value: value)
            }
        }
        .frame(height: 4)
    }
}

// MARK: - MeanderDivider
struct MeanderDivider: View {
    var body: some View {
        Canvas { context, size in
            let patternWidth: CGFloat = 30
            let stepHeight = size.height * 0.5
            let stepDepth = 5.0

            var path = Path()
            var x: CGFloat = 0

            while x < size.width {
                path.move(to: CGPoint(x: x, y: stepHeight))
                path.addLine(to: CGPoint(x: x + stepDepth, y: stepHeight))
                path.addLine(to: CGPoint(x: x + stepDepth, y: stepHeight - (size.height * 0.4)))
                path.addLine(to: CGPoint(x: x + stepDepth * 2, y: stepHeight - (size.height * 0.4)))
                path.addLine(to: CGPoint(x: x + stepDepth * 2, y: stepHeight))
                path.addLine(to: CGPoint(x: x + stepDepth * 3, y: stepHeight))
                path.addLine(to: CGPoint(x: x + stepDepth * 3, y: stepHeight + (size.height * 0.4)))
                path.addLine(to: CGPoint(x: x + stepDepth * 4, y: stepHeight + (size.height * 0.4)))
                path.addLine(to: CGPoint(x: x + stepDepth * 4, y: stepHeight))
                path.addLine(to: CGPoint(x: x + stepDepth * 5, y: stepHeight))

                x += patternWidth
            }

            let stroke = StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round)
            context.stroke(path, with: .color(Color.nostosAccent.opacity(0.18)), style: stroke)
        }
    }
}

// MARK: - DiamondAccent
struct DiamondAccent: View {
    let size: CGFloat

    init(size: CGFloat = 6) {
        self.size = size
    }

    var body: some View {
        RoundedRectangle(cornerRadius: size / 4)
            .fill(Color.nostosGold.opacity(0.75))
            .frame(width: size, height: size)
            .rotationEffect(.degrees(45))
    }
}

// MARK: - StarDotBackground
struct StarDotBackground: View {
    var body: some View {
        Canvas { context, size in
            let gridSize: CGFloat = 28
            let mainDotRadius: CGFloat = 0.9
            let cornerDotRadius: CGFloat = 0.5

            var x: CGFloat = 0
            while x < size.width {
                var y: CGFloat = 0
                while y < size.height {
                    // Center dot
                    var circlePath = Path(ellipseIn: CGRect(
                        x: x + gridSize / 2 - mainDotRadius,
                        y: y + gridSize / 2 - mainDotRadius,
                        width: mainDotRadius * 2,
                        height: mainDotRadius * 2
                    ))
                    context.fill(circlePath, with: .color(Color.nostosAccent.opacity(0.16)))

                    // Corner dots
                    for (dx, dy): (CGFloat, CGFloat) in [(0.0, 0.0), (gridSize, 0.0), (0.0, gridSize), (gridSize, gridSize)] {
                        circlePath = Path(ellipseIn: CGRect(
                            x: x + dx - cornerDotRadius,
                            y: y + dy - cornerDotRadius,
                            width: cornerDotRadius * 2,
                            height: cornerDotRadius * 2
                        ))
                        context.fill(circlePath, with: .color(Color.nostosAccent.opacity(0.1)))
                    }

                    y += gridSize
                }
                x += gridSize
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }
}

// MARK: - Stat helper (for inside cards)
struct Stat: View {
    let label: String
    let value: String
    let color: Color

    init(_ label: String, value: String, color: Color = .nostosFg1) {
        self.label = label
        self.value = value
        self.color = color
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.nostosCaption)
                .foregroundColor(.nostosFg3)

            Text(value)
                .font(.nostosDisplay(size: 26, weight: .bold))
                .foregroundColor(color)
                .lineLimit(1)
        }
    }
}
