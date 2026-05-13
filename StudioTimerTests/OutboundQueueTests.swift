// StudioTimerTests/OutboundQueueTests.swift
import XCTest
@testable import StudioTimer

@MainActor
final class OutboundQueueTests: XCTestCase {
    private var url: URL!

    override func setUp() {
        super.setUp()
        url = FileManager.default.temporaryDirectory.appendingPathComponent("test_outbound_\(UUID().uuidString).json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: url)
        super.tearDown()
    }

    func testEnqueueAndPersist() throws {
        let q = OutboundQueue(persistenceURL: url)
        try q.enqueue(.stop(workspaceID: "ws-1", startedAt: Date(timeIntervalSince1970: 1_000_000), durationMinutes: 30))
        let restored = OutboundQueue(persistenceURL: url)
        XCTAssertEqual(restored.pending.count, 1)
    }

    func testMaxSizeDropsOldest() throws {
        let q = OutboundQueue(persistenceURL: url)
        for i in 0..<12 {
            try q.enqueue(.stop(workspaceID: "ws-\(i)", startedAt: Date(), durationMinutes: i + 1))
        }
        XCTAssertEqual(q.pending.count, 10) // max 10
        XCTAssertEqual(q.pending.first?.durationMinutes, 3) // first 2 dropped
    }
}
