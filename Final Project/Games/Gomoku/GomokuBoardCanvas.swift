//
//  GomokuBoardCanvas.swift
//  Final Project
//
//  Replaces 625 individual GomokuCellView instances with a single Canvas,
//  cutting view-tree overhead significantly on large boards (25×25).
//

import SwiftUI

struct GomokuBoardCanvas: View {
    let board: [[CellState]]
    let boardSize: Int
    let pendingMove: (row: Int, col: Int)?
    let pendingColor: CellState
    let lastMove: (row: Int, col: Int)?
    let cellSize: CGFloat
    let onTap: (Int, Int) -> Void

    var body: some View {
        Canvas { context, _ in
            drawGrid(in: &context)
            drawStarPoints(in: &context)
            drawStones(in: &context)
        }
        .frame(width: CGFloat(boardSize) * cellSize,
               height: CGFloat(boardSize) * cellSize)
        .contentShape(Rectangle())
        .onTapGesture { location in
            let col = Int(location.x / cellSize)
            let row = Int(location.y / cellSize)
            guard row >= 0, row < boardSize, col >= 0, col < boardSize else { return }
            onTap(row, col)
        }
    }

    // MARK: - Grid

    private func drawGrid(in context: inout GraphicsContext) {
        let half = cellSize * 0.5
        let lineEnd = CGFloat(boardSize - 1) * cellSize + half
        var path = Path()
        for i in 0..<boardSize {
            let pos = CGFloat(i) * cellSize + half
            path.move(to: CGPoint(x: half, y: pos))
            path.addLine(to: CGPoint(x: lineEnd, y: pos))
            path.move(to: CGPoint(x: pos, y: half))
            path.addLine(to: CGPoint(x: pos, y: lineEnd))
        }
        context.stroke(path, with: .color(.primary.opacity(0.35)), lineWidth: 0.5)
    }

    // MARK: - Star Points

    private func drawStarPoints(in context: inout GraphicsContext) {
        guard boardSize >= 13 else { return }
        let mid = boardSize / 2
        let off = boardSize >= 19 ? 3 : 2
        let positions = [
            (off, off), (off, mid), (off, boardSize - 1 - off),
            (mid, off), (mid, mid), (mid, boardSize - 1 - off),
            (boardSize - 1 - off, off), (boardSize - 1 - off, mid),
            (boardSize - 1 - off, boardSize - 1 - off)
        ]
        let half = cellSize * 0.5
        for (r, c) in positions {
            let cx = CGFloat(c) * cellSize + half
            let cy = CGFloat(r) * cellSize + half
            context.fill(Path(ellipseIn: CGRect(x: cx - 2.5, y: cy - 2.5, width: 5, height: 5)),
                         with: .color(.primary.opacity(0.5)))
        }
    }

    // MARK: - Stones

    private func drawStones(in context: inout GraphicsContext) {
        let half = cellSize * 0.5
        let stoneR = half - 2
        let pendingR = half - 3

        for row in 0..<boardSize {
            for col in 0..<boardSize {
                let cx = CGFloat(col) * cellSize + half
                let cy = CGFloat(row) * cellSize + half
                let isPending = pendingMove?.row == row && pendingMove?.col == col
                let isLastMove = lastMove?.row == row && lastMove?.col == col
                let state = board[row][col]

                if isPending {
                    let previewColor: Color = pendingColor == .black
                        ? Color.pieceBlack.opacity(0.4)
                        : Color.pieceWhite.opacity(0.5)
                    let rect = CGRect(x: cx - pendingR, y: cy - pendingR,
                                      width: pendingR * 2, height: pendingR * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(previewColor))
                    context.stroke(Path(ellipseIn: rect), with: .color(.yellow), lineWidth: 2)
                } else if state != .empty {
                    let stoneColor: Color = state == .black ? .pieceBlack : .pieceWhite
                    let rect = CGRect(x: cx - stoneR, y: cy - stoneR,
                                      width: stoneR * 2, height: stoneR * 2)
                    var shadowCtx = context
                    shadowCtx.addFilter(.shadow(color: Color.black.opacity(0.3), radius: 1, x: 0.5, y: 0.5))
                    shadowCtx.fill(Path(ellipseIn: rect), with: .color(stoneColor))

                    if isLastMove {
                        let inset: CGFloat = 4
                        let mr = CGRect(x: cx - stoneR + inset, y: cy - stoneR + inset,
                                        width: (stoneR - inset) * 2, height: (stoneR - inset) * 2)
                        context.stroke(Path(ellipseIn: mr), with: .color(.red), lineWidth: 1.5)
                    }
                }
            }
        }
    }
}
