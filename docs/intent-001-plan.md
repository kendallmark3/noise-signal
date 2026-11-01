Absolutely. I’d start with a very small V1 intent so Claude can build the shell, microphone permission flow, live level sampling, and the black Signal-style UI without overbuilding history yet.

Noise Signal — Intent 001

Phased SwiftUI Implementation Plan

Objective

Build the first working version of Noise Signal as a minimal SwiftUI iPhone app that:

* Requests microphone permission.
* Measures ambient microphone input without retaining audio.
* Displays an approximate live sound level in dB.
* Classifies the level as QUIET, NORMAL, LOUD, or TOO LOUD.
* Tracks the current session’s peak level.
* Starts and stops monitoring from one primary control.
* Uses a predominantly black, high-contrast interface.

This is a relative sound-level indicator, not a calibrated sound meter.

⸻

Phase 0: Project Setup and Constraints

Goals

Create the Xcode project, configure microphone privacy messaging, establish the minimum deployment target, and confirm that the app uses only SwiftUI, Swift concurrency, and native Apple frameworks.

Project Configuration

Configure:

* iOS application target
* SwiftUI lifecycle
* Swift language mode compatible with the selected deployment target
* Native frameworks only
* No external dependencies

Add the following privacy key to the app configuration:

NSMicrophoneUsageDescription

Suggested value:

Noise Signal uses the microphone to estimate ambient sound level. It does not record or save audio.

Do not add:

* Backend services
* Accounts
* Cloud storage
* Analytics
* Advertisements
* Speech recognition
* Audio recording
* History
* Charts
* Settings
* Calibration
* Background listening
* Health guidance

Recommended Initial File Structure

NoiseSignal/
├── NoiseSignalApp.swift
├── ContentView.swift
│
├── Models/
│   ├── NoiseClassification.swift
│   ├── PermissionState.swift
│   └── NoiseThresholds.swift
│
├── ViewModels/
│   └── NoiseSignalViewModel.swift
│
├── Services/
│   ├── AudioMonitorActor.swift
│   ├── AudioLevelMonitor.swift
│   ├── MicrophonePermissionProvider.swift
│   └── AppLifecycleObserver.swift
│
├── Processing/
│   ├── AudioLevelProcessor.swift
│   └── LevelSmoother.swift
│
├── Views/
│   ├── SignalStatusView.swift
│   ├── LevelReadoutView.swift
│   ├── ListenButton.swift
│   └── PermissionMessageView.swift
│
└── Tests/
    ├── NoiseClassificationTests.swift
    ├── AudioLevelProcessorTests.swift
    ├── LevelSmootherTests.swift
    └── NoiseSignalViewModelTests.swift

The exact file names may vary, but responsibilities should remain separated.

Test Checkpoint

Confirm that:

1. The project builds successfully.
2. The app launches into a blank or placeholder SwiftUI screen.
3. The microphone usage description is present in the built app configuration.
4. No external dependencies are included.
5. The app runs on a physical iPhone target.

⸻

Phase 1: Domain Models and Pure Logic

Goals

Define the application’s value types and isolate classification, permission mapping, threshold logic, and level formatting from SwiftUI and audio-session code.

NoiseClassification

Recommended implementation:

enum NoiseClassification: String, CaseIterable, Sendable {
    case quiet
    case normal
    case loud
    case tooLoud
    var displayName: String {
        switch self {
        case .quiet:
            return "QUIET"
        case .normal:
            return "NORMAL"
        case .loud:
            return "LOUD"
        case .tooLoud:
            return "TOO LOUD"
        }
    }
}

Add a classification method to NoiseThresholds or a dedicated classifier type.

PermissionState

Recommended implementation:

enum PermissionState: Equatable, Sendable {
    case undetermined
    case granted
    case denied
    case restricted
}

If the current iOS API does not expose a distinct restricted microphone state, represent system-level unavailability separately at the service boundary and map it to .restricted for user-facing state.

NoiseThresholds

Recommended implementation:

