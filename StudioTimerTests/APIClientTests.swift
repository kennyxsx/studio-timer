// StudioTimerTests/APIClientTests.swift
import XCTest
@testable import StudioTimer

final class APIClientTests: XCTestCase {
    func testDecodeEntry() throws {
        let json = """
        {
          "id": "abc-1",
          "workspace_id": "ws-1",
          "user_id": "u-1",
          "customer_user_id": null,
          "started_at": "2026-05-12T10:00:00Z",
          "duration_minutes": 30,
          "category": "Shoot",
          "notes": "tags",
          "splits": [],
          "status": "draft",
          "created_at": "2026-05-12T10:30:00Z",
          "updated_at": "2026-05-12T10:30:00Z"
        }
        """.data(using: .utf8)!

        let decoder = APIClient.makeDecoder()
        let entry = try decoder.decode(Entry.self, from: json)
        XCTAssertEqual(entry.id, "abc-1")
        XCTAssertEqual(entry.status, .draft)
        XCTAssertEqual(entry.durationMinutes, 30)
        XCTAssertNil(entry.customerUserID)
    }

    func testDecodeEntryWithFractionalSeconds() throws {
        let json = """
        {
          "id": "abc-1",
          "workspace_id": "ws-1",
          "user_id": "u-1",
          "customer_user_id": null,
          "started_at": "2026-05-12T10:00:00.123456789Z",
          "duration_minutes": 30,
          "category": "Shoot",
          "notes": null,
          "splits": [],
          "status": "draft",
          "created_at": "2026-05-12T10:30:00.987654321Z",
          "updated_at": "2026-05-12T10:30:00.987654321Z"
        }
        """.data(using: .utf8)!
        let entry = try APIClient.makeDecoder().decode(Entry.self, from: json)
        XCTAssertEqual(entry.id, "abc-1")
    }

    func testDecodeAPIErrorEnvelope() throws {
        let json = """
        {"error":{"code":"FORBIDDEN","message":"Not allowed"}}
        """.data(using: .utf8)!
        let payload = try APIClient.makeDecoder().decode(APIErrorPayload.self, from: json)
        XCTAssertEqual(payload.error.code, "FORBIDDEN")
    }
}
