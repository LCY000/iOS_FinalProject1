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
    let rematchVoting = RematchVoting()

    // MARK: - Navigation / Game State

    var gameStarted: Bool = false
    var engine: (any GameEngine)?

    // MARK: - Leave Room

    var isIntentionalLeave: Bool = false
    var showDisconnectAlert: Bool = false

    // MARK: - Peer Left / Desync

    var showPeerLeftBanner: Bool = false
    var showDesyncAlert: Bool = false
    var showStartGameErrorAlert: Bool = false
    var startGameErrorMessage: String = ""

    // MARK: - First Mover

    var firstMoverConfig: FirstMoverConfig = FirstMoverConfig()
    private var gameCount: Int = 0
    private var initialHostIsBlack: Bool = true

    // MARK: - Init

    init(multipeerManager: MultipeerManager) {
        self.multipeerManager = multipeerManager
        rematchVoting.sendEnvelope = { [weak multipeerManager] envelope in
            multipeerManager?.send(envelope: envelope)
        }
    }

    // MARK: - Setup (called from RoomView.onAppear)

    /// Wires the single envelope handler and the chat sender. Safe to call
    /// multiple times — it just replaces the closures.
    func attachHandlers() {
        multipeerManager.onEnvelopeReceived = { [weak self] envelope in
            self?.handleEnvelope(envelope)
        }
        multipeerManager.onPeerConnected = {
            SoundManager.shared.play(.connect)
        }
        chatManager.onSendEnvelope = { [weak multipeerManager] envelope in
            multipeerManager?.send(envelope: envelope)
        }
        rematchVoting.onAccepted = { [weak self] in
            guard let self, let engine = self.engine else { return }
            let hostIsBlack = self.nextHostIsBlack()
            engine.localPlayer = self.multipeerManager.isHost
                ? (hostIsBlack ? .black : .white)
                : (hostIsBlack ? .white : .black)
            engine.reset()
            engine.applyFirstMover(engine.localPlayer)
            if !self.gameStarted { self.gameStarted = true }
        }
    }

    // MARK: - Connection State

    /// Called from RoomView.onChange(of: multipeerManager.connectionState).
    /// Decides whether to raise the generic disconnect alert.
    func handleConnectionStateChange(_ newState: ConnectionState) {
        guard newState == .disconnected || newState == .notConnected else { return }

        SoundManager.shared.play(.disconnect)
        rematchVoting.reset()

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
        let hostIsBlack = nextHostIsBlack()
        newEngine.isMultiplayer = true
        newEngine.localPlayer = hostIsBlack ? .black : .white
        wireEngineCallbacks(newEngine)

        newEngine.opponentName = multipeerManager.connectedPeerName
        self.engine = newEngine
        showPeerLeftBanner = false
        rematchVoting.reset()

        let settingsData = newEngine.exportSettings()
        let startInfo = StartGamePayload(
            gameType: game.gameType,
            settings: settingsData,
            hostLocalPlayer: newEngine.localPlayer,
            firstMoverConfig: firstMoverConfig
        )
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

    // MARK: - Rematch (delegate to RematchVoting)

    func requestRestart() {
        guard engine != nil else { return }
        rematchVoting.request()
    }

    func respondToRestart(accepted: Bool) {
        rematchVoting.respond(accepted: accepted)
    }

    // MARK: - Private

    private func nextHostIsBlack() -> Bool {
        gameCount += 1
        if gameCount == 1 {
            let result: Bool
            switch firstMoverConfig.initial {
            case .host:   result = true
            case .guest:  result = false
            case .random: result = Bool.random()
            }
            initialHostIsBlack = result
            return result
        }
        switch firstMoverConfig.onRematch {
        case .fixed:
            return initialHostIsBlack
        case .alternate:
            return gameCount % 2 == 1 ? initialHostIsBlack : !initialHostIsBlack
        case .random:
            return Bool.random()
        }
    }

    func handleEnvelope(_ envelope: MessageEnvelope) {
        guard envelope.version <= MessageEnvelope.currentVersion else {
            startGameErrorMessage = "對手使用較新版本的應用程式，請更新後再試。"
            showStartGameErrorAlert = true
            multipeerManager.disconnect()
            return
        }
        switch envelope.type {
        case .startGame:
            handleGuestReceiveStartGame(envelope: envelope)

        case .playerMove:
            engine?.receiveRemoteMove(data: envelope.payload)

        case .chat:
            chatManager.receiveEnvelope(envelope)

        case .restartVote:
            rematchVoting.handleVoteReceived()

        case .restartResponse:
            rematchVoting.handleResponseReceived(from: envelope.payload)

        case .peerLeftRoom:
            showPeerLeftBanner = true
            rematchVoting.reset()

        case .setRules, .gameOver:
            break
        }
    }

    private func handleGuestReceiveStartGame(envelope: MessageEnvelope) {
        guard let startInfo = try? JSONDecoder().decode(
                StartGamePayload.self, from: envelope.payload
              ) else {
            startGameErrorMessage = "收到的開始遊戲訊息無法解析，可能是雙方版本不同。請確認雙方使用相同版本後重試。"
            showStartGameErrorAlert = true
            multipeerManager.disconnect()
            return
        }
        guard let game = GameRegistry.availableGames.first(
                where: { $0.gameType == startInfo.gameType }
              ) else {
            startGameErrorMessage = "對方選擇的遊戲（\(startInfo.gameType)）在此版本不存在，請更新 App。"
            showStartGameErrorAlert = true
            multipeerManager.disconnect()
            return
        }

        let newEngine = game.createEngine()
        newEngine.applySettings(data: startInfo.settings)
        newEngine.isMultiplayer = true
        newEngine.localPlayer = startInfo.hostLocalPlayer == .black ? .white : .black
        newEngine.opponentName = multipeerManager.connectedPeerName
        firstMoverConfig = startInfo.firstMoverConfig
        gameCount = 1
        initialHostIsBlack = startInfo.hostLocalPlayer == .black
        wireEngineCallbacks(newEngine)

        self.engine = newEngine
        showPeerLeftBanner = false
        rematchVoting.reset()

        pushGameScreen()
    }

    private func wireEngineCallbacks(_ engine: any GameEngine) {
        engine.onMoveToSend = { [weak multipeerManager] envelope in
            multipeerManager?.send(envelope: envelope)
        }
        engine.onRestartRequested = { [weak self] in
            self?.requestRestart()
        }
        engine.onDesyncDetected = { [weak self] in
            guard let self else { return }
            self.showDesyncAlert = true
            self.multipeerManager.disconnect()
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
