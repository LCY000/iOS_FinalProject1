//
//  RematchVoting.swift
//  Final Project
//
//  Self-contained rematch-vote state machine extracted from GameSessionCoordinator.
//  Handles request / respond / receive for both sides of the negotiation.
//

import Foundation

@Observable
@MainActor
final class RematchVoting {

    // MARK: - Observable State

    var showVoteAlert       = false  // peer sent a restart vote — show accept/reject
    var waitingForResponse  = false  // we sent a vote — waiting for peer reply
    var rejectedAlert       = false  // peer rejected our restart request

    // MARK: - Dependencies (wired by coordinator)

    /// Sends a prepared envelope to the peer.
    var sendEnvelope: ((MessageEnvelope) -> Void)?

    /// Called when a rematch is accepted (by either side). The coordinator
    /// uses this to reset the engine and re-push the game screen.
    var onAccepted: (() -> Void)?

    // MARK: - Actions

    /// Local user requests a rematch (called by the engine's onRestartRequested).
    func request() {
        guard !waitingForResponse else { return }
        waitingForResponse = true
        sendEnvelope?(MessageEnvelope(type: .restartVote, gameType: nil, payload: Data()))
    }

    /// Local user responds to peer's rematch request (called from the alert).
    func respond(accepted: Bool) {
        showVoteAlert = false
        let payload = RestartResponsePayload(accepted: accepted)
        sendEnvelope?(MessageEnvelope(type: .restartResponse, gameType: nil, payload: payload.toData()))
        if accepted { onAccepted?() }
    }

    // MARK: - Incoming envelope handlers (called by coordinator)

    func handleVoteReceived() {
        guard !showVoteAlert else { return }
        showVoteAlert = true
    }

    func handleResponseReceived(from data: Data) {
        waitingForResponse = false
        guard let payload = RestartResponsePayload.fromData(data) else { return }
        if payload.accepted { onAccepted?() }
        else { rejectedAlert = true }
    }

    // MARK: - Reset

    func reset() {
        showVoteAlert      = false
        waitingForResponse = false
        rejectedAlert      = false
    }
}
