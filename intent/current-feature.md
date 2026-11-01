# Current Feature — Intent 001: Live Noise Signal

<!-- Full phased plan: docs/intent-001-plan.md. After the first build, append deltas below (templates/delta-template.md). -->

## Outcome
On a physical iPhone, tapping LISTEN shows a live approximate dB level, a dominant QUIET / NORMAL / LOUD / TOO LOUD classification, and the session's peak; tapping STOP ends monitoring and keeps the final values on screen.

## Inputs
- Ambient microphone input (numeric level only).
- Microphone permission state.

## Outputs
- Current level (e.g. `72 dB`), session peak (`Peak 79 dB`), classification.
- Concise permission / interruption / unavailable-input messages.

## Success / Evidence
- Classification follows centralized thresholds: QUIET < 40, NORMAL 40–69, LOUD 70–84, TOO LOUD ≥ 85 (unit tested, boundaries included).
- RMS → dBFS → +100 display offset → clamp 0…120 → EMA smoothing; never shows NaN/−∞ (unit tested).
- Peak resets every session; stale measurements cannot update state after STOP (unit tested with fakes).
- Repeated LISTEN/STOP, interruptions, route changes, and backgrounding never crash, overlap, or auto-restart (device checklist: docs/evidence-checklist.md).
- No audio file, buffer, log, or upload exists after monitoring (device checklist).

## Constraints / Boundaries
- Relative indicator only; the offset is not calibration and values are device-dependent.
- Stop condition: no history, charts, calibration, settings, background listening, or health guidance in this intent.