struct NoiseThresholds: Sendable {
    let quietUpperBound: Double
    let normalUpperBound: Double
    let loudUpperBound: Double
    init(
        quietUpperBound: Double = 40,
        normalUpperBound: Double = 70,
        loudUpperBound: Double = 85
    ) {
        self.quietUpperBound = quietUpperBound
        self.normalUpperBound = normalUpperBound
        self.loudUpperBound = loudUpperBound
    }
    func classification(for decibels: Double) -> NoiseClassification {
        switch decibels {
        case ..<quietUpperBound:
            return .quiet
        case ..<normalUpperBound:
            return .normal
        case ..<loudUpperBound:
            return .loud
        default:
            return .tooLoud
        }
    }
}

Classification rules:

* QUIET: < 40 dB
* NORMAL: 40–69 dB
* LOUD: 70–84 dB
* TOO LOUD: >= 85 dB

Keep this logic independent of SwiftUI.

Permission Mapping

Create a small adapter or provider that maps AVAudioSession.RecordPermission to PermissionState.

Expected mapping:

* .undetermined → .undetermined
* .granted → .granted
* .denied → .denied

Represent unavailable or system-restricted conditions as .restricted where appropriate.

Test Checkpoint

Add unit tests for:

* All four classification ranges.
* Exact threshold boundaries: 40, 70, and 85.
* Values below zero.
* Values above the display range.
* Permission-state mapping.
* Display names for all classifications.

⸻

Phase 2: Audio-Level Processing

Goals

Implement pure, testable numeric processing that converts audio samples into a stable approximate displayed level.

This phase must not depend on SwiftUI, @Published, or AVAudioEngine lifecycle management.

AudioLevelProcessor

Recommended responsibilities:

* Calculate RMS from audio samples.
* Convert RMS to dBFS-style values.
* Apply a centralized display offset.
* Clamp the result.
* Reject invalid values.
* Optionally apply smoothing through a separate type.

Recommended constants:

struct AudioLevelProcessor: Sendable {
    let displayOffset: Double
    let lowerBound: Double
    let upperBound: Double
    let epsilon: Float
    init(
        displayOffset: Double = 100,
        lowerBound: Double = 0,
        upperBound: Double = 120,
        epsilon: Float = 0.000_001
    ) {
        self.displayOffset = displayOffset
        self.lowerBound = lowerBound
        self.upperBound = upperBound
        self.epsilon = epsilon
    }
}

RMS Calculation

For a sequence of samples:

rms = sqrt(sum(sample²) / sampleCount)

Ignore:

* Empty sample collections
* Missing channel data
* Non-finite samples
* Invalid buffer formats

Use a small positive floor before applying the logarithm.

dBFS Conversion

dbFS = 20 * log10(max(rms, epsilon))
displayedDecibels = dbFS + displayOffset
displayedDecibels = clamp(displayedDecibels, 0, 120)

Document that:

* The offset is not calibration.
* The result is device-dependent.
* The result is an approximate relative indicator.
* The value must not be presented as laboratory-grade SPL.

LevelSmoother

Use a separate type for smoothing.

An exponential moving average is suitable:

smoothed = alpha × newValue + (1 - alpha) × previousValue

Recommended initial behavior:

* One raw measurement per audio buffer.
* Smooth the values before UI delivery.
* Deliver approximately 10–20 updates per second.
* Keep the response fast enough for obvious environmental changes to appear quickly.

Possible implementation:

struct LevelSmoother: Sendable {
    let alpha: Double
    private(set) var value: Double?
    mutating func reset() {
        value = nil
    }
    mutating func update(_ newValue: Double) -> Double {
        guard let previousValue = value else {
            value = newValue
            return newValue
        }
        let smoothedValue = alpha * newValue + (1 - alpha) * previousValue
        value = smoothedValue
        return smoothedValue
    }
}

The exact smoothing strategy may differ, but it must be deterministic and testable.

Test Checkpoint

Add unit tests for:

