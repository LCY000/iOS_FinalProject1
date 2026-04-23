//
//  GameSessionCoordinator.swift
//  Final Project
//
//  Single source of truth for an active multiplayer session. Owns the chat
//  manager and the current game engine, and routes every incoming
//  MessageEnvelope through one handler to avoid the dual-wiring bugs that
//  previously lived in RoomView.
//
//  Lifetime: created once per RoomView presentation (see RoomView.init) and
//  destroyed when the user leaves the room.
//

import SwiftUI

@Observable
@MainActor
final class GameSessionCoordinator {

    // MARK: - Dependencies

    let multipeerManager: MultipeerManager
    let chatManager = ChatManager()

    // MARK: - Navigation / Game State

    /// Drives the navigationDestination that presents the active GameView.
    var gameStarted: Bool = false

    /// The engine for the current game; nil before the host starts one or
    /// before the guest receives the first .startGame envelope.
    var engine: (any GameEngine)?

    // MARK: - Leave Room

    /// Set true when the local user taps the leave-room button. Suppresses the
    /// generic "連線已中斷" alert because the local user already knows they left.
    var isIntentionalLeave: Bool = false

    /// Shown when the peer disconnects unexpectedly (no explicit .peerLeftRoom).
    var showDisconnectAlert: Bool = false

    // MARK: - Rematch Voting

    /// Peer requested a rematch; show accept / reject alert to the local user.
    var showRestartVoteAlert: Bool = false

    /// Local user requested a rematch; show a waiting overlay until the peer
    /// responds (or the peer leaves).
    var waitingForRestartResponse: Bool = false

    /// Peer rejected the local user's rematch request.
    var restartRejectedAlert: Bool = false

    // MARK: - Peer Left During Game

    /// True once the peer has sent .peerLeftRoom (or the connection dropped).
    /// Drives a non-blocking banner on the game screen; the local user can
    /// keep viewing the board.
    var showPeerLeftBanner: Bool = false

    // MARK: - Init

    init(multipeerManager: MultipeerManager) {
        self.multipeerManager = multipeerManager
    }

    // MARK: - Setup (called from RoomView.onAppear)

    /// Wires the single envelope handler and the chat sender. Safe to call
    /// multiple times — it just replaces the closures.
    func attachHandlers() {
        multipeerManager.onEnvelopeReceived = { [weak self] envelope in
            self?.handleEnvelope(envelope)
        }
        chatManager.onSendEnvelope = { [weak multipeerManager] envelope in
            multipeerManager?.send(envelope: envelope)
        }
    }

    // MARK: - Connection State

    /// Called from RoomView.onChange(of: multipeerManager.connectionState).
    /// Decides whether to raise the generic disconnect alert.
    func handleConnectionStateChange(_ newState: ConnectionState) {
        guard newState == .disconnected || newState == .notConnected else { return }

        // Any in-flight rematch request is now void.
        waitingForRestartResponse = false

        // Suppress the alert when:
        //   (a) the local user initiated the leave, or
        //   (b) the peer already announced they are leaving (banner covers it).
        if !isIntentionalLeave && !showPeerLeftBanner {
            showDisconnectAlert = true
        }
    }

    // MARK: - Leave Room (from back button)

    func leaveRoom() {
        isIntentionalLeave = true
        // Best-effort notify peer. Fine if this fails (already disconnected).
        let envelope = MessageEnvelope(type: .peerLeftRoom, gameType: nil, payload: Data())
        multipeerManager.send(envelope: envelope)
        multipeerManager.disconnect()
    }

    // MARK: - Host: Start Game

