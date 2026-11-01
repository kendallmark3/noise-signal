import AVFAudio
import Foundation

/// Serializes every AVAudioSession / AVAudioEngine lifecycle operation.
///
/// Session configuration, activation, route validation, engine creation, tap install/removal,
/// engine start/stop, deactivation and configuration-change cleanup all run on this actor's
/// serial executor, so the engine is never touched from two isolation domains at once.
actor AudioMonitorActor: AudioLevelMonitoring {
    private let processor: AudioLevelProcessor
    private let smoothingAlpha: Double
    private let updatesPerSecond: Double
    private let tapBufferSize: AVAudioFrameCount

    private var engine: AVAudioEngine?
    private var continuation: AsyncStream<Double>.Continuation?
    private var tapInstalled = false
    private var sessionActivatedByUs = false
    private var configurationObserver: NSObjectProtocol?
    private var sessionID: UInt64 = 0

    init(
        processor: AudioLevelProcessor = AudioLevelProcessor(),
        smoothingAlpha: Double = 0.35,
        updatesPerSecond: Double = 15,
        tapBufferSize: AVAudioFrameCount = 1024
    ) {
        self.processor = processor
        self.smoothingAlpha = smoothingAlpha
        self.updatesPerSecond = updatesPerSecond
        self.tapBufferSize = tapBufferSize
    }

    nonisolated func isInputAvailable() -> Bool {
        AVAudioSession.sharedInstance().isInputAvailable
    }

    func start() async throws -> AsyncStream<Double> {
        // Defensive: a previous session that was never stopped is torn down first.
        cleanUp()
        sessionID &+= 1
        let currentSessionID = sessionID

        let session = AVAudioSession.sharedInstance()

        // 1–2. Configure and activate the session.
        do {
            try session.setCategory(.record, mode: .measurement, options: [])
        } catch {
            cleanUp()
            throw AudioMonitorError.sessionConfigurationFailed
        }
        do {
            try session.setActive(true)
            sessionActivatedByUs = true
        } catch {
            cleanUp()
            throw AudioMonitorError.sessionConfigurationFailed
        }

        // 3. Validate input availability.
        guard session.isInputAvailable, !session.currentRoute.inputs.isEmpty else {
            cleanUp()
            throw AudioMonitorError.microphoneUnavailable
        }

        // 4. Create the engine and validate the input format.
        let engine = AVAudioEngine()
        self.engine = engine
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            cleanUp()
            throw AudioMonitorError.inputFormatUnavailable
        }

        // Bounded delivery: the UI only ever needs the newest value.
        let (stream, continuation) = AsyncStream.makeStream(
            of: Double.self,
            bufferingPolicy: .bufferingNewest(1)
        )
        self.continuation = continuation

        // 5–6. Remove any existing tap, then install exactly one.
        inputNode.removeTap(onBus: 0)
        let tapProcessor = TapProcessor(
            processor: processor,
            smoothingAlpha: smoothingAlpha,
            updatesPerSecond: updatesPerSecond,
            continuation: continuation
        )
        inputNode.installTap(
            onBus: 0,
            bufferSize: tapBufferSize,
            format: format,
            block: Self.makeTapBlock(tapProcessor)
        )
        tapInstalled = true

        // If the hardware configuration changes and the engine stops, end this session cleanly.
        configurationObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: nil
        ) { [weak self] _ in
            Task { await self?.handleConfigurationChange(sessionID: currentSessionID) }
        }

        // 7. Start the engine.
        engine.prepare()
        do {
            try engine.start()
        } catch {
            cleanUp()
            throw AudioMonitorError.engineStartFailed
        }

        // 8. Hand back numbers only.
        return stream
    }

    func stop() async {
        cleanUp()
    }

    // MARK: - Private

    /// Built in a nonisolated context so the block never inherits actor isolation —
    /// it runs on the real-time audio thread and must return immediately.
    private nonisolated static func makeTapBlock(_ tapProcessor: TapProcessor) -> AVAudioNodeTapBlock {
        { buffer, _ in
            tapProcessor.process(buffer)
        }
    }

    private func handleConfigurationChange(sessionID changedSessionID: UInt64) {
        guard changedSessionID == sessionID, let engine else { return }
        // A configuration change stops the engine; if it is no longer running, the input
        // this session was measuring is gone. Finish the stream — the view model shows a retry message.
        if !engine.isRunning {
            cleanUp()
        }
    }

    /// Idempotent teardown. Safe after partial starts and repeated calls.
    private func cleanUp() {
        continuation?.finish()
        continuation = nil

        if let configurationObserver {
            NotificationCenter.default.removeObserver(configurationObserver)
        }
        configurationObserver = nil

        if let engine {
            if tapInstalled {
                engine.inputNode.removeTap(onBus: 0)
            }
            engine.stop()
        }
        tapInstalled = false
        engine = nil // releases the tap block, TapProcessor and any buffer references

        if sessionActivatedByUs {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            sessionActivatedByUs = false
        }
    }
}
