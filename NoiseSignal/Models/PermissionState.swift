import AVFAudio

/// User-facing microphone permission state.
enum PermissionState: Equatable, Sendable {
    case undetermined
    case granted
    case denied
    /// System-level unavailability (unknown future states, device restrictions).
    case restricted
}

extension PermissionState {
    /// Maps the system record-permission value to the app's state.
    /// iOS exposes no distinct "restricted" microphone value, so any unknown value maps to `.restricted`.
    init(_ systemPermission: AVAudioApplication.recordPermission) {
        switch systemPermission {
        case .undetermined:
            self = .undetermined
        case .granted:
            self = .granted
        case .denied:
            self = .denied
        @unknown default:
            self = .restricted
        }
    }
}
