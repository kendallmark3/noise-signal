import SwiftUI

/// Current level and session peak. Shows placeholders until a valid value exists.
struct LevelReadoutView: View {
    let currentDecibels: Double
    let peakDecibels: Double
    let showsValues: Bool

    var body: some View {
        VStack(spacing: 6) {
            Text(showsValues ? LevelFormatter.string(for: currentDecibels) : LevelFormatter.placeholder)
                .font(.system(.largeTitle, design: .rounded).weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.white)
                .contentTransition(.numericText())

            Text(showsValues ? LevelFormatter.peakString(for: peakDecibels) : "Peak \(LevelFormatter.placeholder)")
                .font(.system(.title3, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color.white.opacity(0.6))

            Text("Approximate · not a calibrated meter")
                .font(.caption2)
                .foregroundStyle(Color.white.opacity(0.35))
                .padding(.top, 4)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        guard showsValues else { return "No level reading yet" }
        return "Level \(LevelFormatter.accessibilityString(for: currentDecibels)), peak \(LevelFormatter.accessibilityString(for: peakDecibels)). Approximate."
    }
}