* RMS calculation.
* Silence or near-silence handling.
* Known sample values.
* dBFS conversion.
* Display offset application.
* Lower and upper clamping.
* NaN and infinity rejection.
* Empty input rejection.
* Smoothing reset behavior.
* Smoothing response to changing values.

⸻

Phase 3: Microphone Permission Service

Goals

Encapsulate microphone permission reads and asynchronous requests.

MicrophonePermissionProvider

Recommended responsibilities:

* Read current microphone permission.
* Request permission asynchronously.
* Return the resulting PermissionState.
* Avoid exposing AVFoundation details to the view model where possible.

Recommended interface:

protocol MicrophonePermissionProviding: Sendable {
    func currentPermission() -> PermissionState
    func requestPermission() async -> PermissionState
}

The concrete implementation may use AVAudioSession.sharedInstance().recordPermission.

Wrap the callback-based permission API with a checked continuation or equivalent safe adapter.

Requirements:

* Resume exactly once.
* Do not block the main thread.
* Re-read permission after the request completes.
* Do not assume that requesting permission grants access.

Permission Flow

The view model should:

1. Refresh permission before every start attempt.
2. Request permission only when the state is .undetermined.
3. Re-read permission after the request completes.
4. Stop the start flow if permission is denied or restricted.
5. Avoid repeatedly triggering the system prompt after denial.

Test Checkpoint

Verify:

* First launch shows the standard iOS permission prompt.
* Granting permission produces .granted.
* Denying permission produces .denied.
* A later start attempt does not repeatedly show the prompt after denial.
* Permission state can be refreshed after returning from Settings.

Where possible, use a protocol-backed fake provider for unit tests.

⸻

Phase 4: Serialized Audio Monitor

Goals

Implement microphone input using AVAudioSession and AVAudioEngine, while keeping audio lifecycle operations serialized and preventing raw audio from escaping the processing scope.

Recommended Isolation Strategy

Use a dedicated actor:

actor AudioMonitorActor {
    // AVAudioSession and AVAudioEngine lifecycle
}

All of the following must be serialized through this actor:

* Audio-session configuration
* Session activation
* Input-route validation
* Engine creation
* Tap installation
* Tap removal
* Engine start
* Engine stop
* Session deactivation
* Interruption cleanup
* Route-change cleanup

Do not access the same AVAudioEngine instance concurrently from multiple isolation domains.

AudioLevelMonitor

Use a service boundary that exposes only numeric measurements and lifecycle results.

Possible interface:

protocol AudioLevelMonitoring: Sendable {
    func start() async throws -> AsyncStream<Double>
    func stop() async
}

An alternative design may return a stream from a long-lived monitor object, but the stream must be finished or cancelled when monitoring stops.

Recommended error type:

