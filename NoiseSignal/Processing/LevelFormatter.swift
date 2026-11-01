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

    static func durationString(for seconds: TimeInterval) -> String {
        guard seconds.isFinite else { return "0s" }
        let total = max(0, Int(seconds.rounded()))
        let (hours, minutes, secs) = (total / 3600, total % 3600 / 60, total % 60)
        if hours > 0 { return "\(hours)h \(minutes)m" }
        if minutes > 0 { return "\(minutes)m \(secs)s" }
        return "\(secs)s"
    }
}
