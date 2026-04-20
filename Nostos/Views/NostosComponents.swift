import SwiftUI

// MARK: - MeanderDivider

struct MeanderDivider: View {
    var color: Color = NostosTheme.accent
    var opacity: Double = 0.18
    var height: CGFloat = 7

    var body: some View {
        Canvas { ctx, size in
            let stepW = 30.0
            let h = Double(size.height)
            let count = Int(size.width / stepW) + 2
            for i in 0 ..< count {
                let x = Double(i) * stepW
                var path = Path()
                path.move(to:    CGPoint(x: x,       y: h * 0.5))
                path.addLine(to: CGPoint(x: x + 5,   y: h * 0.5))
                path.addLine(to: CGPoint(x: x + 5,   y: h * 0.1))
                path.addLine(to: CGPoint(x: x + 15,  y: h * 0.1))
                path.addLine(to: CGPoint(x: x + 15,  y: h * 0.9))
                path.addLine(to: CGPoint(x: x + 20,  y: h * 0.9))
                path.addLine(to: CGPoint(x: x + 20,  y: h * 0.5))
                ctx.stroke(path,
                           with: .color(color.opacity(opacity)),
                           style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round))
            }
        }
        .frame(height: height)
        .allowsHitTesting(false)
    }
}

// MARK: - StarDotBackground

struct StarDotBackground: View {
    var body: some View {
        Canvas { ctx, size in
            let spacing = 28.0
            let rows = Int(size.height / spacing) + 2
            let cols = Int(size.width / spacing) + 2
            let fill = GraphicsContext.Shading.color(NostosTheme.accent.opacity(0.09))
            for row in 0 ..< rows {
                for col in 0 ..< cols {
                    let x = Double(col) * spacing
                    let y = Double(row) * spacing
                    let r = 0.9
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                        with: fill
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - DiamondAccent

struct DiamondAccent: View {
    var color: Color = NostosTheme.gold
    var size: CGFloat = 8

    var body: some View {
        Rectangle()
            .fill(color.opacity(0.75))
            .frame(width: size, height: size)
            .rotationEffect(.degrees(45))
            .frame(width: size * 1.42, height: size * 1.42)
    }
}

// MARK: - SectionLabel

struct SectionLabel: View {
    let title: String
    var showDiamond: Bool = true

    var body: some View {
        HStack(spacing: 6) {
            if showDiamond {
                DiamondAccent(size: 5)
            }
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(NostosTheme.fg3)
                .textCase(.uppercase)
                
        }
        .padding(.bottom, 6)
    }
}

// MARK: - NostosPageHeader

struct NostosPageHeader: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(NostosTheme.displayFont(size: 34))
                    .foregroundColor(NostosTheme.fg1)
                    
                if let sub = subtitle {
                    Text(sub)
                        .font(.system(size: 12))
                        .foregroundColor(NostosTheme.fg3)
                }
            }
            .padding(.bottom, 14)

            MeanderDivider()
        }
        .padding(.horizontal, 26)
        .padding(.top, 24)
        .padding(.bottom, 0)
    }
}

// MARK: - NostosCard

struct NostosCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(.horizontal, 15)
            .padding(.vertical, 13)
            .background(NostosTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(NostosTheme.border, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
    }
}

// MARK: - NostosProgressBar

struct NostosProgressBar: View {
    let value: Double  // 0...1
    var color: Color = NostosTheme.accent
    var trackHeight: CGFloat = 4

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(NostosTheme.progressBg)
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: geo.size.width * min(1, max(0, value)))
                    .animation(.linear(duration: 0.18), value: value)
            }
        }
        .frame(height: trackHeight)
    }
}

// MARK: - StatCell

struct StatCell: View {
    let label: String
    let value: String
    var color: Color = NostosTheme.fg1

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(NostosTheme.fg3)
                .textCase(.uppercase)
                
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(color)
                
        }
    }
}

// MARK: - WaveLensLogo (sidebar logo mark)

struct WaveLensLogo: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(NostosTheme.accent)

            Circle()
                .stroke(Color.white.opacity(0.18), lineWidth: max(1, size * 0.018))
                .padding(size * 0.13)

            WaveLensOval()
                .stroke(Color.white.opacity(0.92),
                        style: StrokeStyle(lineWidth: max(1, size * 0.042),
                                           lineCap: .round))
                .padding(size * 0.13)

            Circle()
                .stroke(Color.white.opacity(0.4), lineWidth: max(1, size * 0.02))
                .padding(size * 0.39)

            Circle()
                .fill(Color.white.opacity(0.95))
                .padding(size * 0.448)

            // Gold north indicator
            VStack(spacing: 0) {
                Circle()
                    .fill(Color(hex: "D4A030"))
                    .frame(width: max(2, size * 0.04), height: max(2, size * 0.04))
                Rectangle()
                    .fill(Color(hex: "D4A030"))
                    .frame(width: max(1, size * 0.028), height: size * 0.05)
                Spacer()
            }
            .padding(.top, size * 0.095)
        }
        .frame(width: size, height: size)
    }
}