enum AudioMonitorError: LocalizedError, Sendable {
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

Do not expose raw system errors directly to the user.

Audio Session Configuration

Use an appropriate configuration such as:

try audioSession.setCategory(.record, mode: .measurement)
try audioSession.setActive(true)

Use .playAndRecord only if required by the implementation.

After activation:

* Verify that an input route exists.
* Verify that the input node has a usable format.
* Fail cleanly if no input is available.

Tap Installation

Before installing a tap:

1. Remove any existing tap safely.
2. Install exactly one tap on the input node.
3. Process each buffer immediately.
4. Retain only the resulting numeric measurement.
5. Do not store the buffer.
6. Do not perform await inside the tap callback.
7. Do not update SwiftUI state from the tap callback.

The tap callback should:

1. Read channel data.
2. Calculate RMS.
3. Convert to a numeric level.
4. Apply smoothing or pass the value to a bounded processing path.
5. Forward only the numeric result.
6. Return immediately.

Update Cadence

The UI does not need one update per audio frame.

Use one of the following:

* Aggregate measurements in the audio service.
* Throttle numeric delivery.
* Use a bounded AsyncStream.
* Deliver approximately 10–20 updates per second.

Avoid unbounded buffering.

Start Flow

The monitor’s start operation should:

1. Configure the audio session.
2. Activate the session.
3. Validate input availability.
4. Create or configure the engine.
5. Remove any existing tap.
6. Install one tap.
7. Start the engine.
8. Return a measurement stream or equivalent numeric delivery mechanism.

If any step fails:

* Remove the tap.
* Stop the engine if necessary.
* Deactivate the session if this attempt activated it.
* Finish or cancel the measurement stream.
* Leave the monitor ready for a later retry.
* Throw a concise service error.

Stop Flow

The monitor’s stop operation should:

1. Mark monitoring inactive.
2. Finish or cancel measurement delivery.
3. Remove the tap.
4. Stop the engine.
5. Deactivate the audio session using an appropriate option.
6. Release continuations and buffer references.
7. Remain safe if called repeatedly.

Cleanup must be idempotent.

Test Checkpoint

On a physical iPhone, verify:

* The audio session activates successfully.
* A usable input route is detected.
* The engine starts.
* Exactly one tap is installed.
* Numeric measurements are produced.
* No raw audio is retained.
* Stop removes the tap and stops the engine.
* Repeated start/stop cycles do not crash.
* Failed starts clean up correctly.

⸻

Phase 5: View Model and Session State

Goals

Create the single owner of user-visible monitoring state.

NoiseSignalViewModel

The view model must be isolated to the main actor:

@MainActor
final class NoiseSignalViewModel: ObservableObject {
    @Published private(set) var isListening = false
    @Published private(set) var isTransitioning = false
    @Published private(set) var currentDecibels: Double = 0
    @Published private(set) var peakDecibels: Double = 0
    @Published private(set) var classification: NoiseClassification = .quiet
    @Published private(set) var microphonePermission: PermissionState = .undetermined
    @Published private(set) var errorMessage: String?
}

Additional internal state may include:

* Measurement task
* Session identifier or generation token
* Whether a valid measurement has arrived
* Current input availability
* Threshold configuration
* Audio monitor reference

The audio service must not mutate these properties directly.

Initialization

On initialization:

1. Read the current microphone permission.
2. Set the initial permission state.
3. Prepare dependencies.
4. Register lifecycle observation.
5. Do not start microphone monitoring automatically.

Start Method

Recommended signature:

func startListening() async

Required behavior:

1. Ignore the request if isTransitioning is already true.
2. Ignore the request if already listening.
3. Set isTransitioning = true.
4. Clear stale error state if appropriate.
5. Refresh permission.
6. Request permission if undetermined.
7. Re-read permission.
8. Stop with an actionable message if denied or restricted.
9. Reset session-specific peak state before monitoring begins.
10. Start the audio monitor.
11. Begin consuming numeric measurements.
12. Set isListening = true only after successful monitor startup.
13. Reset isTransitioning using guaranteed cleanup.

Use defer or equivalent cleanup to ensure transition state is always reset.

Stop Method

Recommended signature:

func stopListening() async

Required behavior:

1. Ignore the request if isTransitioning is already true.
2. Set isTransitioning = true.
3. Invalidate the current measurement task or session generation.
4. Stop the audio monitor.
5. Set isListening = false.
6. Preserve current, peak, and classification values.
7. Reset isTransitioning in guaranteed cleanup.

Measurement Consumption

The view model should consume numeric values from the monitor.

For each valid value:

1. Confirm the session is still active.
2. Confirm the value is finite.
3. Set currentDecibels.
4. Update peakDecibels.
5. Recalculate classification.
6. Keep all published-state mutations on the main actor.

Use the same processed value for classification and peak tracking unless the implementation explicitly documents a different choice.

Session Reset

At the beginning of every successful listening session:

* Reset the peak.
* Do not carry the previous session’s peak forward.
* Preserve stopped-session values until the first new valid measurement if desired.
* Ensure the new session’s peak is initialized from the first valid measurement or a defined baseline.

A session identifier or generation token is recommended to prevent stale measurement tasks from updating state after stop.

Deinitialization

When the view model is deallocated:

* Cancel the measurement task.
* Cancel lifecycle observation.
* Stop the monitor.
* Release stream continuations through the monitor.
* Ensure no later measurement can mutate state.

Test Checkpoint

Using mocked permission and audio-monitor services, verify:

* Start and stop operations are serialized.
* Duplicate start requests are ignored.
* Duplicate stop requests are safe.
* Failed starts leave isListening == false.
* isTransitioning always returns to false.
* Peak resets between sessions.
* Stale measurements cannot update state after stop.
* Classification updates from valid measurements.
* Invalid measurements are ignored.
* Final values remain visible after stop.

⸻

Phase 6: App Lifecycle, Interruptions, and Route Changes

Goals

Handle system events safely without automatically restarting monitoring.

AppLifecycleObserver

Observe:

* App becoming active
* App entering background
* App becoming inactive
* Audio-session interruptions
* Audio-session route changes

Observation may be implemented with NotificationCenter and bridged into Swift concurrency, but callbacks must not mutate SwiftUI state outside the main actor.

Interruption Handling

When an interruption begins:

1. Mark monitoring inactive.
2. Invalidate measurement delivery.
3. Remove the tap.
4. Stop the engine.
5. Deactivate the session if appropriate.
6. Set isListening = false.
7. Preserve current and peak values.
8. Show “Listening was interrupted.”

When an interruption ends:

* Do not automatically restart.
* Leave the app stopped.
* Allow the user to tap LISTEN again.
* Refresh permission and input availability before restarting.

Route Changes

Handle:

* Old device unavailable
* New device available
* Category changes
* Input route changes that invalidate the current input

If input becomes unavailable:

1. Stop monitoring safely.
2. Remove the tap.
3. Stop the engine.
4. Set isListening = false.
5. Preserve the last valid values.
6. Show “Microphone unavailable.”
7. Do not report stale values as live.

If a new input becomes available:

* Do not automatically restart.
* Allow the user to retry.

App Backgrounding

When the app becomes inactive or enters the background:

* Stop monitoring or mark it inactive according to observed iOS behavior.
* Preserve final values.
* Do not automatically restart on foreground.
* Refresh permission and route availability when the app becomes active again.

Foreground Refresh

When the app returns to the foreground:

1. Refresh microphone permission.
2. Refresh input availability.
3. Update user-facing state if permission changed.
4. Do not start monitoring automatically.

Test Checkpoint

Verify on a physical device:

* Incoming phone call or system interruption stops monitoring safely.
* Monitoring does not automatically restart.
* Removing or disconnecting an input route is handled safely.
* Returning to the foreground refreshes permission.
* Backgrounding does not leave the UI falsely showing active monitoring.
* Repeated lifecycle events do not crash or install duplicate taps.

⸻

Phase 7: SwiftUI Interface

Goals

Build the minimal black, high-contrast interface around the view model.

NoiseSignalApp

Responsibilities:

* Application entry point.
* Create the shared view model once for the active scene.
* Inject it into ContentView.

Recommended ownership:

@main
struct NoiseSignalApp: App {
    @StateObject private var viewModel = NoiseSignalViewModel()
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
        }
    }
}

