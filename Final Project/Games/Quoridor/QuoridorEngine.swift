//
//  QuoridorEngine.swift
//  Final Project
//
//  GameEngine conformance for Quoridor.
//

import SwiftUI

enum QuoridorInputMode { case pawn, wallH, wallV }

@Observable
final class QuoridorEngine: GameEngine {

    // MARK: - Identity
    static let gameTitle = "步步為營"
    static let gameIcon  = "square.grid.3x3"
    static let gameType  = "quoridor"

    // MARK: - State
    var model = QuoridorModel()
    var inputMode: QuoridorInputMode = .pawn
    var selectedPawn: QuoridorPosition?
    var wallPreview: (row: Int, col: Int)? // TODO(Q7): set via drag gesture in QuoridorGameView

    // GameEngine computed
    var currentPlayer: PlayerColor { model.currentPlayer }
    var scores: (black: Int, white: Int) { (0, 0) }
    var isGameOver: Bool { model.isGameOver }
    var boardSize: Int { QuoridorModel.boardSize }

    var statusMessage: String {
        if let winner = model.winner {
            if isMultiplayer { return (winner == localPlayer ? "你" : "對手") + " 獲勝！" }
            return "\(winner.displayName) 獲勝！"
        }
        if isMultiplayer {
            return currentPlayer == localPlayer ? "輪到你了" : "等待對手…"
        }
        return "輪到 \(currentPlayer.displayName)"
    }

    // MARK: - Multiplayer
    var isMultiplayer: Bool = false
    var localPlayer: PlayerColor = .black
    var onMoveToSend: ((MessageEnvelope) -> Void)?
    var onRestartRequested: (() -> Void)?
    var nextSendSeq: UInt32 = 1
    var expectedRecvSeq: UInt32 = 1
    var onDesyncDetected: (() -> Void)?

    // MARK: - Pending Move (unused in Quoridor — moves apply immediately)
    var pendingMove: (row: Int, col: Int)? { nil }
    func confirmMove() {}
    func cancelMove() {}

    // MARK: - Tap Handling

    @discardableResult
    func handleTap(row: Int, col: Int) -> Bool {
        guard !isGameOver else { return false }
        guard !isMultiplayer || currentPlayer == localPlayer else { return false }
        guard inputMode == .pawn else { return false }

        let tapped = QuoridorPosition(row: row, col: col)

        if tapped == model.positions[currentPlayer] {
            selectedPawn = tapped
            return true
        }

        guard selectedPawn != nil else { return false }
        let valid = model.validPawnMoves(for: currentPlayer)
        guard valid.contains(tapped) else {
            // Keep selection alive — user may tap a different valid destination next
            return false
        }

        sendAndApplyPawn(dest: tapped)
        return true
    }

    func handleWallTap(row: Int, col: Int) {
        guard !isGameOver else { return }
        guard !isMultiplayer || currentPlayer == localPlayer else { return }
        guard inputMode == .wallH || inputMode == .wallV else { return }

        let ok = inputMode == .wallH
            ? model.canPlaceHWall(row: row, col: col)
            : model.canPlaceVWall(row: row, col: col)
        guard ok else { return }

        sendAndApplyWall(kind: inputMode == .wallH ? .wallH : .wallV, row: row, col: col)
    }

    // MARK: - Remote Move

    func receiveRemoteMove(data: Data) {
        guard let move = QuoridorMove.fromData(data) else { return }
        guard move.seq == expectedRecvSeq else {
            onDesyncDetected?(); return
        }
        expectedRecvSeq &+= 1
        switch move.kind {
        case .pawn:
            model.applyPawnMove(QuoridorPosition(row: move.row, col: move.col))
        case .wallH:
            model.applyHWall(row: move.row, col: move.col)
        case .wallV:
            model.applyVWall(row: move.row, col: move.col)
        }
        selectedPawn = nil
    }

    // MARK: - Reset

    func reset() {
        model.reset()
        selectedPawn = nil
        wallPreview = nil
        inputMode = .pawn
        nextSendSeq = 1
        expectedRecvSeq = 1
    }

    // MARK: - Settings (Quoridor has no configurable settings)

    func makeSettingsView() -> AnyView { AnyView(EmptyView()) }
    func exportSettings() -> Data { Data() }
    func applySettings(data: Data) {}

    // MARK: - View Factory

    func makeGameView() -> AnyView {
        AnyView(QuoridorGameView(engine: self))
    }

    // MARK: - Private

    private func sendAndApplyPawn(dest: QuoridorPosition) {
        if isMultiplayer {
            let move = QuoridorMove(kind: .pawn, row: dest.row, col: dest.col, seq: nextSendSeq)
            nextSendSeq &+= 1
            let envelope = MessageEnvelope(type: .playerMove, gameType: Self.gameType, payload: move.toData())
            onMoveToSend?(envelope)
        }
        model.applyPawnMove(dest)
        selectedPawn = nil
    }

    private func sendAndApplyWall(kind: QuoridorMoveKind, row: Int, col: Int) {
        if isMultiplayer {
            let move = QuoridorMove(kind: kind, row: row, col: col, seq: nextSendSeq)
            nextSendSeq &+= 1
            let envelope = MessageEnvelope(type: .playerMove, gameType: Self.gameType, payload: move.toData())
            onMoveToSend?(envelope)
        }
        if kind == .wallH { model.applyHWall(row: row, col: col) }
        else               { model.applyVWall(row: row, col: col) }
        inputMode = .pawn
    }
}
