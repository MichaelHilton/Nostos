import SwiftUI

// MARK: - Scanner Icon
struct ScannerIcon: View {
    let active: Bool

    var body: some View {
        Canvas { context, size in
            let stroke = StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
            let color: Color = active ? .white : .nostosFg3

            // Magnifying glass circle
            var path = Path()
            path.addEllipse(in: CGRect(x: 1.5, y: 1.5, width: 9, height: 9))
            context.stroke(path, with: .color(color), style: stroke)

            // Handle
            path = Path()
            path.move(to: CGPoint(x: 9.8, y: 9.8))
            path.addLine(to: CGPoint(x: 14, y: 14))
            context.stroke(path, with: .color(color), style: stroke)

            // Scan lines
            path = Path()
            path.move(to: CGPoint(x: 4.5, y: 5.5))
            path.addLine(to: CGPoint(x: 8, y: 5.5))
            context.stroke(path, with: .color(color.opacity(0.6)), style: StrokeStyle(lineWidth: 1))

            path = Path()
            path.move(to: CGPoint(x: 4.5, y: 7))
            path.addLine(to: CGPoint(x: 8, y: 7))
            context.stroke(path, with: .color(color.opacity(0.6)), style: StrokeStyle(lineWidth: 1))
        }
        .frame(width: 16, height: 16)
    }
}

// MARK: - Gallery Icon
struct GalleryIcon: View {
    let active: Bool

    var body: some View {
        Canvas { context, size in
            let stroke = StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
            let color: Color = active ? .white : .nostosFg3

            // 2x2 grid
            for (x, y): (CGFloat, CGFloat) in [(1.5, 1.5), (9, 1.5), (1.5, 9), (9, 9)] {
                var path = Path()
                path.addRect(CGRect(x: x, y: y, width: 5.5, height: 5.5))
                context.stroke(path, with: .color(color), style: stroke)
            }

            // Mountain in bottom-right
            var path = Path()
            path.move(to: CGPoint(x: 9.8, y: 13.2))
            path.addLine(to: CGPoint(x: 11.5, y: 10.8))
            path.addLine(to: CGPoint(x: 13.2, y: 13.2))
            context.stroke(path, with: .color(color.opacity(0.7)), style: StrokeStyle(lineWidth: 1))
        }
        .frame(width: 16, height: 16)
    }
}

// MARK: - Duplicates Icon
struct DuplicatesIcon: View {
    let active: Bool

    var body: some View {
        Canvas { context, size in
            let stroke = StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
            let color: Color = active ? .white : .nostosFg3

            // First rectangle
            var path = Path()
            path.addRect(CGRect(x: 1.5, y: 3.5, width: 9, height: 11))
            if active {
                context.fill(path, with: .color(color.opacity(0.15)))
            }
            context.stroke(path, with: .color(color), style: stroke)

            // Second rectangle (offset)
            path = Path()
            path.addRect(CGRect(x: 5.5, y: 1.5, width: 9, height: 11))
            if active {
                context.fill(path, with: .color(color.opacity(0.1)))
            }
            context.stroke(path, with: .color(color), style: stroke)

            // Lines
            path = Path()
            path.move(to: CGPoint(x: 8, y: 5.5))
            path.addLine(to: CGPoint(x: 12, y: 5.5))
            context.stroke(path, with: .color(color.opacity(0.6)), style: StrokeStyle(lineWidth: 1))

            path = Path()
            path.move(to: CGPoint(x: 8, y: 7.5))
            path.addLine(to: CGPoint(x: 12, y: 7.5))
            context.stroke(path, with: .color(color.opacity(0.6)), style: StrokeStyle(lineWidth: 1))
        }
        .frame(width: 16, height: 16)
    }
}

// MARK: - Vault Icon
struct VaultIcon: View {
    let active: Bool

    var body: some View {
        Canvas { context, size in
            let stroke = StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
            let color: Color = active ? .white : .nostosFg3

            // Outer ring
            var path = Path()
            path.addEllipse(in: CGRect(x: 2, y: 2, width: 12, height: 12))
            context.stroke(path, with: .color(color), style: stroke)

            // Inner dial
            path = Path()
            path.addEllipse(in: CGRect(x: 5.2, y: 5.2, width: 5.6, height: 5.6))
            context.stroke(path, with: .color(color), style: stroke)

            // Spokes
            path = Path()
            path.move(to: CGPoint(x: 8, y: 2))
            path.addLine(to: CGPoint(x: 8, y: 5.2))
            context.stroke(path, with: .color(color), style: stroke)

            path = Path()
            path.move(to: CGPoint(x: 8, y: 10.8))
            path.addLine(to: CGPoint(x: 8, y: 14))
            context.stroke(path, with: .color(color), style: stroke)

            path = Path()
            path.move(to: CGPoint(x: 2, y: 8))
            path.addLine(to: CGPoint(x: 5.2, y: 8))
            context.stroke(path, with: .color(color), style: stroke)

            path = Path()
            path.move(to: CGPoint(x: 10.8, y: 8))
            path.addLine(to: CGPoint(x: 14, y: 8))
            context.stroke(path, with: .color(color), style: stroke)

            // Handle
            path = Path()
            path.move(to: CGPoint(x: 8, y: 5.2))
            path.addLine(to: CGPoint(x: 10.4, y: 5.2))
            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))

            path = Path()
            path.move(to: CGPoint(x: 10.4, y: 5.2))
            path.addLine(to: CGPoint(x: 10.4, y: 8))
            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))

            // Hinge bolts
            path = Path()
            path.addEllipse(in: CGRect(x: 1.7, y: 4.7, width: 1.6, height: 1.6))
            context.fill(path, with: .color(color))

            path = Path()
            path.addEllipse(in: CGRect(x: 1.7, y: 9.7, width: 1.6, height: 1.6))
            context.fill(path, with: .color(color))
        }
        .frame(width: 16, height: 16)
    }
}
