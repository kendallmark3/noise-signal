import XCTest
@testable import NoiseSignal

@MainActor
final class HistoryAndSettingsTests: XCTestCase {
    private let monitor = FakeAudioMonitor()
    private let store = FakeAppDataStore()
    private var currentDate = Date(timeIntervalSince1970: 1_000)

    private func makeViewModel() -> NoiseSignalViewModel {
        NoiseSignalViewModel(
            permissionProvider: FakePermissionProvider(state: .granted),
            monitor: monitor,
            dataStore: store,
            now: { [unowned self] in self.currentDate },
            observesLifecycle: false
        )
    }

    private func send(_ value: Double, to viewModel: NoiseSignalViewModel) async {
        monitor.send(value)
        let deadline = Date().addingTimeInterval(1)
        while viewModel.currentDecibels != value && Date() < deadline {
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
    }

    private func session(peak: Double = 50) -> NoiseSession {
        NoiseSession(startedAt: currentDate, duration: 1, peakDecibels: peak, classification: .normal)
    }

    // MARK: - History

    func testStopSavesOneSession() async {
        let viewModel = makeViewModel()
        await viewModel.startListening()
        await send(60, to: viewModel)
        await send(90, to: viewModel)
        currentDate.addTimeInterval(30)
        await viewModel.stopListening()
        await viewModel.stopListening()

        XCTAssertEqual(viewModel.sessions.count, 1)
        XCTAssertEqual(store.sessions, viewModel.sessions)
        XCTAssertEqual(viewModel.lastSession, viewModel.sessions.first)
        let saved = viewModel.sessions[0]
        XCTAssertEqual(saved.startedAt, Date(timeIntervalSince1970: 1_000))
        XCTAssertEqual(saved.duration, 30)
        XCTAssertEqual(saved.peakDecibels, 90)
        XCTAssertEqual(saved.classification, .tooLoud)
    }

    func testSystemStopSavesOneSession() async {
        let viewModel = makeViewModel()
        await viewModel.startListening()
        await send(60, to: viewModel)
        await viewModel.stopForSystemEvent(message: NoiseSignalViewModel.backgroundMessage)
        await viewModel.stopForSystemEvent(message: NoiseSignalViewModel.backgroundMessage)

        XCTAssertEqual(viewModel.sessions.count, 1)
    }

    func testStreamEndingOnItsOwnSavesOneSession() async {
        let viewModel = makeViewModel()
        await viewModel.startListening()
        await send(60, to: viewModel)
        monitor.endStream()
        let deadline = Date().addingTimeInterval(1)
        while viewModel.isListening && Date() < deadline {
            try? await Task.sleep(nanoseconds: 5_000_000)
        }

        XCTAssertEqual(viewModel.sessions.count, 1)
    }

    func testSessionWithoutMeasurementIsNotSaved() async {
        let viewModel = makeViewModel()
        await viewModel.startListening()
        await viewModel.stopListening()

        XCTAssertTrue(viewModel.sessions.isEmpty)
        XCTAssertNil(viewModel.lastSession)
    }

    func testNewestFirstAndSummaryClearsOnNextStart() async {
        let viewModel = makeViewModel()
        await viewModel.startListening()
        await send(50, to: viewModel)
        await viewModel.stopListening()
        await viewModel.startListening()
        XCTAssertNil(viewModel.lastSession)
        await send(75, to: viewModel)
        await viewModel.stopListening()

        XCTAssertEqual(viewModel.sessions.map(\.peakDecibels), [75, 50])
    }

    func testHistoryIsCapped() async {
        store.sessions = (0..<NoiseSession.maxStored).map { _ in session() }
        let viewModel = makeViewModel()
        await viewModel.startListening()
        await send(77, to: viewModel)
        await viewModel.stopListening()

        XCTAssertEqual(viewModel.sessions.count, NoiseSession.maxStored)
        XCTAssertEqual(viewModel.sessions.first?.peakDecibels, 77)
    }

    func testClearHistory() async {
        let viewModel = makeViewModel()
        await viewModel.startListening()
        await send(60, to: viewModel)
        await viewModel.stopListening()
        viewModel.clearHistory()

        XCTAssertTrue(viewModel.sessions.isEmpty)
        XCTAssertNil(viewModel.lastSession)
        XCTAssertTrue(store.sessions.isEmpty)
    }

    // MARK: - Settings

    func testThresholdIsClampedToValidSteps() {
        XCTAssertEqual(AppSettings.clampedThreshold(10), 75)
        XCTAssertEqual(AppSettings.clampedThreshold(500), 100)
        XCTAssertEqual(AppSettings.clampedThreshold(88), 90)
        XCTAssertEqual(AppSettings.clampedThreshold(85), 85)
        XCTAssertEqual(AppSettings(tooLoudThreshold: 10).thresholds.loudUpperBound, 75)
    }

    func testThresholdPersistsAndReclassifiesVisibleReading() async {
        let viewModel = makeViewModel()
        await viewModel.startListening()
        await send(80, to: viewModel)
        await viewModel.stopListening()
        XCTAssertEqual(viewModel.classification, .loud)

        viewModel.setTooLoudThreshold(75)

        XCTAssertEqual(viewModel.classification, .tooLoud)
        XCTAssertEqual(store.settings.tooLoudThreshold, 75)
        XCTAssertEqual(viewModel.sessions.first?.classification, .loud, "past sessions keep their classification")
    }

    func testSavedThresholdIsUsedForNewSessions() async {
        store.settings.tooLoudThreshold = 100
        let viewModel = makeViewModel()
        await viewModel.startListening()
        await send(90, to: viewModel)

        XCTAssertEqual(viewModel.classification, .loud)
    }

    func testScreenStaysAwakeOnlyWhileListeningWithSettingOn() async {
        let viewModel = makeViewModel()
        XCTAssertFalse(viewModel.shouldKeepScreenAwake)
        await viewModel.startListening()
        XCTAssertTrue(viewModel.shouldKeepScreenAwake)
        viewModel.setKeepsScreenAwake(false)
        XCTAssertFalse(viewModel.shouldKeepScreenAwake)
        XCTAssertFalse(store.settings.keepsScreenAwake)
        viewModel.setKeepsScreenAwake(true)
        await viewModel.stopListening()
        XCTAssertFalse(viewModel.shouldKeepScreenAwake)
    }

    // MARK: - Persistence

    private func makeDefaults() -> UserDefaults {
        let suite = "NoiseSignalTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { UserDefaults().removePersistentDomain(forName: suite) }
        return defaults
    }

    func testStoreRoundTripSurvivesRelaunch() {
        let defaults = makeDefaults()
        let saved = [session(peak: 66)]
        let settings = AppSettings(tooLoudThreshold: 95, keepsScreenAwake: false)
        let store = UserDefaultsAppDataStore(defaults: defaults)
        store.saveSessions(saved)
        store.saveSettings(settings)

        let relaunched = UserDefaultsAppDataStore(defaults: defaults)
        XCTAssertEqual(relaunched.loadSessions(), saved)
        XCTAssertEqual(relaunched.loadSettings(), settings)
    }

    func testMissingOrCorruptDataFallsBackSafely() {
        let defaults = makeDefaults()
        let store = UserDefaultsAppDataStore(defaults: defaults)
        XCTAssertEqual(store.loadSessions(), [])
        XCTAssertEqual(store.loadSettings(), AppSettings())

        defaults.set(Data("not json".utf8), forKey: "history.sessions")
        defaults.set(Data("not json".utf8), forKey: "app.settings")
        XCTAssertEqual(store.loadSessions(), [])
        XCTAssertEqual(store.loadSettings(), AppSettings())
    }

    // MARK: - Formatting

    func testDurationFormatting() {
        XCTAssertEqual(LevelFormatter.durationString(for: 45), "45s")
        XCTAssertEqual(LevelFormatter.durationString(for: 134), "2m 14s")
        XCTAssertEqual(LevelFormatter.durationString(for: 3_720), "1h 2m")
        XCTAssertEqual(LevelFormatter.durationString(for: -5), "0s")
        XCTAssertEqual(LevelFormatter.durationString(for: .nan), "0s")
    }
}
