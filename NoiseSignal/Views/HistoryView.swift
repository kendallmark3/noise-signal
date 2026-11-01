import SwiftUI

/// One-line result of the session that just ended. Opens History.
struct SessionSummaryButton: View {
    let session: NoiseSession
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text("Saved · \(LevelFormatter.peakString(for: session.peakDecibels)) · \(LevelFormatter.durationString(for: session.duration))")
                    .monospacedDigit()
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
            }
            .font(.footnote)
            .foregroundStyle(Color.white.opacity(0.7))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Session saved. Peak \(LevelFormatter.accessibilityString(for: session.peakDecibels)). Open history.")
    }
}

/// Finished sessions, newest first.
struct HistoryView: View {
    @EnvironmentObject private var viewModel: NoiseSignalViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.sessions.isEmpty {
                    ContentUnavailableView(
                        "No Sessions Yet",
                        systemImage: "clock",
                        description: Text("Tap LISTEN, then STOP, and the session appears here.")
                    )
                } else {
                    List(viewModel.sessions) { session in
                        SessionRow(session: session)
                    }
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct SessionRow: View {
    let session: NoiseSession

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(session.startedAt, format: .dateTime.month(.abbreviated).day().hour().minute())
                    .font(.subheadline)
                Text(LevelFormatter.durationString(for: session.duration))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(LevelFormatter.peakString(for: session.peakDecibels))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                Text(session.classification.displayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(session.classification == .tooLoud ? Color(red: 1, green: 0.27, blue: 0.23) : .secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
