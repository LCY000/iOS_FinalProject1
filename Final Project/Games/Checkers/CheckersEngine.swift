//
//  CheckersEngine.swift
//  Final Project
//
//  Bridges CheckersModel to the GameEngine protocol.
//

import SwiftUI

@Observable
final class CheckersEngine: GameEngine {

    // MARK: - Identity
    static let gameTitle = "西洋跳棋"
    static let gameIcon  = "checkerboard.rectangle"
    static let gameType  = "checkers"

    // MARK: - State
    var model: CheckersModel
    var selectedFrom: CheckersPosition?
    private(set) var currentValidMoves: [(from: CheckersPosition, to: CheckersPosition, captures: [CheckersPosition])] = []

    init(variant: CheckersVariant = .american) {
        model = CheckersModel(variant: variant)
        refreshValidMoves()
    }

    private func refreshValidMoves() {
        currentValidMoves = model.validMoves(for: model.currentPlayer)
    }

    // MARK: - GameEngine State
    var currentPlayer: PlayerColor { model.currentPlayer }
    var scores: (black: Int, white: Int) {
        var b = 0; var w = 0
        for row in model.board { for p in row {
            if p.owner == .black { b += 1 } else if p.owner == .white { w += 1 }
        }}
        return (b, w)
    }
    var isGameOver: Bool { model.isGameOver }
    var boardSize: Int { model.boardSize }

    var statusMessage: String {
        if isGameOver {
            guard let winner = model.winner else { return "平手" }
            if isMultiplayer { return (winner == localPlayer ? "你" : "對手") + " 獲勝！🎉" }
            return "\(winner.displayName) 獲勝！🎉"
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

    // MARK: - Pending Move (two-tap UI — no separate confirm step)
    var pendingMove: (row: Int, col: Int)? { nil }
    func confirmMove() {}
    func cancelMove() {}

    // MARK: - Tap Handling

    @discardableResult
    func handleTap(row: Int, col: Int) -> Bool {
        guard !isGameOver else { return false }
        guard !isMultiplayer || currentPlayer == localPlayer else { return false }
        let tapped = CheckersPosition(row: row, col: col)

        if selectedFrom == nil {
            let hasMoves = currentValidMoves.contains { $0.from == tapped }
            if hasMoves { selectedFrom = tapped; return true }
            return false
        }

        let move = currentValidMoves.first { $0.from == selectedFrom && $0.to == tapped }
        guard let move else {
            let reselect = currentValidMoves.contains { $0.from == tapped }
            selectedFrom = reselect ? tapped : nil
            return reselect
        }

        executeMove(path: [move.from, move.to], captures: move.captures)
        return true
    }

    func executeMove(path: [CheckersPosition], captures: [CheckersPosition]) {
        if isMultiplayer {
            let payload = CheckersMovePayload(path: path, captures: captures,
                                              promoted: false, seq: nextSendSeq)
            nextSendSeq &+= 1
            let envelope = MessageEnvelope(type: .playerMove, gameType: Self.gameType,
                                           payload: payload.toData())
            onMoveToSend?(envelope)
        }
        model.applyMove(path: path, captures: captures)
        selectedFrom = nil
        refreshValidMoves()
        SoundManager.shared.play(captures.isEmpty ? .placePiece : .opponentMove)
    }

    // MARK: - Remote Move

    func receiveRemoteMove(data: Data) {
        guard let payload = CheckersMovePayload.fromData(data) else { return }
        guard payload.seq == expectedRecvSeq else { onDesyncDetected?(); return }
        expectedRecvSeq &+= 1
        model.applyMove(path: payload.path, captures: payload.captures)
        selectedFrom = nil
        refreshValidMoves()
    }

    // MARK: - Reset

    func reset() {
        model = CheckersModel(variant: model.variant)
        selectedFrom = nil
        nextSendSeq = 1
        expectedRecvSeq = 1
        refreshValidMoves()
    }

    // MARK: - Settings

    func makeSettingsView() -> AnyView { AnyView(CheckersSettingsView(engine: self)) }

    func exportSettings() -> Data {
        (try? JSONEncoder().encode(model.variant.rawValue)) ?? Data()
    }

    func applySettings(data: Data) {
        guard let raw = try? JSONDecoder().decode(String.self, from: data),
              let variant = CheckersVariant(rawValue: raw) else { return }
        model = CheckersModel(variant: variant)
        refreshValidMoves()
    }

    func makeGameView() -> AnyView { AnyView(Text("Checkers")) }

    // MARK: - Convenience

    var board: [[CheckersPiece]] { model.board }
    var validDestinations: [CheckersPosition] {
        guard let from = selectedFrom else { return [] }
        return currentValidMoves.filter { $0.from == from }.map(\.to)
    }
}

// MARK: - Settings View

struct CheckersSettingsView: View {
    @Bindable var engine: CheckersEngine

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text("規則版本")
                .font(.appSection)
            Picker("規則", selection: Binding(
                get: { engine.model.variant },
                set: { engine.model = CheckersModel(variant: $0) }
            )) {
                Text("美式（8×8）").tag(CheckersVariant.american)
                Text("國際（10×10）").tag(CheckersVariant.international)
            }
            .pickerStyle(.segmented)
            Text(engine.model.variant == .american
                 ? "強制吃子，普通王只走一格"
                 : "強制吃最多子，飛王可走任意距離")
                .font(.appCaption)
                .foregroundStyle(.secondary)
        }
        .padding(Spacing.m)
        .card(radius: Radius.m, elevation: .low, padding: 0)
    }
}
