# Security & Privacy

- Microphone samples are read inside the AVAudioEngine tap callback, reduced to one RMS number, and discarded. No `AVAudioPCMBuffer` is stored in a property or collection.
- No `AVAudioRecorder`, no audio file writes, no `print`/`os_log` of audio data, no networking code, no speech recognition.
- `NSMicrophoneUsageDescription`: "Noise Signal uses the microphone to estimate ambient sound level. It does not record or save audio."
- Permission is requested only when undetermined; after denial the app points to Settings and never re-prompts.
- The only persisted data is settings and session summaries (date, duration, peak, classification) in `UserDefaults`, on this device. Clear History in Settings removes the summaries.
