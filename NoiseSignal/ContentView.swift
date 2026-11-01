import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var viewModel: NoiseSignalViewModel
    @State private var isShowingHistory = false
    @State private var isShowingSettings = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    headerButton("clock", label: "History") { isShowingHistory = true }
                    Spacer()
                    Text("NOISE SIGNAL")
                        .font(.footnote.weight(.semibold))
                        .tracking(4)
                        .foregroundStyle(Color.white.opacity(0.6))
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityLabel("Noise Signal")
                    Spacer()
                    headerButton("gearshape", label: "Settings") { isShowingSettings = true }
                }
                .padding(.top, 4)

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

                // Fixed height so the primary button never moves when the summary appears.
                Color.clear
                    .frame(height: 44)
                    .overlay {
                        if let session = viewModel.lastSession, !viewModel.isListening {
                            SessionSummaryButton(session: session) { isShowingHistory = true }
                        }
                    }
                    .padding(.top, 14)

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
        .sheet(isPresented: $isShowingHistory) { HistoryView() }
        .sheet(isPresented: $isShowingSettings) { SettingsView() }
        .onChange(of: viewModel.shouldKeepScreenAwake, initial: true) { _, keepsAwake in
            UIApplication.shared.isIdleTimerDisabled = keepsAwake
        }
    }

    private func headerButton(_ systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(Color.white.opacity(0.7))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
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
