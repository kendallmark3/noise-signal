import XCTest
@testable import NoiseSignal

final class AudioLevelProcessorTests: XCTestCase {
    private let processor = AudioLevelProcessor()

    func testRMSKnownValues() throws {
        XCTAssertEqual(try XCTUnwrap(processor.rms(of: [0.5, -0.5, 0.5, -0.5])), 0.5, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(processor.rms(of: [1, 1, 1])), 1, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(processor.rms(of: [3, 4])), (12.5).squareRoot(), accuracy: 1e-9)
    }

    func testEmptyInputIsRejected() {
        XCTAssertNil(processor.rms(of: [Float]()))
        XCTAssertNil(processor.displayLevel(from: [Float]()))
    }

    func testNonFiniteSamplesAreIgnored() throws {
        XCTAssertEqual(try XCTUnwrap(processor.rms(of: [.nan, 0.5, -0.5, .infinity])), 0.5, accuracy: 1e-9)
        XCTAssertNil(processor.rms(of: [.nan, .infinity, -.infinity]))
    }

    func testSilenceUsesEpsilonFloorAndClampsToLowerBound() throws {
        // 20·log10(1e-6) = −120 dBFS; +100 offset = −20 → clamped to 0.
        XCTAssertEqual(try XCTUnwrap(processor.decibelsFullScale(fromRMS: 0)), -120, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(processor.displayLevel(from: [0, 0, 0, 0])), 0, accuracy: 1e-9)
    }

    func testDBFSConversion() throws {
        XCTAssertEqual(try XCTUnwrap(processor.decibelsFullScale(fromRMS: 1)), 0, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(processor.decibelsFullScale(fromRMS: 0.1)), -20, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(processor.decibelsFullScale(fromRMS: 0.01)), -40, accuracy: 1e-9)
    }

    func testDisplayOffsetIsApplied() throws {
        XCTAssertEqual(try XCTUnwrap(processor.displayLevel(fromRMS: 0.1)), 80, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(processor.displayLevel(fromRMS: 0.001)), 40, accuracy: 1e-9)
        let shifted = AudioLevelProcessor(displayOffset: 90)
        XCTAssertEqual(try XCTUnwrap(shifted.displayLevel(fromRMS: 0.1)), 70, accuracy: 1e-9)
    }

    func testUpperClamp() throws {
        let hot = AudioLevelProcessor(displayOffset: 130)
        XCTAssertEqual(try XCTUnwrap(hot.displayLevel(fromRMS: 1)), 120, accuracy: 1e-9)
    }

    func testInvalidRMSIsRejected() {
        XCTAssertNil(processor.displayLevel(fromRMS: .nan))
        XCTAssertNil(processor.displayLevel(fromRMS: .infinity))
        XCTAssertNil(processor.displayLevel(fromRMS: -1))
    }

    func testFullPipelineNeverProducesInvalidValues() {
        let inputs: [[Float]] = [[0], [1e-30], [1], [-1, 1], [.nan, 0.2], [.greatestFiniteMagnitude]]
        for samples in inputs {
            if let level = processor.displayLevel(from: samples) {
                XCTAssertTrue(level.isFinite, "\(samples)")
                XCTAssertTrue((0...120).contains(level), "\(samples) → \(level)")
            }
        }
    }
}
