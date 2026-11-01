import XCTest
@testable import NoiseSignal

// MARK: - Fakes

final class FakePermissionProvider: MicrophonePermissionProviding, @unchecked Sendable {
    var state: PermissionState
    var stateAfterRequest: PermissionState
    private(set) var requestCount = 0

    init(state: PermissionState, stateAfterRequest: PermissionState = .granted) {
        self.state = state
        self.stateAfterRequest = stateAfterRequest
    }

    func currentPermission() -> PermissionState { state }

    func requestPermission() async -> PermissionState {
        requestCount += 1
        state = stateAfterRequest
        return state
    }
}

final class FakeAudioMonitor: AudioLevelMonitoring, @unchecked Sendable {
    var startError: AudioMonitorError?
    var inputAvailable = true
    /// When false, `stop()` leaves the stream open to simulate a lagging producer.
    var finishesStreamOnStop = true
    private(set) var startCount = 0
    private(set) var stopCount = 0
    private var continuation: AsyncStream<Double>.Continuation?

    func start() async throws -> AsyncStream<Double> {
        startCount += 1
        if let startError { throw startError }
        let (stream, continuation) = AsyncStream.makeStream(of: Double.self, bufferingPolicy: .bufferingNewest(1))
        self.continuation = continuation
        return stream
    }

    func stop() async {
        stopCount += 1
        if finishesStreamOnStop {
            continuation?.finish()
            continuation = nil
        }
    }

    func isInputAvailable() -> Bool { inputAvailable }

    func send(_ value: Double) { continuation?.yield(value) }

    /// Simulates the engine stopping on its own (hardware configuration change).
    func endStream() {
        continuation?.finish()
        continuation = nil
    }
}

// MARK: - Tests

@MainActor
final class NoiseSignalViewModelTests: XCTestCase {
    // XCTest creates a fresh instance per test method, so each test gets new fakes.
    private let permission = FakePermissionProvider(state: .granted)
    private let monitor = FakeAudioMonitor()
    private lazy var viewModel = NoiseSignalViewModel(
        permissionProvider: permission,
        monitor: monitor,
        observesLifecycle: false
    )

    /// Sends a value and waits for the main actor to consume it.
    private func send(_ value: Double) async {
        monitor.send(value)
        for _ in 0..<20 {
            await Task.yield()
        }
        try? await Task.sleep(nanoseconds: 20_000_000)
    }

    private func waitUntil(_ condition: () -> Bool, timeout: TimeInterval = 1) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() && Date() < deadline {
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
    }

    func testInitialStateIsIdleAndDoesNotStart() {
        XCTAssertFalse(viewModel.isListening)
        XCTAssertFalse(viewModel.isTransitioning)
        XCTAssertFalse(viewModel.hasAnyMeasurement)
        XCTAssertEqual(viewModel.microphonePermission, .granted)
        XCTAssertEqual(monitor.startCount, 0)
    }

    func testStartAndStop() async {
        await viewModel.startListening()
        XCTAssertTrue(viewModel.isListening)
        XCTAssertFalse(viewModel.isTransitioning)
        XCTAssertEqual(monitor.startCount, 1)

        await viewModel.stopListening()
        XCTAssertFalse(viewModel.isListening)
        XCTAssertFalse(viewModel.isTransitioning)
        XCTAssertEqual(monitor.stopCount, 1)
    }

    func testDuplicateStartRequestsAreIgnored() async {
        let vm = viewModel
        async let first: Void = vm.startListening()
        async let second: Void = vm.startListening()
        _ = await (first, second)
        await viewModel.startListening()
        XCTAssertEqual(monitor.startCount, 1)
        XCTAssertTrue(viewModel.isListening)
    }

    func testDuplicateStopRequestsAreSafe() async {
        await viewModel.startListening()
        await viewModel.stopListening()
        await viewModel.stopListening()
        await viewModel.stopListening()
        XCTAssertEqual(monitor.stopCount, 1)
        XCTAssertFalse(viewModel.isListening)
        XCTAssertFalse(viewModel.isTransitioning)
    }

    func testFailedStartLeavesStoppedWithConciseMessage() async {
        monitor.startError = .engineStartFailed
        await viewModel.startListening()
        XCTAssertFalse(viewModel.isListening)
        XCTAssertFalse(viewModel.isTransitioning)
        XCTAssertEqual(viewModel.errorMessage, "Unable to start listening.")

        monitor.startError = nil
        await viewModel.startListening()
        XCTAssertTrue(viewModel.isListening, "retry works after a failed start")
        XCTAssertNil(viewModel.errorMessage)
    }

    func testUnavailableInputDoesNotStart() async {
        monitor.inputAvailable = false
        await viewModel.startListening()
        XCTAssertFalse(viewModel.isListening)
        XCTAssertEqual(monitor.startCount, 0)
        XCTAssertEqual(viewModel.errorMessage, "Microphone unavailable.")
    }

    func testUndeterminedPermissionRequestsOnceThenStarts() async {
        permission.state = .undetermined
        permission.stateAfterRequest = .granted
        await viewModel.startListening()
        XCTAssertEqual(permission.requestCount, 1)
        XCTAssertEqual(viewModel.microphonePermission, .granted)
        XCTAssertTrue(viewModel.isListening)
    }

    func testDeniedPermissionNeverRepromptsOrStarts() async {
        permission.state = .undetermined
        permission.stateAfterRequest = .denied
        await viewModel.startListening()
        await viewModel.startListening()
        await viewModel.startListening()
        XCTAssertEqual(permission.requestCount, 1, "system prompt is shown at most once")
        XCTAssertEqual(viewModel.microphonePermission, .denied)
        XCTAssertFalse(viewModel.isListening)
        XCTAssertEqual(monitor.startCount, 0)
    }

