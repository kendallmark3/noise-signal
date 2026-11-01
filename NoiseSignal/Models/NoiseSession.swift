import Foundation

/// Summary of one finished listening session. Numbers only — never audio.
struct NoiseSession: Identifiable, Codable, Equatable, Sendable {
    static let maxStored = 100

    var id = UUID()
    let startedAt: Date
    let duration: TimeInterval
    let peakDecibels: Double
    /// Saved as classified at the time, so past sessions don't change with later settings.
    let classification: NoiseClassification
}
