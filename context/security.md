# Security & Privacy

- Microphone samples are read inside the AVAudioEngine tap callback, reduced to one RMS number, and discarded. No `AVAudioPCMBuffer` is stored in a property or collection.
- No `AVAudioRecorder`, no file writes, no `print`/`os_log` of audio data, no networking code, no speech recognition.
- `NSMicrophoneUsageDescription`: "Noise Signal uses the microphone to estimate ambient sound level. It does not record or save audio."
- Permission is requested only when undetermined; after denial the app points to Settings and never re-prompts.
