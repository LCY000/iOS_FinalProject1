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
        .navigationTitle("五子棋")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Board Content

    private var boardContent: some View {
        VStack(spacing: 0) {
            ForEach(0..<engine.rules.boardSize, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<engine.rules.boardSize, id: \.self) { col in
                        let isPending = engine.pendingMove?.row == row && engine.pendingMove?.col == col
                        let isLastMove = engine.lastMove?.row == row && engine.lastMove?.col == col

                        GomokuCellView(
                            cellState: engine.board[row][col],
                            isPending: isPending,
                            pendingColor: isPending ? CellState.from(engine.currentPlayer) : .empty,
                            isLastMove: isLastMove,
                            row: row,
                            col: col,
                            boardSize: engine.rules.boardSize
                        )
                        .frame(width: cellSize, height: cellSize)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            engine.handleTap(row: row, col: col)
                        }
                        .onLongPressGesture(minimumDuration: 0.3) {
                            engine.handleTap(row: row, col: col)
                        }
                    }
                }
            }
        }
        .background(Color(red: 0.86, green: 0.72, blue: 0.52))
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
    }

    // MARK: - Score Bar

    private var scoreBar: some View {
        HStack(spacing: 24) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.black)
                    .frame(width: 22, height: 22)
                    .overlay(Circle().stroke(Color.white, lineWidth: 1))
                Text("\(engine.scores.black)")
                    .font(.title3.bold().monospacedDigit())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
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

                Text("\(Int(currentScale * 100))%")
                    .font(.caption.monospacedDigit())
                    .frame(width: 44)

                Button {
                    withAnimation { currentScale = min(maxScale, currentScale + 0.25) }
                } label: {
                    Image(systemName: "plus.magnifyingglass")
                        .font(.title3)
                }
            }

            Spacer()

            // Confirm/Cancel or Game Over (right side)
            if engine.isGameOver {
                Button {
                    engine.reset()
                } label: {
                    Label("再來一局", systemImage: "arrow.counterclockwise")
                        .font(.subheadline.bold())
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.green))
                        .foregroundStyle(.white)
                }
            } else if engine.pendingMove != nil {
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
