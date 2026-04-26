//
//  GomokuCellView.swift
//  Final Project
//
//  Single intersection on the Gomoku board.
//  Shows grid lines, placed stone, pending preview, and last-move marker.
//

import SwiftUI

struct GomokuCellView: View {
    let cellState: CellState
    let isPending: Bool
    let pendingColor: CellState
    let isLastMove: Bool
    let row: Int
    let col: Int
    let boardSize: Int

    var body: some View {
        ZStack {
            // Grid lines
            Canvas { context, size in
                let mid = CGPoint(x: size.width / 2, y: size.height / 2)

                // Horizontal line
                var hPath = Path()
                let hStart = CGPoint(x: col == 0 ? mid.x : 0, y: mid.y)
                let hEnd = CGPoint(x: col == boardSize - 1 ? mid.x : size.width, y: mid.y)
                hPath.move(to: hStart)
                hPath.addLine(to: hEnd)
                context.stroke(hPath, with: .color(.primary.opacity(0.35)), lineWidth: 0.5)

                // Vertical line
                var vPath = Path()
                let vStart = CGPoint(x: mid.x, y: row == 0 ? mid.y : 0)
                let vEnd = CGPoint(x: mid.x, y: row == boardSize - 1 ? mid.y : size.height)
                vPath.move(to: vStart)
                vPath.addLine(to: vEnd)
                context.stroke(vPath, with: .color(.primary.opacity(0.35)), lineWidth: 0.5)
            }

            // Star point (天元 and corner stars)
            if isStarPoint {
                Circle()
                    .fill(Color.primary.opacity(0.5))
                    .frame(width: 5, height: 5)
            }

            // Pending preview stone
            if isPending {
                Circle()
                    .fill(pendingColor == .black ? Color.pieceBlack.opacity(0.4) : Color.pieceWhite.opacity(0.5))
                    .padding(3)
                    .overlay(
                        Circle()
                            .stroke(Color.yellow, lineWidth: 2)
                            .padding(3)
                    )
            }

            // Placed stone
            if cellState != .empty && !isPending {
                Circle()
                    .fill(cellState == .black ? Color.pieceBlack : Color.pieceWhite)
                    .padding(2)
                    .shadow(color: .black.opacity(0.3), radius: 1, x: 0.5, y: 0.5)
                    .overlay(
                        // Last move marker
                        isLastMove ?
                        Circle()
                            .stroke(Color.red, lineWidth: 1.5)
                            .padding(5)
                        : nil
                    )
            }
        }
    }

    // Star points for standard board sizes
    private var isStarPoint: Bool {
        guard boardSize >= 13 else { return false }
        let mid = boardSize / 2
        let starOffset = boardSize >= 19 ? 3 : 2
        let starPositions = [
            (starOffset, starOffset), (starOffset, mid), (starOffset, boardSize - 1 - starOffset),
            (mid, starOffset), (mid, mid), (mid, boardSize - 1 - starOffset),
            (boardSize - 1 - starOffset, starOffset), (boardSize - 1 - starOffset, mid),
            (boardSize - 1 - starOffset, boardSize - 1 - starOffset)
        ]
        return starPositions.contains { $0.0 == row && $0.1 == col }
    }
}
