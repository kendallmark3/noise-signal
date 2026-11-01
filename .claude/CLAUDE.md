# Repository Rules
Read intent/current-feature.md first, including any deltas appended to it. Full phased plan: docs/intent-001-plan.md.
Run hooks/pre-implement.sh before implementing.
Build the smallest useful delta, then let the human observe it and decide: continue or stop.
Always write tests (NoiseSignalTests/, XCTest, fakes for permission and audio).
Respect architecture (context/architecture.md) and privacy (context/security.md): numbers only leave the audio tap; never record, store, log, or upload audio.
Stop condition for Intent 001: no history, charts, calibration, settings, background listening, or health guidance.
