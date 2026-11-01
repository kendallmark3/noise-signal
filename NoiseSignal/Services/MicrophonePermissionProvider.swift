import AVFAudio

protocol MicrophonePermissionProviding: Sendable {
    func currentPermission() -> PermissionState
    func requestPermission() async -> PermissionState
}

/// System-backed permission provider (iOS 17+ `AVAudioApplication`).
struct SystemMicrophonePermissionProvider: MicrophonePermissionProviding {
    func currentPermission() -> PermissionState {
        PermissionState(AVAudioApplication.shared.recordPermission)
    }

    /// Shows the system prompt only when undetermined. The callback is wrapped in a checked
    /// continuation (resumes exactly once), then permission is re-read rather than trusting the Bool.
    func requestPermission() async -> PermissionState {
        guard currentPermission() == .undetermined else { return currentPermission() }
        _ = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        return currentPermission()
    }
}
