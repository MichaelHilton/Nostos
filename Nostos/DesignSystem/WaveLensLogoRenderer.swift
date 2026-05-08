import SwiftUI

// MARK: - WaveLensLogoRenderer (testable geometry extracted)
struct WaveLensLogoRenderer {
    @inline(never)
    static func mainElements(for size: CGSize) -> (bgPath: Path,
                                                 outerRing: Path, outerRingLineWidth: CGFloat,
                                                 wave: Path, waveLineWidth: CGFloat,
                                                 innerRing: Path, innerRingLineWidth: CGFloat,
                                                 centerDot: Path,
                                                 needle: Path, needleLineWidth: CGFloat,
                                                 needleDot: Path) {
        let scale = min(size.width, size.height)

        let bgPath = Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: scale * 0.22)

        var outerRing = Path()
        outerRing.addEllipse(in: CGRect(x: size.width * 0.13, y: size.height * 0.13, width: size.width * 0.74, height: size.height * 0.74))

        var wave = Path()
        let startX = size.width * 0.185
        let midX = size.width * 0.5
        let endX = size.width * 0.87
        let topY = size.height * 0.13
        let bottomY = size.height * 0.835
        wave.move(to: CGPoint(x: startX, y: size.height * 0.5))
        wave.addCurve(to: CGPoint(x: endX, y: size.height * 0.5), control1: CGPoint(x: midX, y: topY), control2: CGPoint(x: midX, y: bottomY))

        var innerRing = Path()
        innerRing.addEllipse(in: CGRect(x: size.width * 0.39, y: size.height * 0.39, width: size.width * 0.22, height: size.height * 0.22))

        var centerDot = Path()
        centerDot.addEllipse(in: CGRect(x: size.width * 0.44, y: size.height * 0.44, width: size.width * 0.12, height: size.height * 0.12))

        let needleX = size.width * 0.5
        let needleTopY = size.height * 0.097
        let needleBottomY = size.height * 0.145
        var needle = Path()
        needle.move(to: CGPoint(x: needleX, y: needleTopY))
        needle.addLine(to: CGPoint(x: needleX, y: needleBottomY))

        var needleDot = Path()
        needleDot.addEllipse(in: CGRect(x: needleX - scale * 0.015, y: size.height * 0.094 - scale * 0.015, width: scale * 0.03, height: scale * 0.03))

        return (bgPath,
                outerRing, scale * 0.018,
                wave, scale * 0.042,
                innerRing, scale * 0.02,
                centerDot,
                needle, scale * 0.03,
                needleDot)
    }

    @inline(never)
    static func watermarkElements(for size: CGSize) -> (outerRing: Path, outerStroke: StrokeStyle, middleRing: Path, middleLineWidth: CGFloat, wave: Path, waveLineWidth: CGFloat, innerRing: Path, innerLineWidth: CGFloat, centerDot: Path, ticks: [Path], needle: Path, needleLineWidth: CGFloat, goldDot: Path) {
        let scale = min(size.width, size.height)

        var outerRing = Path()
        outerRing.addEllipse(in: CGRect(x: size.width * 0.04, y: size.height * 0.04, width: size.width * 0.92, height: size.height * 0.92))
        let stroke = StrokeStyle(lineWidth: scale * 0.012, dash: [scale * 0.025, scale * 0.018])

        var middleRing = Path()
        middleRing.addEllipse(in: CGRect(x: size.width * 0.13, y: size.height * 0.13, width: size.width * 0.74, height: size.height * 0.74))

        var wave = Path()
        wave.move(to: CGPoint(x: size.width * 0.13, y: size.height * 0.5))
        wave.addCurve(to: CGPoint(x: size.width * 0.87, y: size.height * 0.5), control1: CGPoint(x: size.width * 0.5, y: size.height * 0.245), control2: CGPoint(x: size.width * 0.5, y: size.height * 0.655))

        var innerRing = Path()
        innerRing.addEllipse(in: CGRect(x: size.width * 0.37, y: size.height * 0.37, width: size.width * 0.26, height: size.height * 0.26))

        var centerDot = Path()
        centerDot.addEllipse(in: CGRect(x: size.width * 0.45, y: size.height * 0.45, width: size.width * 0.1, height: size.height * 0.1))

        var ticks: [Path] = []
        for angle in [0, 90, 180, 270] {
            let rad = CGFloat(angle) * .pi / 180
            let x1 = size.width / 2 + sin(rad) * size.width * 0.44
            let y1 = size.height / 2 - cos(rad) * size.height * 0.44
            let x2 = size.width / 2 + sin(rad) * size.width * 0.48
            let y2 = size.height / 2 - cos(rad) * size.height * 0.48

            var path = Path()
            path.move(to: CGPoint(x: x1, y: y1))
            path.addLine(to: CGPoint(x: x2, y: y2))
            ticks.append(path)
        }

        let needleX = size.width * 0.5
        let needleTopY = size.height * 0.095
        let needleBottomY = size.height * 0.148
        var needle = Path()
        needle.move(to: CGPoint(x: needleX, y: needleTopY))
        needle.addLine(to: CGPoint(x: needleX, y: needleBottomY))

        var goldDot = Path()
        let goldRadius = scale * 0.018
        goldDot.addEllipse(in: CGRect(x: needleX - goldRadius, y: needleTopY - goldRadius, width: goldRadius * 2, height: goldRadius * 2))

        return (outerRing, stroke, middleRing, scale * 0.014, wave, scale * 0.032, innerRing, scale * 0.014, centerDot, ticks, needle, scale * 0.025, goldDot)
    }
}
