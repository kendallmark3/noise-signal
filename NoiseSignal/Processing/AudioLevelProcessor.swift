import Foundation

/// Converts raw microphone samples into an approximate display level.
///
/// Pipeline: RMS → dBFS (`20 · log10(max(rms, ε))`) → `+ displayOffset` → clamp to `lowerBound...upperBound`.
///
/// Important: the display offset is **not calibration**. The result is device-dependent and is a
/// relative indicator only. It must never be presented as laboratory-grade SPL.
struct AudioLevelProcessor: Sendable {
    let displayOffset: Double
    let lowerBound: Double
    let upperBound: Double
    let epsilon: Double

    init(
        displayOffset: Double = 100,
        lowerBound: Double = 0,
        upperBound: Double = 120,
        epsilon: Double = 0.000_001
    ) {
        self.displayOffset = displayOffset
        self.lowerBound = lowerBound
        self.upperBound = upperBound
        self.epsilon = epsilon
    }

    /// Root mean square of the finite samples. Non-finite samples are ignored.
    /// Returns `nil` for empty input or input with no finite samples.
    func rms(of samples: UnsafeBufferPointer<Float>) -> Double? {
        var sumOfSquares: Double = 0
        var count = 0
        for sample in samples where sample.isFinite {
            let value = Double(sample)
            sumOfSquares += value * value
            count += 1
        }
        guard count > 0 else { return nil }
        let result = (sumOfSquares / Double(count)).squareRoot()
        return result.isFinite ? result : nil
    }

    func rms(of samples: [Float]) -> Double? {
        samples.withUnsafeBufferPointer { rms(of: $0) }
    }

    /// dBFS for an RMS value, floored at `epsilon` before the logarithm.
    func decibelsFullScale(fromRMS rms: Double) -> Double? {
        guard rms.isFinite, rms >= 0 else { return nil }
        return 20 * log10(max(rms, epsilon))
    }

    /// Display level for an RMS value: dBFS + offset, clamped. `nil` if invalid.
    func displayLevel(fromRMS rms: Double) -> Double? {
        guard let dbfs = decibelsFullScale(fromRMS: rms) else { return nil }
        let shifted = dbfs + displayOffset
        guard shifted.isFinite else { return nil }
        return min(max(shifted, lowerBound), upperBound)
    }

    /// Full pipeline for one buffer's worth of samples.
    func displayLevel(from samples: UnsafeBufferPointer<Float>) -> Double? {
        guard let value = rms(of: samples) else { return nil }
        return displayLevel(fromRMS: value)
    }

    func displayLevel(from samples: [Float]) -> Double? {
        samples.withUnsafeBufferPointer { displayLevel(from: $0) }
    }
}
