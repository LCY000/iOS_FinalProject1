//
//  GameSessionCoordinatorTests.swift
//  Final ProjectTests
//
//  Tests for GameSessionCoordinator envelope handling,
//  focusing on version guard and safe dispatch.
//

import XCTest
@testable import Final_Project

final class GameSessionCoordinatorTests: XCTestCase {

    // MARK: - MessageEnvelope version

    func testEnvelopeVersionDefaultsToCurrentVersion() {
        let env = MessageEnvelope(type: .chat, payload: Data())
        XCTAssertEqual(env.version, MessageEnvelope.currentVersion)
    }

    func testEnvelopeVersionRoundTrip() throws {
        let env = MessageEnvelope(type: .chat, payload: Data("hi".utf8))
        let data = try XCTUnwrap(env.encode())
        let decoded = try XCTUnwrap(MessageEnvelope.decode(from: data))
        XCTAssertEqual(decoded.version, MessageEnvelope.currentVersion)
    }

    func testLegacyEnvelopeWithoutVersionDecodesAsV1() throws {
        // Simulate an old peer that sends a JSON envelope without the version field.
        let json = """
        {"type":"chat","payload":"aGk="}
        """.data(using: .utf8)!
        let decoded = try XCTUnwrap(MessageEnvelope.decode(from: json))
        XCTAssertEqual(decoded.version, 1, "Missing version field should default to 1")
    }

    func testFutureVersionEnvelopeDecodes() throws {
        // A peer from the future sends version 99. We should still be able to decode it
        // (the coordinator decides what to do with it, not the model).
        let json = """
        {"type":"chat","payload":"aGk=","version":99}
        """.data(using: .utf8)!
        let decoded = try XCTUnwrap(MessageEnvelope.decode(from: json))
        XCTAssertEqual(decoded.version, 99)
    }

    // MARK: - Coordinator version guard

    @MainActor
    func testFutureVersionEnvelopeTriggersError() {
        let manager = MultipeerManager()
        let coordinator = GameSessionCoordinator(multipeerManager: manager)

        // Inject an envelope with version > currentVersion
        let futureEnvelope = buildEnvelope(version: MessageEnvelope.currentVersion + 1)
        coordinator.handleEnvelope(futureEnvelope)

        XCTAssertTrue(coordinator.showStartGameErrorAlert, "Future-version envelope should trigger error alert")
    }

    @MainActor
    func testCurrentVersionEnvelopePassesGuard() {
        let manager = MultipeerManager()
        let coordinator = GameSessionCoordinator(multipeerManager: manager)
        coordinator.attachHandlers()

        let envelope = MessageEnvelope(type: .chat, payload: Data("hello".utf8))
        coordinator.handleEnvelope(envelope)

        XCTAssertFalse(coordinator.showStartGameErrorAlert, "Current-version chat envelope should not trigger error")
    }

    // MARK: - Helpers

    private func buildEnvelope(version: Int) -> MessageEnvelope {
        let json = """
        {"type":"chat","payload":"dGVzdA==","version":\(version)}
        """.data(using: .utf8)!
        return MessageEnvelope.decode(from: json)!
    }
}
