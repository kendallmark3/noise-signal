import AVFAudio
import XCTest
@testable import NoiseSignal

final class NoiseClassificationTests: XCTestCase {
    private let thresholds = NoiseThresholds()

    func testAllFourRanges() {
        XCTAssertEqual(thresholds.classification(for: 20), .quiet)
        XCTAssertEqual(thresholds.classification(for: 55), .normal)
        XCTAssertEqual(thresholds.classification(for: 77), .loud)
        XCTAssertEqual(thresholds.classification(for: 100), .tooLoud)
    }

    func testExactBoundaries() {
        XCTAssertEqual(thresholds.classification(for: 39.999), .quiet)
        XCTAssertEqual(thresholds.classification(for: 40), .normal)
        XCTAssertEqual(thresholds.classification(for: 69.999), .normal)
        XCTAssertEqual(thresholds.classification(for: 70), .loud)
        XCTAssertEqual(thresholds.classification(for: 84.999), .loud)
        XCTAssertEqual(thresholds.classification(for: 85), .tooLoud)
    }

    func testValuesBelowZeroAreQuiet() {
        XCTAssertEqual(thresholds.classification(for: -10), .quiet)
        XCTAssertEqual(thresholds.classification(for: -.infinity), .quiet)
    }

    func testValuesAboveDisplayRangeAreTooLoud() {
        XCTAssertEqual(thresholds.classification(for: 120), .tooLoud)
        XCTAssertEqual(thresholds.classification(for: 500), .tooLoud)
    }

    func testCustomThresholds() {
        let custom = NoiseThresholds(quietUpperBound: 10, normalUpperBound: 20, loudUpperBound: 30)
        XCTAssertEqual(custom.classification(for: 15), .normal)
        XCTAssertEqual(custom.classification(for: 30), .tooLoud)
    }

    func testDisplayNames() {
        XCTAssertEqual(NoiseClassification.quiet.displayName, "QUIET")
        XCTAssertEqual(NoiseClassification.normal.displayName, "NORMAL")
        XCTAssertEqual(NoiseClassification.loud.displayName, "LOUD")
        XCTAssertEqual(NoiseClassification.tooLoud.displayName, "TOO LOUD")
        XCTAssertEqual(NoiseClassification.allCases.count, 4)
    }

    func testPermissionMapping() {
        XCTAssertEqual(PermissionState(AVAudioApplication.recordPermission.undetermined), .undetermined)
        XCTAssertEqual(PermissionState(AVAudioApplication.recordPermission.granted), .granted)
        XCTAssertEqual(PermissionState(AVAudioApplication.recordPermission.denied), .denied)
    }

    func testFormatter() {
        XCTAssertEqual(LevelFormatter.string(for: 72.4), "72 dB")
        XCTAssertEqual(LevelFormatter.string(for: 72.5), "73 dB")
        XCTAssertEqual(LevelFormatter.peakString(for: 79), "Peak 79 dB")
        XCTAssertEqual(LevelFormatter.string(for: .nan), LevelFormatter.placeholder)
        XCTAssertEqual(LevelFormatter.string(for: -.infinity), LevelFormatter.placeholder)
    }
}