Use the ownership model appropriate to the selected SwiftUI and Observation APIs, but ensure the view model is not recreated during view updates.

ContentView

Responsibilities:

* Apply the black background.
* Respect safe-area layout.
* Display the title.
* Display classification.
* Display current and peak values.
* Display permission and error messaging.
* Display the primary action.
* Observe app lifecycle if needed.
* Trigger asynchronous start and stop actions.

Recommended hierarchy:

1. App title
2. Large classification
3. Current level
4. Peak level
5. Primary action
6. Permission or error message

Avoid navigation unless required.

SignalStatusView

Displays:

* Current classification as the dominant text.
* Optional live-state styling.
* A neutral or loading state before the first valid measurement.

Possible inputs:

struct SignalStatusView: View {
    let classification: NoiseClassification
    let isListening: Bool
    let hasMeasurement: Bool
}

Do not display an invalid numeric value while waiting for the first measurement.

LevelReadoutView

Displays:

* Current level, such as 72 dB.
* Peak level, such as Peak 79 dB.

Use a centralized formatter:

enum LevelFormatter {
    static func string(for value: Double) -> String {
        "\(Int(value.rounded())) dB"
    }
}

Only format finite values.

ListenButton

Displays:

* LISTEN when idle or stopped.
* STOP while monitoring.

