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
                        .overlay(
                            Circle()
                                .stroke(Color.yellow, lineWidth: 2)
                                .padding(4)
                        )
                }

                // Placed piece
                if displayedState != .empty && !isPending {
                    Circle()
                        .fill(displayedState == .black ? Color.pieceBlack : Color.pieceWhite)
                        .padding(4)
                        .shadow(color: .black.opacity(0.4), radius: 2, x: 1, y: 1)
                        .rotation3DEffect(
                            .degrees(flipDegrees),
                            axis: (x: 0, y: 1, z: 0)
                        )
                        .overlay(
                            // Last-move marker. Only show once any flip
                            // animation has settled (flipDegrees == 0) so it
                            // doesn't rotate with the piece.
                            isLastMove && flipDegrees == 0
                            ? Circle()
                                .stroke(Color.red, lineWidth: 2)
                                .padding(7)
                            : nil
                        )
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
