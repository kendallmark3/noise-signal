import Foundation

/// Exponential moving average: `smoothed = α · new + (1 − α) · previous`.
/// Deterministic and testable. The first value passes through unchanged.
struct LevelSmoother: Sendable {
    let alpha: Double
    private(set) var value: Double?

    /// - Parameter alpha: 0...1. Higher reacts faster. Default 0.35 keeps obvious changes visible within ~0.3 s at 15 Hz.
    init(alpha: Double = 0.35) {
        self.alpha = min(max(alpha, 0), 1)
        self.value = nil
    }

    mutating func reset() {
        value = nil
    }

    /// Feeds a new raw value. Non-finite input is ignored and the previous value (or `nil`) is returned.
    @discardableResult
    mutating func update(_ newValue: Double) -> Double? {
        guard newValue.isFinite else { return value }
        guard let previousValue = value else {
            value = newValue
            return newValue
        }
        let smoothedValue = alpha * newValue + (1 - alpha) * previousValue
        value = smoothedValue
        return smoothedValue
    }
}