Requirements:

* Calls the view model’s asynchronous start or stop method.
* Disables itself while isTransitioning is true.
* Prevents overlapping operations.
* Uses a large, accessible hit target.
* Does not expose recording controls.

PermissionMessageView

Displays:

* A concise explanation for denied or restricted access.
* A Settings action when permission is denied.
* No Settings action for undetermined permission.
* No raw system errors.

Use:

UIApplication.shared.open(
    URL(string: UIApplication.openSettingsURLString)!
)

Keep this interaction isolated from the view model where practical.

Visual Style

Use:

* Black or near-black background.
* High-contrast white or light typography.
* Large classification text.
* Minimal spacing and controls.
* Restrained animation only while listening.
* Clear disabled state during transitions.

Avoid:

* Graphs
* Decorative complexity
* Onboarding
* Settings pages
* Accounts
* Advertisements
* Unnecessary navigation

Required UI States

Idle

* Title: Noise Signal
* Neutral classification or QUIET
* Current and peak values hidden or shown as placeholders
* Button: LISTEN
* No denied-state message before the system permission request

Listening

* Large live classification
* Current dB value
* Peak dB value
* Button: STOP
* Optional restrained live animation
* Loading or measuring state before the first valid value

Stopped

* Final current value
* Final peak value
* Final classification
* Button: LISTEN
* Interruption or unavailable-input message when applicable

Permission Denied or Restricted

* Main layout remains intact
* Concise explanation
* Settings action for denied permission
* No repeated permission prompt

Error

* Main layout remains intact
* Concise actionable message
* Retry remains available when safe
* Raw implementation errors remain hidden

Test Checkpoint

Verify:

* The interface is readable in dark mode.
* The classification is visually dominant.
* The button changes between LISTEN and STOP.
* The button disables during transitions.
* Permission messaging is concise and correct.
* Settings opens only for denied permission.
* Loading state appears before the first valid measurement.
* Final values remain visible after stopping.
* VoiceOver labels and button actions are understandable.
* Dynamic Type does not make the primary layout unusable.

⸻

Phase 8: Integration and Physical-Device Validation

Goals

Connect all layers and validate the complete listening experience on a physical iPhone.

Integration Sequence

Implement and verify in this order:

1. Launch the app into the idle UI.
2. Read and display permission state.
3. Request permission through LISTEN.
4. Configure and activate the audio session.
5. Validate microphone input.
6. Start AVAudioEngine.
7. Install one input tap.
8. Process numeric levels.
9. Deliver bounded updates.
10. Update the view model.
11. Update classification and peak.
12. Stop and clean up.
13. Handle interruptions and route changes.
14. Refresh state on foreground return.

Physical-Device Test Matrix

Test at minimum:

Permission

* First launch with undetermined permission.
* Grant permission.
* Deny permission.
* Disable permission in Settings.
* Return from Settings.
* Restricted or unavailable microphone condition where testable.

Audio

* Quiet room.
* Normal conversation or ambient room noise.
* Clearly louder environment.
* Short loud event.
* No usable input route.
* External microphone connection or disconnection if available.

Session Lifecycle

* Start once.
* Stop once.
* Start and stop repeatedly.
* Tap LISTEN repeatedly during startup.
* Tap STOP repeatedly during shutdown.
* Stop after a failed start.
* Background while listening.
* Return to foreground.
* Trigger an audio interruption.
* Trigger a route change.

Data Integrity

* No audio files are created.
* No audio buffers are stored in properties or collections.
* No audio is uploaded.
* No audio is logged.
* No speech recognition occurs.
* No stale measurement updates after stop.

Test Checkpoint

The integration phase is complete when:

