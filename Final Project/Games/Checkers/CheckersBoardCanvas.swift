import SwiftUI

struct CheckersBoardCanvas: View {
    let board: [[CheckersPiece]]
    let flipBoard: Bool
    let validDestinations: [CheckersPosition]
    let selectedFrom: CheckersPosition?
    let onTap: (Int, Int) -> Void

    private var boardSize: Int { board.count }
    // Adapts to board variant: 40pt for 8×8 (American), 32pt for 10×10 (International)
    private var cellSize: CGFloat { boardSize == 10 ? 32 : 40 }

    private func displayPos(_ pos: CheckersPosition) -> CheckersPosition {
        flipBoard
            ? CheckersPosition(row: boardSize - 1 - pos.row, col: boardSize - 1 - pos.col)
            : pos
    }

    private func center(of pos: CheckersPosition) -> CGPoint {
        let d = displayPos(pos)
        return CGPoint(x: CGFloat(d.col) * cellSize + cellSize / 2,
                       y: CGFloat(d.row) * cellSize + cellSize / 2)
    }

    var body: some View {
        let total = CGFloat(boardSize) * cellSize
        Canvas { ctx, _ in
            drawCells(ctx: ctx)
            drawHighlights(ctx: ctx)
            drawPieces(ctx: ctx)
        }
        .frame(width: total, height: total)
        .contentShape(Rectangle())
        .accessibilityLabel("Checkers board")
        .accessibilityAddTraits(.isButton)
        .onTapGesture { loc in
            var col = Int(loc.x / cellSize)
            var row = Int(loc.y / cellSize)
            if flipBoard {
                row = boardSize - 1 - row
                col = boardSize - 1 - col
            }
            guard (0..<boardSize).contains(row) && (0..<boardSize).contains(col) else { return }
            onTap(row, col)
        }
    }

    private func drawCells(ctx: GraphicsContext) {
        for r in 0..<boardSize {
            for c in 0..<boardSize {
                let isDark = (r + c) % 2 == 1
                let color = isDark ? Color.checkersDark : Color.checkersLight
                let rect = CGRect(x: CGFloat(c) * cellSize,
                                  y: CGFloat(r) * cellSize,
                                  width: cellSize, height: cellSize)
                ctx.fill(Path(rect), with: .color(color))
            }
        }
    }

    private func drawHighlights(ctx: GraphicsContext) {
        if let sel = selectedFrom {
            let d = displayPos(sel)
            let rect = CGRect(x: CGFloat(d.col) * cellSize,
                              y: CGFloat(d.row) * cellSize,
                              width: cellSize, height: cellSize)
            ctx.fill(Path(rect), with: .color(Color.accentColor.opacity(0.5)))
        }
        for pos in validDestinations {
            let d = displayPos(pos)
            let rect = CGRect(x: CGFloat(d.col) * cellSize,
                              y: CGFloat(d.row) * cellSize,
                              width: cellSize, height: cellSize)
            ctx.fill(Path(rect), with: .color(Color.accentColor.opacity(0.35)))
        }
    }

    private func drawPieces(ctx: GraphicsContext) {
        for r in 0..<boardSize {
            for c in 0..<boardSize {
                let piece = board[r][c]
                guard let owner = piece.owner else { continue }
                let pt = center(of: CheckersPosition(row: r, col: c))
                let radius = cellSize * 0.38

                let pieceRect = CGRect(x: pt.x - radius, y: pt.y - radius,
                                       width: radius * 2, height: radius * 2)
                let fill: Color = owner == .black ? Color.pieceBlack : Color.pieceWhite
                ctx.fill(Path(ellipseIn: pieceRect), with: .color(fill))

                if owner == .white {
                    ctx.stroke(Path(ellipseIn: pieceRect),
                               with: .color(Color.gray.opacity(0.5)), lineWidth: 1)
                }

                if piece.isKing {
                    drawStarBorder(ctx: ctx, center: pt,
                                   innerR: radius, outerR: radius * 1.48, points: 10)
                }
            }
        }
    }

    private func drawStarBorder(ctx: GraphicsContext, center: CGPoint,
                                 innerR: CGFloat, outerR: CGFloat, points: Int) {
        var path = Path()
        let total = points * 2
        for i in 0..<total {
            let angle = Double(i) * .pi / Double(points) - .pi / 2
            let r = i % 2 == 0 ? outerR : innerR
            let x = center.x + CGFloat(cos(angle)) * r
            let y = center.y + CGFloat(sin(angle)) * r
            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else       { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        path.closeSubpath()
        ctx.fill(path, with: .color(Color.kingCrown.opacity(0.9)))
    }
}
