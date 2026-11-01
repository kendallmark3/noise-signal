import Foundation

/// Single owner of user-visible monitoring state. Every published mutation happens on the main actor;
/// the audio service only ever hands back numbers.
@MainActor
final class NoiseSignalViewModel: ObservableObject {
    @Published private(set) var isListening = false
    @Published private(set) var isTransitioning = false
    @Published private(set) var currentDecibels: Double = 0
    @Published private(set) var peakDecibels: Double = 0
    @Published private(set) var classification: NoiseClassification = .quiet
    @Published private(set) var microphonePermission: PermissionState = .undetermined
    @Published private(set) var errorMessage: String?
    /// True once the current listening session has delivered its first valid value.
    @Published private(set) var hasSessionMeasurement = false
    /// True once any session has delivered a valid value (final values stay visible after STOP).
    @Published private(set) var hasAnyMeasurement = false
    @Published private(set) var isInputAvailable = true
    /// Finished sessions, newest first.
    @Published private(set) var sessions: [NoiseSession]
    /// The session that just ended; cleared when the next one starts.
    @Published private(set) var lastSession: NoiseSession?
    @Published private(set) var settings: AppSettings

    private let permissionProvider: any MicrophonePermissionProviding
    private let monitor: any AudioLevelMonitoring
    private let dataStore: any AppDataStoring
    private let now: () -> Date
    private var thresholds: NoiseThresholds { settings.thresholds }
    private var sessionStartDate: Date?
    /// Mutated only on the main actor; `nonisolated(unsafe)` so `deinit` can cancel it.
    nonisolated(unsafe) private var measurementTask: Task<Void, Never>?
    /// Incremented on every start and stop. Measurements tagged with an old generation are dropped.
    private var sessionGeneration: UInt64 = 0
    private var lifecycleObserver: AppLifecycleObserver?

    static let interruptedMessage = AudioMonitorError.interrupted.errorDescription!
    static let unavailableMessage = AudioMonitorError.microphoneUnavailable.errorDescription!
    static let inputChangedMessage = "Microphone input changed. Tap LISTEN to resume."
    static let backgroundMessage = "Listening stopped when the app left the screen."

    init(
        permissionProvider: any MicrophonePermissionProviding = SystemMicrophonePermissionProvider(),
        monitor: any AudioLevelMonitoring = AudioMonitorActor(),
        dataStore: any AppDataStoring = UserDefaultsAppDataStore(),
        now: @escaping () -> Date = Date.init,
        observesLifecycle: Bool = true
    ) {
        self.permissionProvider = permissionProvider
        self.monitor = monitor
        self.dataStore = dataStore
        self.now = now
        self.sessions = dataStore.loadSessions()
        self.settings = dataStore.loadSettings()
        self.microphonePermission = permissionProvider.currentPermission()
        self.isInputAvailable = monitor.isInputAvailable()

        if observesLifecycle {
            lifecycleObserver = AppLifecycleObserver { [weak self] event in
                self?.handle(event)
            }
        }
        // Monitoring never starts automatically.
    }

    deinit {
        measurementTask?.cancel()
        let monitor = self.monitor
        Task { await monitor.stop() }
    }

    /// The screen stays on only while listening, and only if the user wants it to.
    var shouldKeepScreenAwake: Bool {
        isListening && settings.keepsScreenAwake
    }

    // MARK: - Intent

    func toggleListening() async {
        if isListening {
            await stopListening()
        } else {
            await startListening()
        }
    }

    func startListening() async {
        guard !isTransitioning, !isListening else { return }
        isTransitioning = true
        defer { isTransitioning = false }

        errorMessage = nil

        // Refresh before every attempt; prompt only when undetermined; re-read afterwards.
        var permission = permissionProvider.currentPermission()
        if permission == .undetermined {
            _ = await permissionProvider.requestPermission()
            permission = permissionProvider.currentPermission()
        }
        microphonePermission = permission
        guard permission == .granted else { return } // PermissionMessageView explains denied/restricted.

        isInputAvailable = monitor.isInputAvailable()
        guard isInputAvailable else {
            errorMessage = Self.unavailableMessage
            return
        }

        sessionGeneration &+= 1
        let generation = sessionGeneration

        let stream: AsyncStream<Double>
        do {
            stream = try await monitor.start()
        } catch {
            isListening = false
            errorMessage = (error as? AudioMonitorError)?.errorDescription
                ?? AudioMonitorError.unknown.errorDescription
            return
        }

        // A system stop (interruption, background) may have arrived while we were starting.
        guard generation == sessionGeneration else {
            await monitor.stop()
            return
        }

        // New session: the previous peak is never carried forward.
        peakDecibels = 0
        hasSessionMeasurement = false
        lastSession = nil
        sessionStartDate = now()
        isListening = true

        measurementTask = Task { [weak self] in
            for await value in stream {
                guard let self else { return }
                self.consume(value, generation: generation)
            }
            self?.streamDidFinish(generation: generation)
        }
    }

