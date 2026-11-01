import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var viewModel: NoiseSignalViewModel

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Text("NOISE SIGNAL")
                    .font(.footnote.weight(.semibold))
                    .tracking(4)
                    .foregroundStyle(Color.white.opacity(0.6))
                    .padding(.top, 12)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityLabel("Noise Signal")

                Spacer(minLength: 24)

                SignalStatusView(
                    classification: viewModel.classification,
                    isListening: viewModel.isListening,
                    hasMeasurement: showsValues
                )

                LevelReadoutView(
                    currentDecibels: viewModel.currentDecibels,
                    peakDecibels: viewModel.peakDecibels,
                    showsValues: showsValues
                )
                .padding(.top, 28)

                Spacer(minLength: 24)

                ListenButton(
                    isListening: viewModel.isListening,
                    isTransitioning: viewModel.isTransitioning
                ) {
                    Task { await viewModel.toggleListening() }
                }

                PermissionMessageView(
                    permission: viewModel.microphonePermission,
                    errorMessage: viewModel.errorMessage
                )
                .padding(.top, 16)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 12)
        }
        .preferredColorScheme(.dark)
    }

    /// While listening, wait for the session's first valid value; once stopped, keep the final values.
    private var showsValues: Bool {
        viewModel.isListening ? viewModel.hasSessionMeasurement : viewModel.hasAnyMeasurement
    }
}

#Preview {
    ContentView()
        .environmentObject(NoiseSignalViewModel(observesLifecycle: false))
}
