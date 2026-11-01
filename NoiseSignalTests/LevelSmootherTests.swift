import XCTest
@testable import NoiseSignal

final class LevelSmootherTests: XCTestCase {
    func testFirstValuePassesThrough() {
        var smoother = LevelSmoother(alpha: 0.5)
        XCTAssertEqual(smoother.update(60), 60)
        XCTAssertEqual(smoother.value, 60)
    }

    func testExponentialMovingAverage() throws {
        var smoother = LevelSmoother(alpha: 0.5)
        smoother.update(40)
        XCTAssertEqual(try XCTUnwrap(smoother.update(80)), 60, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(smoother.update(80)), 70, accuracy: 1e-9)
    }

    func testRespondsToChangingValues() throws {
        var smoother = LevelSmoother(alpha: 0.35)
        smoother.update(40)
        var last = 40.0
        for _ in 0..<10 {
            let next = try XCTUnwrap(smoother.update(90))
            XCTAssertGreaterThan(next, last)
            last = next
        }
        XCTAssertGreaterThan(last, 88, "10 updates (~0.7 s at 15 Hz) should approach the new level")
    }

    func testReset() {
        var smoother = LevelSmoother(alpha: 0.5)
        smoother.update(40)
        smoother.reset()
        XCTAssertNil(smoother.value)
        XCTAssertEqual(smoother.update(90), 90)
    }

    func testNonFiniteInputIsIgnored() {
        var smoother = LevelSmoother(alpha: 0.5)
        XCTAssertNil(smoother.update(.nan))
        smoother.update(50)
        XCTAssertEqual(smoother.update(.infinity), 50)
    }

    func testAlphaIsClamped() {
        XCTAssertEqual(LevelSmoother(alpha: 3).alpha, 1)
        XCTAssertEqual(LevelSmoother(alpha: -1).alpha, 0)
    }
}