* The app builds and runs on a physical iPhone.
* The live level visibly responds to environmental changes.
* Classification changes at the configured thresholds.
* Peak tracking works.
* Peak resets between sessions.
* Stop preserves final values.
* Repeated start/stop cycles remain stable.
* Interruption and route-change handling are safe.
* No raw audio is retained.

⸻

Phase 9: Acceptance and Evidence

Acceptance Criteria

The implementation is complete when all of the following are true:

1. The project builds successfully in Xcode.
2. The app launches into a clear idle state.
3. The app requests microphone permission using the standard iOS flow.
4. The app handles granted, denied, restricted, and undetermined permission states.
5. Permission state is refreshed after returning from Settings or the background.
6. Tapping LISTEN configures and activates the audio session.
7. Tapping LISTEN starts microphone level monitoring through AVAudioEngine.
8. The audio-level conversion is implemented with documented RMS or average-power input, dBFS conversion, offset, clamping, and smoothing.
9. The displayed value never shows NaN, negative infinity, or another invalid live value.
10. The current dB value updates visibly while monitoring.
11. The displayed value responds when the environment becomes louder or quieter.
12. The classification updates according to the centralized thresholds.
13. Peak dB resets at the start of each listening session.
14. Peak dB reflects the highest valid processed level measured during that session.
15. Tapping STOP removes the audio tap, stops the engine, cancels measurement delivery, and deactivates the audio session appropriately.
16. Final current, peak, and classification values remain visible after STOP.
17. Repeated start/stop cycles do not crash, race, or install duplicate taps.
18. Start and stop operations are serialized and cannot overlap.
19. All UI state mutations occur on the main actor.
20. Audio callbacks do not block on the main actor or perform asynchronous work directly in the real-time tap callback.
21. Audio interruptions are handled safely and do not automatically restart monitoring.
22. Microphone route changes and unavailable input are handled safely.
23. Returning to the foreground refreshes permission and input availability.
24. No audio recording is saved, uploaded, logged, or retained after monitoring stops.
25. The interface is predominantly black, readable, minimal, and immediately understandable.
26. The app runs successfully on a physical iPhone.

Evidence Required

Document evidence for:

* Successful Xcode build.
* First-launch microphone permission prompt.
* Granted, denied, undetermined, and restricted/unavailable permission behavior.
* Idle screen.
* Active listening screen.
* Stopped screen.
* Audio-level conversion and smoothing implementation.
* Live level changes in response to environmental noise.
* Classification changes across threshold ranges.
* Peak tracking during a session.
* Peak reset between sessions.
* STOP behavior and preserved final values.
* Safe repeated start/stop behavior.
* Audio interruption handling.
* Microphone route-change or unavailable-input handling.
* Foreground return and permission refresh.
* Confirmation that no audio files, recordings, or retained audio buffers are created.
* Confirmation that published state changes occur on the main actor.
* Known limitations of approximate, device-dependent, non-calibrated dB values.

Recommended Evidence Format

For each checkpoint, record:

Checkpoint:
Device and iOS version:
Steps:
Expected result:
Observed result:
Pass/fail:
Notes:

For audio-level behavior, include:

* Quiet-room reading.
* Normal-room reading.
* Louder-environment reading.
* Peak value during a short loud event.
* Classification at each threshold range.

For privacy validation, confirm:

* No recording files in the app sandbox.
* No audio data in logs.
* No network requests containing microphone data.
* No retained AVAudioPCMBuffer references after processing.

⸻

Stop Condition

Stop once the core listening experience is reliable and meets the acceptance criteria.

Do not implement:

* History
* Charts
* Calibration
* Settings
* Background listening
* Health guidance
* Accounts
* Backend services
* Additional product features

The implementation should end with a stable, minimal, privacy-preserving SwiftUI app that measures relative ambient sound level, presents a clear classification, tracks the current session’s peak, and safely starts and stops microphone monitoring.

That gives Claude just enough freedom to solve the microphone mechanics without letting it turn Noise Signal into a 14-screen product. The next intent should probably be history + session evidence, once this one proves the sensor loop works.