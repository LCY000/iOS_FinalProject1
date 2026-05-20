//
//  ReversiCellView.swift
//  Final Project
//
//  Single cell on the Reversi board.
//  Shows green background, black/white piece with flip animation, preview
//  state, and a red ring marking the most recently placed piece.
//

import SwiftUI

struct ReversiCellView: View {
    let cellState: CellState
    let isValidMove: Bool
    let isPending: Bool     // preview mode: semi-transparent piece
    let pendingColor: CellState  // color of the pending piece
    let isLastMove: Bool
    let row: Int
    let col: Int
    let action: () -> Void

    private var accessibilityDescription: String {
        if isPending { return "第\(row+1)行第\(col+1)列，待確認落子" }
        switch cellState {
        case .black: return "第\(row+1)行第\(col+1)列，黑棋"
        case .white: return "第\(row+1)行第\(col+1)列，白棋"
        case .empty: return isValidMove
            ? "第\(row+1)行第\(col+1)列，可落子"
            : "第\(row+1)行第\(col+1)列，空格"
        }
    }

    // Animation state
    @State private var flipDegrees: Double = 0
    @State private var displayedState: CellState = .empty
    @State private var flipTask: Task<Void, Never>?

    var body: some View {
        Button(action: action) {
            ZStack {
                // Green board cell
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.reversiBoard)
                    .aspectRatio(1, contentMode: .fit)

                // Cell border
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(Color.black.opacity(0.3), lineWidth: 0.5)

                // Valid move hint
                if isValidMove && cellState == .empty && !isPending {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 12, weight: .light))
                        .foregroundStyle(Color.white.opacity(0.5))
                }

                // Pending preview piece (semi-transparent)
                if isPending {
                    Circle()
                        .fill(pendingColor == .black ? Color.pieceBlack.opacity(0.4) : Color.pieceWhite.opacity(0.5))
                        .padding(4)
                        .overlay {
                            Circle()
                                .stroke(Color.yellow, lineWidth: 2)
                                .padding(4)
                        }
                }

                // Placed piece
                if displayedState != .empty && !isPending {
                    let isBlack = displayedState == .black
                    let pieceColor: Color = isBlack ? .pieceBlack : .pieceWhite
                    let edgeColor: Color  = isBlack ? .black.opacity(0.50) : .gray.opacity(0.40)
                    let sheenAlpha: Double = isBlack ? 0.22 : 0.82

                    ZStack {
                        // Drop shadow
                        Circle()
                            .fill(Color.black.opacity(0.28))
                            .padding(5)
                            .offset(y: 2)

                        // Base fill
                        Circle()
                            .fill(pieceColor)
                            .padding(4)
                            .overlay {
                                // Specular sheen
                                Circle()
                                    .fill(RadialGradient(
                                        colors: [Color.white.opacity(sheenAlpha), .clear],
                                        center: UnitPoint(x: 0.33, y: 0.26),
                                        startRadius: 0,
                                        endRadius: 22))
                                    .padding(4)
                            }
                            .overlay {
                                // Edge stroke
                                Circle().stroke(edgeColor, lineWidth: 1.5).padding(4)
                            }
                    }
                    .rotation3DEffect(
                        .degrees(flipDegrees),
                        axis: (x: 0, y: 1, z: 0)
                    )
                    .overlay {
                        if isLastMove && flipDegrees == 0 {
                            Circle()
                                .stroke(Color.accentColor.opacity(0.80), lineWidth: 2)
                                .padding(7)
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityDescription)
        .onAppear {
            displayedState = cellState
        }
        .onDisappear {
            flipTask?.cancel()
        }
        .onChange(of: cellState) { oldValue, newValue in
            if oldValue != .empty && newValue != .empty && oldValue != newValue {
                // Flip animation: piece changes color
                flipTask?.cancel()
                flipTask = Task { @MainActor in
                    withAnimation(.easeInOut(duration: 0.3)) {
                        flipDegrees = 90
                    }
                    try? await Task.sleep(for: .milliseconds(300))
                    guard !Task.isCancelled else { return }
                    displayedState = newValue
                    withAnimation(.easeInOut(duration: 0.3)) {
                        flipDegrees = 0
                    }
                }
            } else {
                withAnimation(.easeOut(duration: 0.2)) {
                    displayedState = newValue
                }
            }
        }
    }
}

#Preview {
    HStack(spacing: 4) {
        ReversiCellView(cellState: .empty, isValidMove: false, isPending: false, pendingColor: .empty, isLastMove: false, row: 0, col: 0, action: {})
        ReversiCellView(cellState: .empty, isValidMove: true, isPending: false, pendingColor: .empty, isLastMove: false, row: 0, col: 1, action: {})
        ReversiCellView(cellState: .empty, isValidMove: false, isPending: true, pendingColor: .black, isLastMove: false, row: 0, col: 2, action: {})
        ReversiCellView(cellState: .black, isValidMove: false, isPending: false, pendingColor: .empty, isLastMove: true, row: 0, col: 3, action: {})
    }
    .padding()
}
