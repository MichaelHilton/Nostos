import SwiftUI

// MARK: - WaveLensLogo (main logo mark)
struct WaveLensLogo: View {
    var body: some View {
        Canvas { context, size in
            // Use renderer to produce paths and stroke widths; keeps drawing math testable
            let elements = WaveLensLogoRenderer.mainElements(for: size)

            context.fill(elements.bgPath, with: .color(.nostosAccent))
            context.stroke(elements.outerRing, with: .color(.white.opacity(0.18)), lineWidth: elements.outerRingLineWidth)
            context.stroke(elements.wave, with: .color(.white), lineWidth: elements.waveLineWidth)
            context.stroke(elements.innerRing, with: .color(.white.opacity(0.4)), lineWidth: elements.innerRingLineWidth)
            context.fill(elements.centerDot, with: .color(.white.opacity(0.95)))
            context.stroke(elements.needle, with: .color(.nostosGold), lineWidth: elements.needleLineWidth)
            context.fill(elements.needleDot, with: .color(.nostosGold))
        }
        .frame(maxWidth: 28, maxHeight: 28)
    }
}

// MARK: - Renderer helpers (testable geometry)
// Renderer moved to WaveLensLogoRenderer.swift to improve coverage attribution

// MARK: - WaveLensLogoWatermark (for sidebar footer)
struct WaveLensLogoWatermark: View {
    var body: some View {
        Canvas { context, size in
            // Use renderer for watermark geometry to make testing deterministic
            let elems = WaveLensLogoRenderer.watermarkElements(for: size)

            context.stroke(elems.outerRing, with: .color(.nostosAccent.opacity(0.35)), style: elems.outerStroke)
            context.stroke(elems.middleRing, with: .color(.nostosAccent.opacity(0.2)), lineWidth: elems.middleLineWidth)
            context.stroke(elems.wave, with: .color(.nostosAccent), lineWidth: elems.waveLineWidth)
            context.stroke(elems.innerRing, with: .color(.nostosAccent), lineWidth: elems.innerLineWidth)
            context.fill(elems.centerDot, with: .color(.nostosAccent))

            for tick in elems.ticks {
                context.stroke(tick, with: .color(.nostosAccent), lineWidth: elems.innerLineWidth)
            }

            context.stroke(elems.needle, with: .color(.nostosGold), lineWidth: elems.needleLineWidth)
            context.fill(elems.goldDot, with: .color(.nostosGold))
        }
    }
}