private struct WaveLensOval: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        p.move(to:       CGPoint(x: w * 0.185, y: h * 0.5))
        p.addCurve(to:   CGPoint(x: w * 0.5,   y: h * 0.13),
                   control1: CGPoint(x: w * 0.185, y: h * 0.305),
                   control2: CGPoint(x: w * 0.31,  y: h * 0.145))
        p.addCurve(to:   CGPoint(x: w * 0.87,  y: h * 0.47),
                   control1: CGPoint(x: w * 0.695, y: h * 0.115),
                   control2: CGPoint(x: w * 0.855, y: h * 0.275))
        p.addCurve(to:   CGPoint(x: w * 0.535, y: h * 0.835),
                   control1: CGPoint(x: w * 0.885, y: h * 0.665),
                   control2: CGPoint(x: w * 0.73,  y: h * 0.82))
        p.addCurve(to:   CGPoint(x: w * 0.185, y: h * 0.5),
                   control1: CGPoint(x: w * 0.345, y: h * 0.85),
                   control2: CGPoint(x: w * 0.185, y: h * 0.72))
        return p
    }
}

// MARK: - CompassRoseWatermark

struct CompassRoseWatermark: View {
    var body: some View {
        Canvas { ctx, size in
            let cx = size.width / 2, cy = size.height / 2
            let R = min(cx, cy) * 0.88

            ctx.stroke(
                Path { p in p.addEllipse(in: CGRect(x: cx-R, y: cy-R, width: R*2, height: R*2)) },
                with: .color(NostosTheme.accent.opacity(0.35)),
                style: StrokeStyle(lineWidth: 0.8, dash: [3, 5])
            )
            ctx.stroke(
                Path { p in
                    let r2 = R * 0.73
                    p.addEllipse(in: CGRect(x: cx-r2, y: cy-r2, width: r2*2, height: r2*2))
                },
                with: .color(NostosTheme.accent.opacity(0.18)),
                style: StrokeStyle(lineWidth: 0.5)
            )

            for (idx, deg) in [0.0, 90.0, 180.0, 270.0].enumerated() {
                let rad = deg * Double.pi / 180
                let tip  = CGPoint(x: cx + sin(rad) * R * 0.87,   y: cy - cos(rad) * R * 0.87)
                let base = CGPoint(x: cx + sin(rad) * R * 0.46,   y: cy - cos(rad) * R * 0.46)
                let lpt  = CGPoint(x: cx + sin(rad-0.18) * R*0.7, y: cy - cos(rad-0.18) * R*0.7)
                let rpt  = CGPoint(x: cx + sin(rad+0.18) * R*0.7, y: cy - cos(rad+0.18) * R*0.7)
                var arrow = Path()
                arrow.move(to: tip); arrow.addLine(to: lpt)
                arrow.addLine(to: base); arrow.addLine(to: rpt)
                arrow.closeSubpath()
                ctx.fill(arrow, with: .color(NostosTheme.accent.opacity(idx == 0 ? 0.55 : 0.28)))
            }

            let ir = R * 0.33
            ctx.stroke(
                Path { p in p.addEllipse(in: CGRect(x: cx-ir, y: cy-ir, width: ir*2, height: ir*2)) },
                with: .color(NostosTheme.accent.opacity(0.22)),
                style: StrokeStyle(lineWidth: 0.8)
            )
            ctx.fill(
                Path(ellipseIn: CGRect(x: cx-4, y: cy-4, width: 8, height: 8)),
                with: .color(NostosTheme.accent.opacity(0.2))
            )
        }
        .allowsHitTesting(false)
    }
}

// MARK: - BreakdownBar  (for Vault view)

struct BreakdownBar: View {
    let label: String
    let pct: Double
    let rightLabel: String
    var barColor: Color = NostosTheme.accent
    var barOpacity: Double = 0.75
    var labelWidth: CGFloat = 36

    var body: some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(NostosTheme.fg2)
                .frame(width: labelWidth, alignment: .leading)
                .lineLimit(1)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(NostosTheme.progressBg)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(barColor.opacity(barOpacity))
                        .frame(width: geo.size.width * min(1, pct / 100))
                }
            }
            .frame(height: 5)
            Text(rightLabel)
                .font(.system(size: 11))
                .foregroundColor(NostosTheme.fg2)
                .frame(width: 44, alignment: .trailing)
        }
    }
}
