//
//  ReversiEngine.swift
//  Final Project
//
//  Bridges ReversiModel to the GameEngine protocol.
//

import SwiftUI

@Observable
class ReversiEngine: GameEngine {

    // MARK: - Identity

    static let gameTitle = "黑白棋"
    static let gameIcon = "circle.lefthalf.filled"
    static let gameType = "reversi"

    // MARK: - Internal State

    var model: ReversiModel
    var rules: ReversiRules

    init() {
        let defaultRules = ReversiRules()
        self.rules = defaultRules
        self.model = ReversiModel(rules: defaultRules)
    }

    // MARK: - GameEngine State

    var currentPlayer: PlayerColor { model.currentPlayer }
    var scores: (black: Int, white: Int) { model.score() }
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
        if pendingMove != nil { return "確認落子？" }
        if isMultiplayer {
            return currentPlayer == localPlayer
                ? "輪到你了（\(currentPlayer.displayName)）"
                : "等待對手落子…"
        }
        return "輪到 \(currentPlayer.displayName)"
    }

    var validMoves: [(row: Int, col: Int)] {
        model.validMoves(for: model.currentPlayer)
    }

    var board: [[CellState]] { model.board }

    // MARK: - Multiplayer

    var isMultiplayer: Bool = false
    var localPlayer: PlayerColor = .black
    var onMoveToSend: ((MessageEnvelope) -> Void)?

    var turnWasSkipped: Bool = false
    var skippedPlayer: PlayerColor = .black

    // MARK: - Move Confirmation

    var pendingMove: (row: Int, col: Int)?

    func confirmMove() {
        guard let move = pendingMove else { return }
        pendingMove = nil
        executePlacement(row: move.row, col: move.col)
    }

    func cancelMove() {
        pendingMove = nil
    }

    // MARK: - Actions

    @discardableResult
    func handleTap(row: Int, col: Int) -> Bool {
        if isMultiplayer && currentPlayer != localPlayer { return false }
        guard model.board[row][col] == .empty else { return false }
        let moves = model.validMoves(for: currentPlayer)
        guard moves.contains(where: { $0.row == row && $0.col == col }) else { return false }
        pendingMove = (row, col)
        return true
    }

    func receiveRemoteMove(data: Data) {
        guard let move = MoveMessage.fromData(data) else { return }
        _ = model.placePiece(row: move.row, col: move.col)
        checkAndSkipTurn()
    }

    func reset() {
        model.reset()
        turnWasSkipped = false
        pendingMove = nil
    }

    // MARK: - Settings

    func makeSettingsView() -> AnyView {
        AnyView(ReversiSettingsView(engine: self))
    }

    func exportSettings() -> Data {
        (try? JSONEncoder().encode(rules)) ?? Data()
    }

    func applySettings(data: Data) {
        if let decoded = try? JSONDecoder().decode(ReversiRules.self, from: data) {
            self.rules = decoded
            self.model = ReversiModel(rules: decoded)
        }
    }

    // MARK: - View Factory

    func makeGameView() -> AnyView {
        AnyView(ReversiGameView(engine: self))
    }

    // MARK: - Private

    private func executePlacement(row: Int, col: Int) {
        guard model.placePiece(row: row, col: col) else { return }
        if isMultiplayer {
            let move = MoveMessage(row: row, col: col)
            let envelope = MessageEnvelope(
                type: .playerMove,
                gameType: ReversiEngine.gameType,
                payload: move.toData()
            )
            onMoveToSend?(envelope)
        }
        checkAndSkipTurn()
    }

    private func checkAndSkipTurn() {
        if model.skipTurnIfNeeded() {
            skippedPlayer = model.currentPlayer.opposite
            turnWasSkipped = true
        }
    }
}

// MARK: - Reversi Settings View

struct ReversiSettingsView: View {
    @Bindable var engine: ReversiEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("棋盤大小")
                .font(.subheadline.bold())

            HStack(spacing: 8) {
                ForEach(ReversiRules.supportedBoardSizes, id: \.self) { size in
                    Button {
                        engine.rules.boardSize = size
                        engine.model = ReversiModel(rules: engine.rules)
                    } label: {
                        Text("\(size)×\(size)")
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(engine.rules.boardSize == size
                                          ? Color.blue : Color.gray.opacity(0.15))
                            )
                            .foregroundStyle(engine.rules.boardSize == size
                                             ? .white : .primary)
                    }
                }
            }
        }
        .padding(.horizontal, 24)
    }
}
