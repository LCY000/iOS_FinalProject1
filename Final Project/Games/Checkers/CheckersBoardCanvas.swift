import SwiftUI

struct CheckersBoardCanvas: View {
    let board: [[CheckersPiece]]
    let flipBoard: Bool
    let validDestinations: [CheckersPosition]
    let selectedFrom: CheckersPosition?
    let onTap: (Int, Int) -> Void

    private var boardSize: Int { board.count }
    private var cellSize: CGFloat { boardSize == 10 ? 30 : 38 }

    // Rich board colors
    private static let lightCell = Color(red: 0.957, green: 0.855, blue: 0.694)
    private static let darkCell  = Color(red: 0.545, green: 0.271, blue: 0.075)

    private func displayPos(_ pos: CheckersPosition) -> CheckersPosition {
        flipBoard
            ? CheckersPosition(row: boardSize - 1 - pos.row, col: boardSize - 1 - pos.col)
            : pos
    }

    private func center(of pos: CheckersPosition) -> CGPoint {
        let d = displayPos(pos)
        return CGPoint(
            x: CGFloat(d.col) * cellSize + cellSize / 2,
            y: CGFloat(d.row) * cellSize + cellSize / 2
        )
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

    // MARK: - Board Cells

    private func drawCells(ctx: GraphicsContext) {
        for r in 0..<boardSize {
            for c in 0..<boardSize {
                let isDark = (r + c) % 2 == 1
                let rect = CGRect(x: CGFloat(c) * cellSize, y: CGFloat(r) * cellSize,
                                  width: cellSize, height: cellSize)
                ctx.fill(Path(rect), with: .color(isDark ? Self.darkCell : Self.lightCell))
            }
        }
    }

    // MARK: - Selection & Valid-Move Highlights

    private func drawHighlights(ctx: GraphicsContext) {
        if let sel = selectedFrom {
            let d = displayPos(sel)
            let rect = CGRect(x: CGFloat(d.col) * cellSize, y: CGFloat(d.row) * cellSize,
                              width: cellSize, height: cellSize)
            ctx.fill(Path(rect), with: .color(Color.yellow.opacity(0.42)))
        }
        for pos in validDestinations {
            let pt = center(of: pos)
            let r = cellSize * 0.22
            let rect = CGRect(x: pt.x - r, y: pt.y - r, width: r * 2, height: r * 2)
            ctx.fill(Path(ellipseIn: rect), with: .color(Color.green.opacity(0.65)))
        }
    }

    // MARK: - Pieces

    private func drawPieces(ctx: GraphicsContext) {
        for r in 0..<boardSize {
            for c in 0..<boardSize {
                let piece = board[r][c]
                guard let owner = piece.owner else { continue }
                let pt = center(of: CheckersPosition(row: r, col: c))
                drawPiece(ctx: ctx, piece: piece, owner: owner, center: pt)
            }
        }
    }

    private func drawPiece(ctx: GraphicsContext, piece: CheckersPiece,
                            owner: PlayerColor, center pt: CGPoint) {
        let radius = cellSize * 0.40
        let rect = CGRect(x: pt.x - radius, y: pt.y - radius,
                          width: radius * 2, height: radius * 2)

        // --- Drop shadow ---
        let shadowRect = rect.offsetBy(dx: 0, dy: 2)
        ctx.fill(Path(ellipseIn: shadowRect),
                 with: .color(Color.black.opacity(0.28)))

        // --- Base fill ---
        let baseColor: Color = owner == .black ? Color.pieceBlack : Color.pieceWhite
        ctx.fill(Path(ellipseIn: rect), with: .color(baseColor))

        // --- Specular highlight (top-left bright ellipse) ---
        let hlW = radius * 0.90
        let hlH = radius * 0.55
        let hlRect = CGRect(x: pt.x - radius * 0.52, y: pt.y - radius * 0.60,
                            width: hlW, height: hlH)
        let hlAlpha: Double = owner == .black ? 0.20 : 0.88
        ctx.fill(Path(ellipseIn: hlRect), with: .color(Color.white.opacity(hlAlpha)))

        // --- Edge stroke ---
        let strokeColor: Color = owner == .black
            ? Color.black.opacity(0.65)
            : Color(white: 0.50).opacity(0.75)
        ctx.stroke(Path(ellipseIn: rect), with: .color(strokeColor), lineWidth: 1.5)

        // --- King: double gold ring ---
        if piece.isKing {
            let outerRing = rect.insetBy(dx: -4, dy: -4)
            ctx.stroke(Path(ellipseIn: outerRing),
                       with: .color(Color.kingCrown), lineWidth: 3.5)
            let innerRing = rect.insetBy(dx: 4, dy: 4)
            ctx.stroke(Path(ellipseIn: innerRing),
                       with: .color(Color.kingCrown.opacity(0.5)), lineWidth: 1.5)
        }
    }
}
