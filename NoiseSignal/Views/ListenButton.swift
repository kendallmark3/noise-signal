import SwiftUI

/// The single primary control. LISTEN when idle, STOP while monitoring; disabled during transitions.
struct ListenButton: View {
    let isListening: Bool
    let isTransitioning: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Text(isListening ? "STOP" : "LISTEN")
                    .font(.title3.weight(.bold))
                    .tracking(3)
                    .opacity(isTransitioning ? 0 : 1)
                if isTransitioning {
                    ProgressView().tint(isListening ? .white : .black)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 72)
            .foregroundStyle(isListening ? Color.white : Color.black)
            .background(
                Capsule().fill(isListening ? Color.clear : Color.white)
            )
            .overlay(
                Capsule().strokeBorder(Color.white, lineWidth: 2)
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isTransitioning)
        .opacity(isTransitioning ? 0.6 : 1)
        .accessibilityLabel(isListening ? "Stop listening" : "Listen")
        .accessibilityHint(isListening ? "Stops measuring sound level" : "Starts measuring ambient sound level. Nothing is recorded.")
    }
}