    func testRestrictedPermissionDoesNotStart() async {
        permission.state = .restricted
        await viewModel.startListening()
        XCTAssertEqual(permission.requestCount, 0)
        XCTAssertEqual(viewModel.microphonePermission, .restricted)
        XCTAssertFalse(viewModel.isListening)
    }

    func testPermissionRefreshAfterReturningFromSettings() {
        permission.state = .denied
        viewModel.handle(.didBecomeActive)
        XCTAssertEqual(viewModel.microphonePermission, .denied)
        permission.state = .granted
        viewModel.handle(.didBecomeActive)
        XCTAssertEqual(viewModel.microphonePermission, .granted)
    }

    func testMeasurementsUpdateLevelPeakAndClassification() async {
        await viewModel.startListening()
        XCTAssertFalse(viewModel.hasSessionMeasurement, "measuring state before first value")

        await send(55)
        XCTAssertTrue(viewModel.hasSessionMeasurement)
        XCTAssertEqual(viewModel.currentDecibels, 55)
        XCTAssertEqual(viewModel.peakDecibels, 55)
        XCTAssertEqual(viewModel.classification, .normal)

        await send(88)
        XCTAssertEqual(viewModel.classification, .tooLoud)
        XCTAssertEqual(viewModel.peakDecibels, 88)

        await send(30)
        XCTAssertEqual(viewModel.currentDecibels, 30)
        XCTAssertEqual(viewModel.peakDecibels, 88, "peak holds the highest value")
        XCTAssertEqual(viewModel.classification, .quiet)
    }

    func testInvalidMeasurementsAreIgnored() async {
        await viewModel.startListening()
        await send(60)
        await send(.nan)
        await send(.infinity)
        await send(-.infinity)
        XCTAssertEqual(viewModel.currentDecibels, 60)
        XCTAssertEqual(viewModel.peakDecibels, 60)
    }

    func testFinalValuesRemainVisibleAfterStop() async {
        await viewModel.startListening()
        await send(72)
        await viewModel.stopListening()
        XCTAssertEqual(viewModel.currentDecibels, 72)
        XCTAssertEqual(viewModel.peakDecibels, 72)
        XCTAssertEqual(viewModel.classification, .loud)
        XCTAssertTrue(viewModel.hasAnyMeasurement)
    }

    func testPeakResetsBetweenSessions() async {
        await viewModel.startListening()
        await send(95)
        await viewModel.stopListening()
        XCTAssertEqual(viewModel.peakDecibels, 95)

        await viewModel.startListening()
        XCTAssertEqual(viewModel.peakDecibels, 0, "previous session's peak is not carried forward")
        await send(50)
        XCTAssertEqual(viewModel.peakDecibels, 50)
    }

    func testStaleMeasurementsCannotUpdateStateAfterStop() async {
        monitor.finishesStreamOnStop = false
        await viewModel.startListening()
        await send(60)
        await viewModel.stopListening()
        await send(99)
        XCTAssertEqual(viewModel.currentDecibels, 60)
        XCTAssertEqual(viewModel.peakDecibels, 60)
    }

    func testInterruptionStopsWithoutRestart() async {
        await viewModel.startListening()
        await send(65)
        viewModel.handle(.interruptionBegan)
        await waitUntil { !self.viewModel.isListening }
        XCTAssertFalse(viewModel.isListening)
        XCTAssertEqual(viewModel.errorMessage, "Listening was interrupted.")
        XCTAssertEqual(viewModel.currentDecibels, 65)

        viewModel.handle(.interruptionEnded)
        await waitUntil { false }
        XCTAssertFalse(viewModel.isListening, "never restarts automatically")
        XCTAssertEqual(monitor.startCount, 1)
    }

    func testInputUnavailableStopsWithMessage() async {
        await viewModel.startListening()
        monitor.inputAvailable = false
        viewModel.handle(.inputUnavailable)
        await waitUntil { !self.viewModel.isListening }
        XCTAssertFalse(viewModel.isListening)
        XCTAssertEqual(viewModel.errorMessage, "Microphone unavailable.")

        monitor.inputAvailable = true
        viewModel.handle(.routeChanged)
        XCTAssertNil(viewModel.errorMessage, "message clears when input returns")
        XCTAssertFalse(viewModel.isListening, "no auto-restart on new input")
    }

    func testBackgroundingStops() async {
        await viewModel.startListening()
        viewModel.handle(.didEnterBackground)
        await waitUntil { !self.viewModel.isListening }
        XCTAssertFalse(viewModel.isListening)
    }

    func testSystemEventWhenIdleShowsNoMessage() async {
        await viewModel.stopForSystemEvent(message: "x")
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(monitor.stopCount, 0)
    }

    func testStreamEndingUnexpectedlyStopsWithRetryMessage() async {
        await viewModel.startListening()
        monitor.endStream()
        await waitUntil { !self.viewModel.isListening }
        XCTAssertFalse(viewModel.isListening)
        XCTAssertEqual(viewModel.errorMessage, NoiseSignalViewModel.inputChangedMessage)
    }

    func testRepeatedCyclesStayConsistent() async {
        for index in 0..<20 {
            await viewModel.startListening()
            await send(Double(40 + index))
            await viewModel.stopListening()
        }
        XCTAssertEqual(monitor.startCount, 20)
        XCTAssertEqual(monitor.stopCount, 20)
        XCTAssertFalse(viewModel.isListening)
        XCTAssertFalse(viewModel.isTransitioning)
        XCTAssertEqual(viewModel.peakDecibels, 59)
    }
}
