# Noise Signal

A minimal, black, high-contrast iPhone app that tells you how loud the room is: **QUIET · NORMAL · LOUD · TOO LOUD**, a live approximate dB level, and the session peak. One button. Nothing recorded.

Built with Intent-Driven Engineering from [intent-drive-starter](https://github.com/kendallmark3/intent-drive-starter). Intent: [`intent/current-feature.md`](intent/current-feature.md) · full phased plan: [`docs/intent-001-plan.md`](docs/intent-001-plan.md).

> Relative indicator, not a calibrated sound meter. Values are dBFS + a fixed offset and vary by device.

## Run it on your iPhone

1. Open `NoiseSignal.xcodeproj` in Xcode 16 or later.
2. Select the **NoiseSignal** target → *Signing & Capabilities* → pick your Team. (Change the bundle ID if `org.learnteachmaster.NoiseSignal` is taken on your account.)
3. Plug in your iPhone (iOS 17+), choose it as the run destination, press **⌘R**.
4. Tap **LISTEN**, allow the microphone, make some noise.

Run the unit tests with **⌘U** (simulator is fine — they use fakes, no microphone needed).
Then work through [`docs/evidence-checklist.md`](docs/evidence-checklist.md) on the device.

If the project ever refuses to open: `brew install xcodegen && xcodegen` regenerates it from `project.yml`.

## How it works

```
LISTEN ─► NoiseSignalViewModel (@MainActor) ─► AudioMonitorActor (actor)
                ▲                                   │ AVAudioSession(.record, .measurement)
                │ AsyncStream<Double>, newest-1     │ AVAudioEngine input tap
                └──────── ~15 Hz ◄── TapProcessor ◄─┘ RMS → dBFS → +100 → clamp 0…120 → EMA
```

| Folder | What lives there |
|---|---|
| `NoiseSignal/Models` | `NoiseClassification`, `NoiseThresholds` (40 / 70 / 85), `PermissionState` |
| `NoiseSignal/Processing` | `AudioLevelProcessor` (RMS, dBFS, offset, clamp), `LevelSmoother` (EMA), `LevelFormatter` |
| `NoiseSignal/Services` | `AudioMonitorActor` (serialized engine lifecycle), `TapProcessor`, permission provider, lifecycle observer |
| `NoiseSignal/ViewModels` | `NoiseSignalViewModel` — single owner of UI state, session-generation token |
| `NoiseSignal/Views` | Status, readout, LISTEN/STOP button, permission message |
| `NoiseSignalTests` | 40+ XCTest cases: thresholds, processing, smoothing, permission, lifecycle mapping, view-model state machine |

Design rules: start/stop are serialized; nothing restarts automatically after interruptions, route changes, or backgrounding; raw audio buffers never leave the tap callback.

## Next intent

Intent 002 — history + session evidence, once this one proves the sensor loop on device. Append observations as deltas to `intent/current-feature.md` (see `templates/delta-template.md`).

---
Intent-Driven Engineering · [learnteachmaster.org](https://learnteachmaster.org) · [intent-driven-engineering.com](https://intent-driven-engineering.com)
