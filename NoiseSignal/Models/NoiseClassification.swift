import Foundation

/// User-facing loudness bucket. Pure value type — no SwiftUI or audio dependencies.
enum NoiseClassification: String, CaseIterable, Codable, Sendable {
    case quiet
    case normal
    case loud
    case tooLoud

    var displayName: String {
        switch self {
        case .quiet:
            return "QUIET"
        case .normal:
            return "NORMAL"
        case .loud:
            return "LOUD"
        case .tooLoud:
            return "TOO LOUD"
        }
    }
}
