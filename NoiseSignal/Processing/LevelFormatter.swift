import Foundation

/// Single place that turns a level into display text. Only finite values are formatted.
enum LevelFormatter {
    static let placeholder = "— dB"

    static func string(for value: Double) -> String {
        guard value.isFinite else { return placeholder }
        return "\(Int(value.rounded())) dB"
    }

    static func peakString(for value: Double) -> String {
        guard value.isFinite else { return "Peak \(placeholder)" }
        return "Peak \(string(for: value))"
    }

    static func accessibilityString(for value: Double) -> String {
        guard value.isFinite else { return "no reading" }
        return "\(Int(value.rounded())) decibels"
    }
}
