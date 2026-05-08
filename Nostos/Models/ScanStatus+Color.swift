import SwiftUI

extension ScanStatus {
    var color: Color {
        switch self {
        case .running:   return .nostosOrange
        case .completed: return .nostosGreen
        case .failed:    return .nostosRed
        }
    }
}
