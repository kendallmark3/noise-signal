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

---

# Delta — Intent 002: Session History + Simple Settings

## Observation
Intent 001 runs on the iPhone. STOP ends the session, and its result is lost at the next LISTEN.

## Keep
Black, high-contrast, one primary control. Live readout, audio pipeline, and stop behaviour are unchanged. Nothing restarts automatically.

## Change
- **Outcome:** when a session ends (STOP or a system stop), it is saved and a one-line summary appears under the button; tapping it, or the clock icon, opens History, newest first: date, duration, peak, classification at peak.
- **Settings (gear icon), three items only:** TOO LOUD level (75–100 dB in 5 dB steps, default 85), Keep Screen Awake while listening (default on), Clear History (with confirmation).

## New Boundary
- History stores numbers only, on this device (date, duration, peak, classification). Never audio.
- Latest 100 sessions. A session with no valid measurement is not saved.
- Past sessions keep the classification they were saved with, even if the TOO LOUD level changes later.
- Stop condition: no charts, export, sharing, per-session delete, calibration, background listening, notifications, or health guidance.

## Success / Evidence
- Unit tested with fakes: saved once per session on STOP and system stops; none without a measurement; newest first; cap at 100; survives relaunch; clear empties it; corrupt stored data falls back safely.
- Unit tested: threshold is clamped to its range, persists, and reclassifies the visible reading; screen stays awake only while listening with the setting on.
- Device checklist: docs/evidence-checklist.md, section "History & Settings".