    func hostStartGame(game: GameInfo, settingsEngine: (any GameEngine)?) {
        let newEngine: any GameEngine = settingsEngine ?? game.createEngine()
        newEngine.isMultiplayer = true
        newEngine.localPlayer = .black
        wireEngineCallbacks(newEngine)

        self.engine = newEngine
        showPeerLeftBanner = false  // reset for the new game
        restartRejectedAlert = false

        let settingsData = newEngine.exportSettings()
        let startInfo = StartGamePayload(gameType: game.gameType, settings: settingsData)
        let payload = (try? JSONEncoder().encode(startInfo)) ?? Data()
        let envelope = MessageEnvelope(
            type: .startGame,
            gameType: game.gameType,
            payload: payload
        )
        multipeerManager.send(envelope: envelope)

        pushGameScreen()
    }

    // MARK: - Continue Game (from toolbar)

    /// Re-pushes the game destination when the user has popped back to the room
    /// but the engine is still alive.
    func continueGame() {
        guard engine != nil, !gameStarted else { return }
        gameStarted = true
    }

    // MARK: - Rematch

    /// Called by the game engine's onRestartRequested callback.
    func requestRestart() {
        guard !waitingForRestartResponse else { return }
        guard engine != nil else { return }
        waitingForRestartResponse = true
        let envelope = MessageEnvelope(type: .restartVote, gameType: nil, payload: Data())
        multipeerManager.send(envelope: envelope)
    }

    /// Called when the local user taps accept / reject in the rematch alert.
    func respondToRestart(accepted: Bool) {
        let payload = RestartResponsePayload(accepted: accepted)
        let envelope = MessageEnvelope(
            type: .restartResponse,
            gameType: nil,
            payload: payload.toData()
        )
        multipeerManager.send(envelope: envelope)
        if accepted {
            engine?.reset()
            if !gameStarted {
                gameStarted = true
            }
        }
    }

    // MARK: - Private

    private func handleEnvelope(_ envelope: MessageEnvelope) {
        switch envelope.type {
        case .startGame:
            handleGuestReceiveStartGame(envelope: envelope)

        case .playerMove:
            engine?.receiveRemoteMove(data: envelope.payload)

        case .chat:
            chatManager.receiveEnvelope(envelope)

        case .restartVote:
            // Ignore duplicate requests while one is already visible.
            guard !showRestartVoteAlert else { return }
            showRestartVoteAlert = true

        case .restartResponse:
            waitingForRestartResponse = false
            if let payload = RestartResponsePayload.fromData(envelope.payload) {
                if payload.accepted {
                    engine?.reset()
                    if !gameStarted {
                        gameStarted = true
                    }
                } else {
                    restartRejectedAlert = true
                }
            }

        case .peerLeftRoom:
            showPeerLeftBanner = true
            // Cancel any in-flight rematch wait — the peer is gone.
            waitingForRestartResponse = false

        case .setRules, .gameOver:
            break
        }
    }

    private func handleGuestReceiveStartGame(envelope: MessageEnvelope) {
        guard let startInfo = try? JSONDecoder().decode(
                StartGamePayload.self, from: envelope.payload
              ),
              let game = GameRegistry.availableGames.first(
                where: { $0.gameType == startInfo.gameType }
              )
        else { return }

        let newEngine = game.createEngine()
        newEngine.applySettings(data: startInfo.settings)
        newEngine.isMultiplayer = true
        newEngine.localPlayer = .white
        wireEngineCallbacks(newEngine)

        self.engine = newEngine
        showPeerLeftBanner = false
        restartRejectedAlert = false

        pushGameScreen()
    }

    private func wireEngineCallbacks(_ engine: any GameEngine) {
        engine.onMoveToSend = { [weak multipeerManager] envelope in
            multipeerManager?.send(envelope: envelope)
        }
        engine.onRestartRequested = { [weak self] in
            self?.requestRestart()
        }
    }

    /// Push the game destination. If already pushed (host switching to a new
    /// game type mid-session), pop-and-push to force the view to re-create.
    private func pushGameScreen() {
        if gameStarted {
            gameStarted = false
            Task { @MainActor in
                gameStarted = true
            }
        } else {
            gameStarted = true
        }
    }
}
