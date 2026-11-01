import AVFAudio
import Foundation

/// Service boundary: only numeric measurements and lifecycle results cross it.
protocol AudioLevelMonitoring: Sendable {
    /// Configures + activates the session, starts the engine, and returns a bounded stream of display levels.
    /// The stream finishes when monitoring stops for any reason.
    func start() async throws -> AsyncStream<Double>
    /// Idempotent teardown.
    func stop() async
    /// Whether the system currently reports a usable audio input.
    func isInputAvailable() -> Bool
}

/// Concise, user-safe errors. Raw system errors are never shown.
enum AudioMonitorError: LocalizedError, Sendable, Equatable {
    case permissionDenied
    case microphoneUnavailable
    case inputFormatUnavailable
    case sessionConfigurationFailed
    case engineStartFailed
    case interrupted
    case unknown

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone access is required to listen."
        case .microphoneUnavailable:
            return "Microphone unavailable."
        case .inputFormatUnavailable:
            return "No usable microphone input is available."
        case .sessionConfigurationFailed:
            return "Unable to prepare the microphone."
        case .engineStartFailed:
            return "Unable to start listening."
        case .interrupted:
            return "Listening was interrupted."
        case .unknown:
            return "Listening could not start."
        }
    }
}

/// Per-session processing state owned by the audio tap.
///
/// AVAudioNode delivers tap callbacks serially on one internal thread, and this object is only
/// touched from that callback after creation — hence `@unchecked Sendable`.
/// It never stores a buffer: each buffer is reduced to a single number and released.
final class TapProcessor: @unchecked Sendable {
    private let processor: AudioLevelProcessor
    private var smoother: LevelSmoother
    private let minimumEmitIntervalNanos: UInt64
    private var lastEmitNanos: UInt64?
    private let continuation: AsyncStream<Double>.Continuation

    init(
        processor: AudioLevelProcessor,
        smoothingAlpha: Double,
        updatesPerSecond: Double,
        continuation: AsyncStream<Double>.Continuation
    ) {
        self.processor = processor
        self.smoother = LevelSmoother(alpha: smoothingAlpha)
        let interval = 1.0 / max(updatesPerSecond, 1)
        self.minimumEmitIntervalNanos = UInt64(interval * 1_000_000_000)
        self.continuation = continuation
    }

    /// Real-time path: no awaits, no locks, no allocation beyond the stack, no UI.
    func process(_ buffer: AVAudioPCMBuffer) {
        guard let channels = buffer.floatChannelData,
              buffer.format.channelCount > 0 else { return }
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return }

        // Channel 0 is sufficient for an ambient level from the iPhone microphone.
        let samples = UnsafeBufferPointer(start: channels[0], count: frameCount)
        guard let level = processor.displayLevel(from: samples),
              let smoothed = smoother.update(level) else { return }

        let now = DispatchTime.now().uptimeNanoseconds
        if let last = lastEmitNanos, now &- last < minimumEmitIntervalNanos { return }
        lastEmitNanos = now
        continuation.yield(smoothed)
    }
}
