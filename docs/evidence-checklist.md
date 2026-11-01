# Intent 001 — Physical-Device Evidence

Unit tests cover the pure logic and view-model state machine (⌘U). Everything below needs a real iPhone.
Record each row as: **Device / iOS · Steps · Expected · Observed · Pass/Fail · Notes**.

Device: ______________________  iOS: ________  Build: ________  Date: ________

## Permission
| # | Check | Expected | Pass |
|---|---|---|---|
| P1 | Fresh install → tap LISTEN | Standard iOS prompt with the "does not record or save audio" text | ☐ |
| P2 | Allow | Starts listening, shows MEASURING then a level | ☐ |
| P3 | Reinstall → Don't Allow | "Microphone access is off…" + Open Settings; no repeat prompt on further taps | ☐ |
| P4 | Settings → enable mic → return | Message clears; LISTEN works | ☐ |
| P5 | Disable mic in Settings while app is backgrounded | iOS relaunches app; denied state shown | ☐ |

## Audio level
| # | Check | Reading | Classification | Pass |
|---|---|---|---|---|
| A1 | Quiet room | ___ dB | | ☐ |
| A2 | Normal conversation | ___ dB | | ☐ |
| A3 | Loud (music/vacuum) | ___ dB | | ☐ |
| A4 | Short loud event (clap) | Peak ___ dB | | ☐ |
| A5 | Level visibly rises/falls within ~½ s of change | | | ☐ |
| A6 | Never shows NaN, −∞, or negative values | | | ☐ |

## Session lifecycle
| # | Check | Expected | Pass |
|---|---|---|---|
| L1 | LISTEN → STOP | Final current, peak, classification remain on screen | ☐ |
| L2 | LISTEN again | Peak resets (new session's first value) | ☐ |
| L3 | 20× LISTEN/STOP quickly | No crash, button disables during transitions | ☐ |
| L4 | Mash LISTEN during startup | One session only | ☐ |
| L5 | Background while listening → return | Stopped, "Listening stopped when the app left the screen.", no auto-restart | ☐ |
| L6 | Incoming call / Siri while listening | Stopped, "Listening was interrupted.", no auto-restart after | ☐ |
| L7 | Plug/unplug wired or Bluetooth mic while listening | Safe stop with message, or continues on built-in mic; never stale "LIVE" | ☐ |

## History & Settings
| # | Check | Expected | Pass |
|---|---|---|---|
| H1 | LISTEN, make noise, STOP | One-line summary under the button; History has one new row at the top | ☐ |
| H2 | LISTEN then background the app | Session is saved once, with the background message | ☐ |
| H3 | Force quit and reopen | History is still there; monitoring has not started | ☐ |
| H4 | Set TOO LOUD level to 75, reading between 75 and 84 | Reading shows TOO LOUD; older History rows unchanged | ☐ |
| H5 | Keep Screen Awake on, listen past auto-lock time | Screen stays on; after STOP it can lock normally | ☐ |
| H6 | Keep Screen Awake off, listen past auto-lock time | Phone locks; session stops and is saved | ☐ |
| H7 | Clear History, confirm | History is empty, summary is gone | ☐ |

## Privacy
| # | Check | Expected | Pass |
|---|---|---|---|
| X1 | Xcode → Devices → Download Container | No audio files in Documents/Library/tmp | ☐ |
| X2 | Console while listening | No audio data logged | ☐ |
| X3 | Network (Instruments / Settings › Privacy › App Privacy Report) | No network activity | ☐ |
| X4 | Memory graph after STOP | No `AVAudioPCMBuffer` / `AVAudioEngine` retained | ☐ |
| X5 | Main thread checker (on by default in Debug) | No warnings | ☐ |

## Known limitations
- Levels are dBFS + a fixed 100 dB offset — relative, device-dependent, **not** calibrated SPL.
- Peak tracks the smoothed, throttled (~15 Hz) value, so very short transients read lower than a true peak meter.
