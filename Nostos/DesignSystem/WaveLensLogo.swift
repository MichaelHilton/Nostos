import SwiftUI

// MARK: - WaveLensLogo (main logo mark)
struct WaveLensLogo: View {
    var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height)

            // Background rounded rect
            let bgPath = Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: scale * 0.22)
            context.fill(bgPath, with: .color(.nostosAccent))

            // Outer ring (semi-opaque white)
            var path = Path()
            path.addEllipse(in: CGRect(x: size.width * 0.13, y: size.height * 0.13, width: size.width * 0.74, height: size.height * 0.74))
            context.stroke(path, with: .color(.white.opacity(0.18)), lineWidth: scale * 0.018)

            // Wave path
            path = Path()
            let startX = size.width * 0.185
            let midX = size.width * 0.5
            let endX = size.width * 0.87
            let topY = size.height * 0.13
            let bottomY = size.height * 0.835

            path.move(to: CGPoint(x: startX, y: size.height * 0.5))
            path.addCurve(to: CGPoint(x: endX, y: size.height * 0.5),
                         control1: CGPoint(x: midX, y: topY),
                         control2: CGPoint(x: midX, y: bottomY))
            context.stroke(path, with: .color(.white), lineWidth: scale * 0.042)

            // Inner circle
            var circlePath = Path()
            circlePath.addEllipse(in: CGRect(x: size.width * 0.39, y: size.height * 0.39, width: size.width * 0.22, height: size.height * 0.22))
            context.stroke(circlePath, with: .color(.white.opacity(0.4)), lineWidth: scale * 0.02)

            // Center dot
            circlePath = Path()
            circlePath.addEllipse(in: CGRect(x: size.width * 0.44, y: size.height * 0.44, width: size.width * 0.12, height: size.height * 0.12))
            context.fill(circlePath, with: .color(.white.opacity(0.95)))

            // Gold north needle
            let needleX = size.width * 0.5
            let needleTopY = size.height * 0.097
            let needleBottomY = size.height * 0.145
            path = Path()
            path.move(to: CGPoint(x: needleX, y: needleTopY))
            path.addLine(to: CGPoint(x: needleX, y: needleBottomY))
            context.stroke(path, with: .color(.nostosGold), lineWidth: scale * 0.03)

            // Gold circle top
            circlePath = Path()
            circlePath.addEllipse(in: CGRect(x: needleX - scale * 0.015, y: size.height * 0.094 - scale * 0.015, width: scale * 0.03, height: scale * 0.03))
            context.fill(circlePath, with: .color(.nostosGold))
        }
        .frame(maxWidth: 28, maxHeight: 28)
    }
}

// MARK: - WaveLensLogoWatermark (for sidebar footer)
struct WaveLensLogoWatermark: View {
    var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height)

            // Outer ring (dashed)
            var path = Path()
            path.addEllipse(in: CGRect(x: size.width * 0.04, y: size.height * 0.04, width: size.width * 0.92, height: size.height * 0.92))
            let stroke = StrokeStyle(lineWidth: scale * 0.012, dash: [scale * 0.025, scale * 0.018])
            context.stroke(path, with: .color(.nostosAccent.opacity(0.35)), style: stroke)

            // Middle ring
            path = Path()
            path.addEllipse(in: CGRect(x: size.width * 0.13, y: size.height * 0.13, width: size.width * 0.74, height: size.height * 0.74))
            context.stroke(path, with: .color(.nostosAccent.opacity(0.2)), lineWidth: scale * 0.014)

            // Wave path
            path = Path()
            path.move(to: CGPoint(x: size.width * 0.13, y: size.height * 0.5))
            path.addCurve(to: CGPoint(x: size.width * 0.87, y: size.height * 0.5),
                         control1: CGPoint(x: size.width * 0.5, y: size.height * 0.245),
                         control2: CGPoint(x: size.width * 0.5, y: size.height * 0.655))
            context.stroke(path, with: .color(.nostosAccent), lineWidth: scale * 0.032)

            // Inner circle ring
            var circlePath = Path()
            circlePath.addEllipse(in: CGRect(x: size.width * 0.37, y: size.height * 0.37, width: size.width * 0.26, height: size.height * 0.26))
            context.stroke(circlePath, with: .color(.nostosAccent), lineWidth: scale * 0.014)

            // Center dot
            circlePath = Path()
            circlePath.addEllipse(in: CGRect(x: size.width * 0.45, y: size.height * 0.45, width: size.width * 0.1, height: size.height * 0.1))
            context.fill(circlePath, with: .color(.nostosAccent))

            // Cardinal ticks
            for angle in [0, 90, 180, 270] {
                let rad = CGFloat(angle) * .pi / 180
                let x1 = size.width / 2 + sin(rad) * size.width * 0.44
                let y1 = size.height / 2 - cos(rad) * size.height * 0.44
                let x2 = size.width / 2 + sin(rad) * size.width * 0.48
                let y2 = size.height / 2 - cos(rad) * size.height * 0.48

                path = Path()
                path.move(to: CGPoint(x: x1, y: y1))
                path.addLine(to: CGPoint(x: x2, y: y2))
                context.stroke(path, with: .color(.nostosAccent), lineWidth: scale * 0.014)
            }

            // Gold north needle
            let needleX = size.width * 0.5
            let needleTopY = size.height * 0.095
            let needleBottomY = size.height * 0.148
            path = Path()
            path.move(to: CGPoint(x: needleX, y: needleTopY))
            path.addLine(to: CGPoint(x: needleX, y: needleBottomY))
            context.stroke(path, with: .color(.nostosGold), lineWidth: scale * 0.025)

            // Gold circle
            circlePath = Path()
            let goldRadius = scale * 0.018
            circlePath.addEllipse(in: CGRect(x: needleX - goldRadius, y: needleTopY - goldRadius, width: goldRadius * 2, height: goldRadius * 2))
            context.fill(circlePath, with: .color(.nostosGold))
        }
    }
}
