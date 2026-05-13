// StudioTimerTests/ActiveTimerTests.swift
import XCTest
@testable import StudioTimer

final class ActiveTimerTests: XCTestCase {
    func testElapsedWithNoPauses() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let now = start.addingTimeInterval(300) // 5 min
        let timer = ActiveTimer(startedAt: start, pauseIntervals: [], currentPauseStart: nil)
        XCTAssertEqual(timer.elapsedSeconds(at: now), 300)
    }

    func testElapsedSubtractsClosedPauses() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let pauseStart = start.addingTimeInterval(120)
        let pauseEnd = start.addingTimeInterval(180)
        let now = start.addingTimeInterval(300)
        let timer = ActiveTimer(
            startedAt: start,
            pauseIntervals: [.init(start: pauseStart, end: pauseEnd)],
            currentPauseStart: nil)
        XCTAssertEqual(timer.elapsedSeconds(at: now), 300 - 60)
    }

    func testElapsedSubtractsActivePause() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let pauseStart = start.addingTimeInterval(200)
        let now = start.addingTimeInterval(300)
        let timer = ActiveTimer(
            startedAt: start,
            pauseIntervals: [],
            currentPauseStart: pauseStart)
        XCTAssertEqual(timer.elapsedSeconds(at: now), 300 - 100)
    }

    func testCodableRoundTrip() throws {
        let original = ActiveTimer(
            startedAt: Date(timeIntervalSince1970: 1_000_000),
            pauseIntervals: [.init(start: .init(timeIntervalSince1970: 1_000_100),
                                   end: .init(timeIntervalSince1970: 1_000_150))],
            currentPauseStart: nil)
        let data = try JSONEncoder().encode(original)
        let restored = try JSONDecoder().decode(ActiveTimer.self, from: data)
        XCTAssertEqual(restored, original)
    }
}
