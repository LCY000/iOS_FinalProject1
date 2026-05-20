//
//  GomokuEngine.swift
//  Final Project
//
//  Bridges GomokuModel to the GameEngine protocol.
//

import SwiftUI

@Observable
final class GomokuEngine: GameEngine {

    // MARK: - Identity

    static let gameTitle = "五子棋"
    static let gameIcon = "circle.grid.3x3"
    static let gameType = "gomoku"

    // MARK: - Internal State

    var model: GomokuModel
    var rules: GomokuRules

    init() {
        let defaultRules = GomokuRules()
        self.rules = defaultRules
        self.model = GomokuModel(rules: defaultRules)
    }

    // MARK: - Session Wins (persists across rematches within a session)
    private(set) var sessionWins: (black: Int, white: Int) = (0, 0)

    // MARK: - GameEngine State

    var currentPlayer: PlayerColor { model.currentPlayer }

    var scores: (black: Int, white: Int) { sessionWins }

    var isGameOver: Bool { model.isGameOver }

    var boardSize: Int { rules.boardSize }

    var statusMessage: String {
        if isGameOver {
            if let winner = model.winner {
                return "\(winner.displayName) 獲勝！🎉"
            } else {
                return "平手！"
            }
        }

        if pendingMove != nil {
            return "確認落子？"
        }

        if isMultiplayer {
            if currentPlayer == localPlayer {
                return "輪到你了（\(currentPlayer.displayName)）"
            } else {
                return "等待對手落子…"
            }
        }

        return "輪到 \(currentPlayer.displayName)"
    }

    var board: [[CellState]] { model.board }
    var lastMove: (row: Int, col: Int)? { model.lastMove }

    // MARK: - Multiplayer

    var isMultiplayer: Bool = false
    var localPlayer: PlayerColor = .black
    var opponentName: String? = nil
    var onMoveToSend: ((MessageEnvelope) -> Void)?
    var onRestartRequested: (() -> Void)?
    var nextSendSeq: UInt32 = 1
    var expectedRecvSeq: UInt32 = 1
    var onDesyncDetected: (() -> Void)?

    // MARK: - Move Confirmation

    var pendingMove: (row: Int, col: Int)?

    func confirmMove() {
        guard let move = pendingMove else { return }
        pendingMove = nil
        SoundManager.shared.play(.placePiece)
        executePlacement(row: move.row, col: move.col)
    }

    func cancelMove() {
        pendingMove = nil
    }

    // MARK: - Actions

    @discardableResult
    func handleTap(row: Int, col: Int) -> Bool {
        if isMultiplayer && currentPlayer != localPlayer { return false }
        guard row >= 0 && row < rules.boardSize &&
              col >= 0 && col < rules.boardSize &&
              model.board[row][col] == .empty else { return false }

        // Set as pending
        pendingMove = (row, col)
        return true
    }

    func receiveRemoteMove(data: Data) {
        guard let move = MoveMessage.fromData(data) else {
            onDesyncDetected?()
            return
        }
        guard isMultiplayer, currentPlayer != localPlayer else { return }
        guard move.seq == expectedRecvSeq else {
            onDesyncDetected?()
            return
        }
        expectedRecvSeq &+= 1
        SoundManager.shared.play(.opponentMove)
        _ = model.placePiece(row: move.row, col: move.col)
        recordWinIfNeeded()
    }

    func reset() {
        model.reset()
        pendingMove = nil
        nextSendSeq = 1
        expectedRecvSeq = 1
    }

    func applyFirstMover(_ player: PlayerColor) {
        model.currentPlayer = player
        pendingMove = nil
    }

    // MARK: - Settings

    func makeSettingsView() -> AnyView {
        AnyView(GomokuSettingsView(engine: self))
    }

    func exportSettings() -> Data {
        (try? JSONEncoder().encode(rules)) ?? Data()
    }

    func applySettings(data: Data) {
        if let decoded = try? JSONDecoder().decode(GomokuRules.self, from: data) {
            self.rules = decoded
            self.model = GomokuModel(rules: decoded)
        }
    }

    func updateRules(_ newRules: GomokuRules) {
        rules = newRules
        model = GomokuModel(rules: newRules)
        pendingMove = nil
        nextSendSeq = 1
        expectedRecvSeq = 1
    }

    // MARK: - View Factory

    func makeGameView() -> AnyView {
        AnyView(GomokuGameView(engine: self))
    }

    // MARK: - Private

    private func executePlacement(row: Int, col: Int) {
        guard model.placePiece(row: row, col: col) else { return }
        recordWinIfNeeded()
        sendMoveEnvelope(row: row, col: col, gameType: GomokuEngine.gameType)
    }

    private func recordWinIfNeeded() {
        guard let winner = model.winner else { return }
        if winner == .black { sessionWins.black += 1 }
        else { sessionWins.white += 1 }
    }
}
