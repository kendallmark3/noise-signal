import Foundation

/// Centralized classification thresholds (approximate display dB). Values below are the defaults;
/// the TOO LOUD bound can be changed in Settings.
///
/// - QUIET:    < 40
/// - NORMAL:   40 ..< 70
/// - LOUD:     70 ..< 85
/// - TOO LOUD: >= 85
struct NoiseThresholds: Sendable, Equatable {
    let quietUpperBound: Double
    let normalUpperBound: Double
    let loudUpperBound: Double

    init(
        quietUpperBound: Double = 40,
        normalUpperBound: Double = 70,
        loudUpperBound: Double = 85
    ) {
        self.quietUpperBound = quietUpperBound
        self.normalUpperBound = normalUpperBound
        self.loudUpperBound = loudUpperBound
    }

    func classification(for decibels: Double) -> NoiseClassification {
        switch decibels {
        case ..<quietUpperBound:
            return .quiet
        case ..<normalUpperBound:
            return .normal
        case ..<loudUpperBound:
            return .loud
        default:
            return .tooLoud
        }
    }
}
