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
            Text("\(engine.skippedPlayer.displayName) 沒有可落子的位置，回合已跳過。")
        }
    }

    // MARK: - Score Bar

    private var scoreBar: some View {
        HStack(spacing: 24) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.black)
                    .frame(width: 24, height: 24)
                    .overlay(Circle().stroke(Color.white, lineWidth: 1))
                Text("\(engine.scores.black)")
                    .font(.title2.bold().monospacedDigit())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(engine.currentPlayer == .black
                          ? Color.black.opacity(0.15) : Color.clear)
            )

            Text("vs")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Circle()
                    .fill(Color.white)
                    .frame(width: 24, height: 24)
                    .overlay(Circle().stroke(Color.gray, lineWidth: 1))
                Text("\(engine.scores.white)")
                    .font(.title2.bold().monospacedDigit())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(engine.currentPlayer == .white
                          ? Color.gray.opacity(0.15) : Color.clear)
            )
        }
    }

    // MARK: - Bottom Bar (fixed position, no layout push)

    private var bottomBar: some View {
        HStack {
            if engine.isGameOver {
                Button {
                    if engine.isMultiplayer {
                        engine.onRestartRequested?()
                    } else {
                        engine.reset()
                    }
                } label: {
                    Label("再來一局", systemImage: "arrow.counterclockwise")
                        .font(.subheadline.bold())
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.green))
                        .foregroundStyle(.white)
                }
            }

            Spacer()

            if engine.pendingMove != nil {
                HStack(spacing: 12) {
                    Button {
                        engine.cancelMove()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.red)
                    }

                    Button {
                        engine.confirmMove()
                    } label: {
                        Label("確認", systemImage: "checkmark")
                            .font(.subheadline.bold())
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Color.green))
                            .foregroundStyle(.white)
                    }
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
                                action: { engine.handleTap(row: row, col: col) }
                            )
                            .frame(width: cellSize, height: cellSize)
                        }
                    }
                }
            }
            .background(Color.black)
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
