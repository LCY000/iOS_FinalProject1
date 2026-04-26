//
//  ReversiGameView.swift
//  Final Project
//
//  Main game screen for Reversi: score bar + status + board + controls.
//  Confirmation buttons are in the bottom-right to avoid pushing the board.
//

import SwiftUI

struct ReversiGameView: View {
    @Bindable var engine: ReversiEngine
    @Environment(\.dismiss) private var dismiss

    private var isLocalWinner: Bool {
        guard let winner = engine.model.winner else { return false }
        return engine.isMultiplayer ? winner == engine.localPlayer : true
    }

    private var winnerLabel: String {
        guard let winner = engine.model.winner else { return "" }
        if engine.isMultiplayer {
            return winner == engine.localPlayer ? "你" : "對手"
        }
        return winner.displayName
    }

    var body: some View {
        VStack(spacing: 16) {
            // MARK: - Score Bar
            scoreBar

            // MARK: - Status Message
            Text(engine.statusMessage)
                .font(.headline)
                .foregroundStyle(engine.isGameOver ? .orange : .primary)
                .animation(.easeInOut, value: engine.statusMessage)
                .padding(.horizontal)

            // MARK: - Board
            boardGrid
                .padding(.horizontal, 8)

            // MARK: - Bottom Bar (confirm/cancel + game controls, fixed position)
            bottomBar
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

            Spacer(minLength: 0)
        }
        .padding(.top)
        .animatedEntrance()
        .navigationTitle("黑白棋")
        .navigationBarTitleDisplayMode(.inline)
        .alert("跳過回合", isPresented: $engine.turnWasSkipped) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(skipMessage)
        }
        .hapticFeedback(.selection, trigger: engine.pendingMove?.row ?? -1)
        .hapticFeedback(.confirm, trigger: engine.lastMove?.row ?? -1)
        .hapticFeedback(.opponentMove, trigger: engine.expectedRecvSeq)
        .hapticFeedback(.win, trigger: engine.isGameOver)
        .hapticFeedback(.warn, trigger: engine.turnWasSkipped)
        .onChange(of: engine.isGameOver) { _, over in
            if over { SoundManager.shared.play(.gameOver) }
        }
        .overlay {
            if engine.isGameOver {
                GameResultOverlay(
                    isWinner: isLocalWinner,
                    isDraw: engine.model.winner == nil,
                    winnerLabel: winnerLabel,
                    blackScore: engine.scores.black,
                    whiteScore: engine.scores.white,
                    onRematch: {
                        if engine.isMultiplayer { engine.onRestartRequested?() } else { engine.reset() }
                    },
                    onLeave: { dismiss() }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: engine.isGameOver)
    }

    private var skipMessage: String {
        guard engine.isMultiplayer else {
            return "\(engine.skippedPlayer.displayName) 沒有可落子的位置，回合已跳過。"
        }
        if engine.skippedPlayer == engine.localPlayer {
            return "你沒有可落子的位置，回合已跳過。"
        } else {
            return "對手沒有可落子的位置，回合已跳過。"
        }
    }

    // MARK: - Score Bar

    private var scoreBar: some View {
        HStack(spacing: 24) {
            HStack(spacing: Spacing.xs) {
                Circle()
                    .fill(Color.pieceBlack)
                    .frame(width: 24, height: 24)
                    .overlay(Circle().stroke(Color.pieceWhite, lineWidth: 1))
                Text("\(engine.scores.black)").font(.appNumber)
            }
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, Spacing.xs)
            .background(
                Capsule().fill(engine.currentPlayer == .black
                               ? Color.primary.opacity(0.12) : Color.clear)
            )

            Text("vs").font(.appCaption).foregroundStyle(.secondary)

            HStack(spacing: Spacing.xs) {
                Circle()
                    .fill(Color.pieceWhite)
                    .frame(width: 24, height: 24)
                    .overlay(Circle().stroke(Color.gray, lineWidth: 1))
                Text("\(engine.scores.white)").font(.appNumber)
            }
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, Spacing.xs)
            .background(
                Capsule().fill(engine.currentPlayer == .white
                               ? Color.gray.opacity(0.15) : Color.clear)
            )
        }
    }

    // MARK: - Bottom Bar (fixed position, no layout push)

    private var bottomBar: some View {
        HStack {
            if engine.isGameOver {
                Button {
                    if engine.isMultiplayer { engine.onRestartRequested?() } else { engine.reset() }
                } label: {
                    Label("再來一局", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(PillButtonStyle(tint: .green))
            }

            Spacer()

            if engine.pendingMove != nil {
                HStack(spacing: Spacing.s) {
                    Button {
                        engine.cancelMove()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.red)
                    }
                    .accessibilityLabel("取消落子")

                    Button {
                        engine.confirmMove()
                    } label: {
                        Label("確認", systemImage: "checkmark")
                    }
                    .buttonStyle(PillButtonStyle(tint: .green))
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.2), value: engine.pendingMove != nil)
        .frame(height: 36)
    }

    // MARK: - Board Grid

    private var boardGrid: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let cellSize = size / CGFloat(engine.boardSize)

            VStack(spacing: 0) {
                ForEach(0..<engine.boardSize, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<engine.boardSize, id: \.self) { col in
                            let isPending = engine.pendingMove?.row == row && engine.pendingMove?.col == col
                            let isLastMove = engine.lastMove?.row == row && engine.lastMove?.col == col
                            ReversiCellView(
                                cellState: engine.board[row][col],
                                isValidMove: isValidMove(row: row, col: col),
                                isPending: isPending,
                                pendingColor: isPending ? CellState.from(engine.currentPlayer) : .empty,
                                isLastMove: isLastMove,
                                row: row,
                                col: col,
                                action: { engine.handleTap(row: row, col: col) }
                            )
                            .frame(width: cellSize, height: cellSize)
                        }
                    }
                }
            }
            .background(Color.boardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
            .frame(width: size, height: size)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func isValidMove(row: Int, col: Int) -> Bool {
        engine.validMoves.contains(where: { $0.row == row && $0.col == col })
    }
}

#Preview {
    NavigationStack {
        ReversiGameView(engine: ReversiEngine())
    }
}
