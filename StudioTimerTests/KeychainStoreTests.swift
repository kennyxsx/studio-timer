// StudioTimerTests/KeychainStoreTests.swift
import XCTest
@testable import StudioTimer

final class KeychainStoreTests: XCTestCase {
    private var store: KeychainStore!
    private let testService = "de.ivy-s.studiotimer.tests"

    override func setUp() {
        super.setUp()
        store = KeychainStore(service: testService)
        store.clearAll()
    }

    override func tearDown() {
        store.clearAll()
        super.tearDown()
    }

    func testStoreAndRetrieveAccessToken() throws {
        try store.setAccessToken("abc123")
        XCTAssertEqual(store.accessToken, "abc123")
    }

    func testStoreAndRetrieveRefreshToken() throws {
        try store.setRefreshToken("refresh-xyz")
        XCTAssertEqual(store.refreshToken, "refresh-xyz")
    }

    func testOverwriteToken() throws {
        try store.setAccessToken("first")
        try store.setAccessToken("second")
        XCTAssertEqual(store.accessToken, "second")
    }

    func testClearRemovesBothTokens() throws {
        try store.setAccessToken("a")
        try store.setRefreshToken("r")
        store.clearAll()
        XCTAssertNil(store.accessToken)
        XCTAssertNil(store.refreshToken)
    }

    func testRetrieveWithNoStoredValueReturnsNil() {
        XCTAssertNil(store.accessToken)
        XCTAssertNil(store.refreshToken)
    }
}
