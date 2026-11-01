# Architecture

Single-target SwiftUI iOS app (iOS 17+), plus an XCTest target. No services, APIs, databases, or network.

```
SwiftUI Views ──► NoiseSignalViewModel (@MainActor, single owner of UI state)
                     │  ▲ AsyncStream<Double> (bounded: newest 1)
                     ▼  │
                AudioMonitorActor (actor: AVAudioSession + AVAudioEngine lifecycle)
                     │
                     └─ tap callback → TapProcessor → AudioLevelProcessor (RMS→dB) → LevelSmoother → throttle ~15 Hz → yield Double

AppLifecycleObserver (NotificationCenter, main queue) ──► view model: background, interruptions, route changes
MicrophonePermissionProvider (AVAudioApplication) ──► view model
```

| Layer | Folder | Rule |
|---|---|---|
| Pure logic | `Models/`, `Processing/` | No SwiftUI, no AVFoundation lifecycle. Fully unit tested. |
| Services | `Services/` | Only numbers and lifecycle results cross the boundary. Raw buffers never leave the tap callback. |
| State | `ViewModels/` | All `@Published` mutations on the main actor. Session generation token rejects stale values. |
| UI | `Views/` | Black, high-contrast, one primary control. |

Key decisions
- Start/stop serialized twice: the view model's `isTransitioning` gate, and the actor's serial executor.
- The tap block is built in a `nonisolated static` function so it never inherits actor isolation on the real-time audio thread.
- Engine configuration changes are observed by the actor on its own engine; if the engine stopped, the stream finishes and the UI shows a retry message.
- Nothing restarts automatically — interruptions, route changes and backgrounding always leave the app stopped.
