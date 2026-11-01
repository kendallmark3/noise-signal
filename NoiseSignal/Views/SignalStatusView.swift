import SwiftUI

/// The dominant element: the classification word, or a neutral READY / MEASURING state.
struct SignalStatusView: View {
    let classification: NoiseClassification
    let isListening: Bool
    let hasMeasurement: Bool

    @ScaledMetric(relativeTo: .largeTitle) private var fontSize: CGFloat = 64

    var body: some View {
        VStack(spacing: 14) {
            LiveIndicator(isListening: isListening)

            Text(title)
                .font(.system(size: fontSize, weight: .black, design: .default))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .contentTransition(.opacity)
                .animation(.easeOut(duration: 0.2), value: title)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(.updatesFrequently)
    }

    private var title: String {
        if isListening && !hasMeasurement { return "MEASURING" }
        if !hasMeasurement { return "READY" }
        return classification.displayName
    }

    private var color: Color {
        guard hasMeasurement else { return Color.white.opacity(0.55) }
        return classification == .tooLoud ? Color(red: 1, green: 0.27, blue: 0.23) : .white
    }

    private var accessibilityText: String {
        if isListening && !hasMeasurement { return "Measuring" }
        if !hasMeasurement { return "Ready to listen" }
        return isListening ? "Live: \(classification.displayName.lowercased())" : "Last reading: \(classification.displayName.lowercased())"
    }
}

/// Restrained live cue: a softly pulsing dot, only while listening. Static when Reduce Motion is on.
private struct LiveIndicator: View {
    let isListening: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isListening ? Color.white : Color.white.opacity(0.25))
                .frame(width: 8, height: 8)
                .opacity(isListening && pulse && !reduceMotion ? 0.25 : 1)
            Text(isListening ? "LIVE" : "IDLE")
                .font(.caption.weight(.semibold))
                .tracking(2)
                .foregroundStyle(Color.white.opacity(isListening ? 0.85 : 0.4))
        }
        .onChange(of: isListening, initial: true) { _, listening in
            if listening && !reduceMotion {
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { pulse = true }
            } else {
                withAnimation(.default) { pulse = false }
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        SignalStatusView(classification: .loud, isListening: true, hasMeasurement: true)
    }
}
