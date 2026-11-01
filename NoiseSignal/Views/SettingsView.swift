import SwiftUI

/// Deliberately small: one level, one toggle, one clear action.
struct SettingsView: View {
    @EnvironmentObject private var viewModel: NoiseSignalViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isConfirmingClear = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(
                        value: Binding(
                            get: { viewModel.settings.tooLoudThreshold },
                            set: { viewModel.setTooLoudThreshold($0) }
                        ),
                        in: AppSettings.thresholdRange,
                        step: AppSettings.thresholdStep
                    ) {
                        LabeledContent("TOO LOUD at", value: "\(viewModel.settings.tooLoudThreshold) dB")
                    }
                } footer: {
                    Text("Approximate and relative to this phone. Not a calibrated meter.")
                }

                Section {
                    Toggle("Keep Screen Awake", isOn: Binding(
                        get: { viewModel.settings.keepsScreenAwake },
                        set: { viewModel.setKeepsScreenAwake($0) }
                    ))
                } footer: {
                    Text("Only while listening. Listening stops if the phone locks.")
                }

                Section {
                    Button("Clear History", role: .destructive) { isConfirmingClear = true }
                        .disabled(viewModel.sessions.isEmpty)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Clear all history?", isPresented: $isConfirmingClear, titleVisibility: .visible) {
                Button("Clear History", role: .destructive) { viewModel.clearHistory() }
            }
        }
        .preferredColorScheme(.dark)
    }
}
