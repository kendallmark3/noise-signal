import Foundation

/// User preferences. Pure value type; the TOO LOUD level is always a valid step in its range.
struct AppSettings: Codable, Equatable, Sendable {
    static let thresholdRange = 75...100
    static let thresholdStep = 5

    var tooLoudThreshold = 85
    var keepsScreenAwake = true

    var thresholds: NoiseThresholds {
        NoiseThresholds(loudUpperBound: Double(Self.clampedThreshold(tooLoudThreshold)))
    }

    static func clampedThreshold(_ decibels: Int) -> Int {
        let clamped = min(max(decibels, thresholdRange.lowerBound), thresholdRange.upperBound)
        return (clamped + thresholdStep / 2) / thresholdStep * thresholdStep
    }
}
