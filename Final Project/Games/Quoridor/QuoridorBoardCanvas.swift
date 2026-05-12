import SwiftUI

struct QuoridorBoardCanvas: View {
    let model: QuoridorModel
    let localPlayer: PlayerColor
    let flipBoard: Bool          // true when local player is white (guest)
    let inputMode: QuoridorInputMode
    let selectedPawn: QuoridorPosition?
    let validMoves: [QuoridorPosition]
    let wallPreview: (row: Int, col: Int)?
    let onTapCell: (Int, Int) -> Void
    let onTapWallSlot: (Int, Int) -> Void

    private let cellSize: CGFloat = 36
    private let wallGap: CGFloat = 6

    private var slotSize: CGFloat { cellSize + wallGap }

    private func displayPos(_ pos: QuoridorPosition) -> QuoridorPosition {
        flipBoard ? QuoridorPosition(row: 8 - pos.row, col: 8 - pos.col) : pos
    }

    private func center(of pos: QuoridorPosition) -> CGPoint {
        let d = displayPos(pos)
        return CGPoint(
            x: CGFloat(d.col) * slotSize + cellSize / 2,
            y: CGFloat(d.row) * slotSize + cellSize / 2
        )
    }

    var body: some View {
        let totalSize = CGFloat(QuoridorModel.boardSize) * slotSize - wallGap
        Canvas { ctx, _ in
            drawBoard(ctx: ctx)
            drawWalls(ctx: ctx)
            drawValidMoves(ctx: ctx)
            drawWallPreview(ctx: ctx)
            drawPawns(ctx: ctx)
        }
        .frame(width: totalSize, height: totalSize)
        .contentShape(Rectangle())
        .accessibilityLabel(Text("Quoridor board"))
        .accessibilityAddTraits(.isButton)
        .onTapGesture { location in
            if inputMode == .pawn {
                let col = Int(location.x / slotSize)
                let row = Int(location.y / slotSize)
                guard (0..<9).contains(row) && (0..<9).contains(col) else { return }
                let r = flipBoard ? 8 - row : row
                let c = flipBoard ? 8 - col : col
                onTapCell(r, c)
            } else {
                let wCol = Int(location.x / slotSize)
                let wRow = Int(location.y / slotSize)
                guard (0..<8).contains(wRow) && (0..<8).contains(wCol) else { return }
                let r = flipBoard ? 7 - wRow : wRow
                let c = flipBoard ? 7 - wCol : wCol
                onTapWallSlot(r, c)
            }
        }
    }

    private func drawBoard(ctx: GraphicsContext) {
        let cellColor = Color(red: 0.83, green: 0.71, blue: 0.51)
        for row in 0..<QuoridorModel.boardSize {
            for col in 0..<QuoridorModel.boardSize {
                let rect = CGRect(
                    x: CGFloat(col) * slotSize,
                    y: CGFloat(row) * slotSize,
                    width: cellSize, height: cellSize
                )
                ctx.fill(Path(roundedRect: rect, cornerRadius: 3), with: .color(cellColor))
            }
        }
    }

    private func drawWalls(ctx: GraphicsContext) {
        let wallColor = Color(red: 0.36, green: 0.24, blue: 0.12)
        for r in 0..<8 {
            for c in 0..<8 {
                let displayR = flipBoard ? 7 - r : r
                let displayC = flipBoard ? 7 - c : c
                if model.hWalls[r][c] {
                    // H-wall: between row displayR and displayR+1, spanning cols displayC and displayC+1
                    let x = CGFloat(displayC) * slotSize
                    let y = CGFloat(displayR + 1) * slotSize - wallGap
                    let rect = CGRect(x: x, y: y, width: slotSize * 2 - wallGap, height: wallGap)
                    ctx.fill(Path(rect), with: .color(wallColor))
                }
                if model.vWalls[r][c] {
                    // V-wall: between col displayC and displayC+1, spanning rows displayR and displayR+1
                    let x = CGFloat(displayC + 1) * slotSize - wallGap
                    let y = CGFloat(displayR) * slotSize
                    let rect = CGRect(x: x, y: y, width: wallGap, height: slotSize * 2 - wallGap)
                    ctx.fill(Path(rect), with: .color(wallColor))
                }
            }
        }
    }

    private func drawValidMoves(ctx: GraphicsContext) {
        for pos in validMoves {
            let pt = center(of: pos)
            let dotRadius = cellSize * 0.22  // ~8 pt hint dot, visually centered in cell
            let rect = CGRect(x: pt.x - dotRadius, y: pt.y - dotRadius, width: dotRadius * 2, height: dotRadius * 2)
            ctx.fill(Path(ellipseIn: rect), with: .color(Color.accentColor.opacity(0.5)))
        }
    }

    private func drawWallPreview(ctx: GraphicsContext) {
        guard let preview = wallPreview else { return }
        let r = preview.row
        let c = preview.col
        let displayR = flipBoard ? 7 - r : r
        let displayC = flipBoard ? 7 - c : c
        let rect: CGRect
        if inputMode == .wallH {
            let x = CGFloat(displayC) * slotSize
            let y = CGFloat(displayR + 1) * slotSize - wallGap
            rect = CGRect(x: x, y: y, width: slotSize * 2 - wallGap, height: wallGap)
        } else {
            let x = CGFloat(displayC + 1) * slotSize - wallGap
            let y = CGFloat(displayR) * slotSize
            rect = CGRect(x: x, y: y, width: wallGap, height: slotSize * 2 - wallGap)
        }
        ctx.fill(Path(rect), with: .color(Color.yellow.opacity(0.7)))
    }

    private func drawPawns(ctx: GraphicsContext) {
        for player in [PlayerColor.black, PlayerColor.white] {
            guard let pos = model.positions[player] else { continue }
            let pt = center(of: pos)
            let isSelected = selectedPawn == pos && player == localPlayer
            let pawnRadius = cellSize * 0.38
            let rect = CGRect(x: pt.x - pawnRadius, y: pt.y - pawnRadius,
                              width: pawnRadius * 2, height: pawnRadius * 2)

            // Drop shadow
            ctx.fill(Path(ellipseIn: rect.offsetBy(dx: 0, dy: 2)),
                     with: .color(Color.black.opacity(0.25)))

            // Base fill
            let baseColor: Color = player == .black ? Color.pieceBlack : Color.pieceWhite
            ctx.fill(Path(ellipseIn: rect), with: .color(baseColor))

            // Specular highlight (top-left)
            let hlW = pawnRadius * 0.90
            let hlH = pawnRadius * 0.55
            let hlRect = CGRect(x: pt.x - pawnRadius * 0.52, y: pt.y - pawnRadius * 0.60,
                                width: hlW, height: hlH)
            let hlAlpha: Double = player == .black ? 0.20 : 0.88
            ctx.fill(Path(ellipseIn: hlRect), with: .color(Color.white.opacity(hlAlpha)))

            // Edge stroke
            let strokeColor: Color = player == .black
                ? Color.black.opacity(0.6) : Color.gray.opacity(0.5)
            ctx.stroke(Path(ellipseIn: rect), with: .color(strokeColor), lineWidth: 1.5)

            // Selection ring
            if isSelected {
                ctx.stroke(Path(ellipseIn: rect.insetBy(dx: -3, dy: -3)),
                           with: .color(Color.accentColor), lineWidth: 2.5)
            }
        }
    }
}