    func stopListening() async {
        guard !isTransitioning else { return }
        guard isListening else { return } // repeated STOP is a no-op
        isTransitioning = true
        defer { isTransitioning = false }
        await tearDown()
    }

    /// Stops because of a system event. Preserves values and shows a message; never restarts.
    func stopForSystemEvent(message: String?) async {
        guard isListening || isTransitioning else { return }
        errorMessage = message
        await tearDown()
    }

    /// Re-reads permission and input availability (foreground return, interruption end, route change).
    func refreshSystemState() {
        microphonePermission = permissionProvider.currentPermission()
        isInputAvailable = monitor.isInputAvailable()
        if isInputAvailable, errorMessage == Self.unavailableMessage {
            errorMessage = nil
        }
    }

    func handle(_ event: LifecycleEvent) {
        switch event {
        case .didBecomeActive, .interruptionEnded, .routeChanged:
            refreshSystemState()
        case .didEnterBackground:
            Task { await stopForSystemEvent(message: Self.backgroundMessage) }
        case .interruptionBegan, .mediaServicesReset:
            Task { await stopForSystemEvent(message: Self.interruptedMessage) }
        case .inputUnavailable:
            isInputAvailable = false
            Task { await stopForSystemEvent(message: Self.unavailableMessage) }
        }
    }

    // MARK: - Settings & History

    func setTooLoudThreshold(_ decibels: Int) {
        settings.tooLoudThreshold = AppSettings.clampedThreshold(decibels)
        dataStore.saveSettings(settings)
        if hasAnyMeasurement {
            classification = thresholds.classification(for: currentDecibels)
        }
    }

    func setKeepsScreenAwake(_ keepsScreenAwake: Bool) {
        settings.keepsScreenAwake = keepsScreenAwake
        dataStore.saveSettings(settings)
    }

    func clearHistory() {
        sessions = []
        lastSession = nil
        dataStore.saveSessions(sessions)
    }

    /// Every way a session can end passes through `tearDown`, while `isListening` is still true exactly once.
    private func recordFinishedSession() {
        defer { sessionStartDate = nil }
        guard isListening, hasSessionMeasurement, let startedAt = sessionStartDate else { return }
        let session = NoiseSession(
            startedAt: startedAt,
            duration: now().timeIntervalSince(startedAt),
            peakDecibels: peakDecibels,
            classification: thresholds.classification(for: peakDecibels)
        )
        sessions = Array(([session] + sessions).prefix(NoiseSession.maxStored))
        lastSession = session
        dataStore.saveSessions(sessions)
    }

    // MARK: - Measurements

    private func consume(_ value: Double, generation: UInt64) {
        guard generation == sessionGeneration, isListening, value.isFinite else { return }
        currentDecibels = value
        if hasSessionMeasurement {
            peakDecibels = max(peakDecibels, value)
        } else {
            peakDecibels = value
            hasSessionMeasurement = true
            hasAnyMeasurement = true
        }
        classification = thresholds.classification(for: value)
    }

    /// The monitor finished the stream on its own (e.g. the engine stopped after a hardware change).
    private func streamDidFinish(generation: UInt64) {
        guard generation == sessionGeneration, isListening else { return }
        Task { await stopForSystemEvent(message: Self.inputChangedMessage) }
    }

    private func tearDown() async {
        sessionGeneration &+= 1
        measurementTask?.cancel()
        measurementTask = nil
        recordFinishedSession()
        isListening = false // stale values are no longer reported as live
        await monitor.stop()
    }
}
