//
//  GomokuGameView.swift
//  Final Project
//
//  Main game screen for Gomoku: zoomable/pannable board with long-press precision.
//  Confirmation buttons at bottom-right, never push the board.
//

import SwiftUI

struct GomokuGameView: View {
    @Bindable var engine: GomokuEngine
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

    // Zoom state
    @State private var currentScale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    // Board layout constants
    private let cellSize: CGFloat = 28
    private let minScale: CGFloat = 0.5
    private let maxScale: CGFloat = 3.0

    private var boardTotalSize: CGFloat {
        CGFloat(engine.rules.boardSize) * cellSize
    }

    var body: some View {
        VStack(spacing: 12) {
            // MARK: - Score Bar
            scoreBar

            // MARK: - Status
            Text(engine.statusMessage)
                .font(.headline)
                .foregroundStyle(engine.isGameOver ? .orange : .primary)

            // MARK: - Zoomable Board
            ScrollView([.horizontal, .vertical], showsIndicators: false) {
                boardContent
                    .scaleEffect(currentScale)
                    .frame(
                        width: boardTotalSize * currentScale,
                        height: boardTotalSize * currentScale
                    )
                    .gesture(magnifyGesture)
            }
            .frame(maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // MARK: - Bottom Bar (zoom + confirm/cancel, fixed position)
            bottomBar
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
        }
        .padding(.top)
        .animatedEntrance()
        .navigationTitle("五子棋")
        .navigationBarTitleDisplayMode(.inline)
        .hapticFeedback(.selection, trigger: engine.pendingMove?.row ?? -1)
        .hapticFeedback(.confirm, trigger: engine.lastMove?.row ?? -1)
        .hapticFeedback(.opponentMove, trigger: engine.expectedRecvSeq)
        .hapticFeedback(.win, trigger: engine.isGameOver)
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

    // MARK: - Board Content

    private var boardContent: some View {
        GomokuBoardCanvas(
            board: engine.board,
            boardSize: engine.rules.boardSize,
            pendingMove: engine.pendingMove,
            pendingColor: engine.pendingMove != nil ? CellState.from(engine.currentPlayer) : .empty,
            lastMove: engine.lastMove,
            cellSize: cellSize,
            onTap: { row, col in engine.handleTap(row: row, col: col) }
        )
        .accessibilityLabel("五子棋棋盤，\(engine.rules.boardSize)路")
        .background(Color.gomokuBoard)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
    }

    // MARK: - Score Bar

    private var scoreBar: some View {
        HStack(spacing: 24) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.pieceBlack)
                    .frame(width: 22, height: 22)
                    .overlay(Circle().stroke(Color.pieceWhite, lineWidth: 1))
                Text("\(engine.scores.black)")
                    .font(.title3.bold().monospacedDigit())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(engine.currentPlayer == .black
                          ? Color.primary.opacity(0.12) : Color.clear)
            )

            Text("vs")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Circle()
                    .fill(Color.pieceWhite)
                    .frame(width: 22, height: 22)
                    .overlay(Circle().stroke(Color.gray, lineWidth: 1))
                Text("\(engine.scores.white)")
                    .font(.title3.bold().monospacedDigit())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(engine.currentPlayer == .white
                          ? Color.gray.opacity(0.15) : Color.clear)
            )
        }
    }

    // MARK: - Bottom Bar (zoom controls left, confirm/cancel right)

    private var bottomBar: some View {
        HStack {
            // Zoom controls (left side)
            HStack(spacing: 8) {
                Button {
                    withAnimation { currentScale = max(minScale, currentScale - 0.25) }
                } label: {
                    Image(systemName: "minus.magnifyingglass")
                        .font(.title3)
                }
                .accessibilityLabel("縮小棋盤")

                Text("\(Int(currentScale * 100))%")
                    .font(.caption.monospacedDigit())
                    .frame(width: 44)

                Button {
                    withAnimation { currentScale = min(maxScale, currentScale + 0.25) }
                } label: {
                    Image(systemName: "plus.magnifyingglass")
                        .font(.title3)
                }
                .accessibilityLabel("放大棋盤")
            }

            Spacer()

            // Confirm/Cancel or Game Over (right side)
            if engine.isGameOver {
                Button {
                    if engine.isMultiplayer { engine.onRestartRequested?() } else { engine.reset() }
                } label: {
                    Label("再來一局", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(PillButtonStyle(tint: .green))
            } else if engine.pendingMove != nil {
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

    // MARK: - Pinch to Zoom

    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let newScale = lastScale * value.magnification
                currentScale = min(maxScale, max(minScale, newScale))
            }
            .onEnded { _ in
                lastScale = currentScale
            }
    }
}

#Preview {
    NavigationStack {
        GomokuGameView(engine: GomokuEngine())
    }
}
