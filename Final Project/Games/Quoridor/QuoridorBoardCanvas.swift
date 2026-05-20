import SwiftUI

struct QuoridorBoardCanvas: View {
    let model: QuoridorModel
    let localPlayer: PlayerColor
    let flipBoard: Bool
    let inputMode: QuoridorInputMode
    let selectedPawn: QuoridorPosition?
    let validMoves: [QuoridorPosition]
    let wallPreview: (row: Int, col: Int)?
    let onTapCell: (Int, Int) -> Void
    let onTapWallSlot: (Int, Int) -> Void

    private let cellSize: CGFloat = 38
    private let wallGap: CGFloat = 7

    private var slotSize: CGFloat { cellSize + wallGap }

    // Pawn position animation
    @State private var blackPos: CGPoint = .zero
    @State private var whitePos: CGPoint = .zero

    // Wall glow
    @State private var newWall: (row: Int, col: Int, isH: Bool)? = nil
    @State private var wallGlowOpacity: Double = 0

    // MARK: - Coordinate helpers

    private func displayPos(_ pos: QuoridorPosition) -> QuoridorPosition {
        flipBoard ? QuoridorPosition(row: 8 - pos.row, col: 8 - pos.col) : pos
    }

    private func center(of pos: QuoridorPosition) -> CGPoint {
        let d = displayPos(pos)
        return CGPoint(
            x: CGFloat(d.col) * slotSize + cellSize / 2,
            y: CGFloat(d.row) * slotSize + cellSize / 2)
    }

    private func wallRect(row r: Int, col c: Int, isH: Bool) -> CGRect {
        let dr = flipBoard ? 7 - r : r
        let dc = flipBoard ? 7 - c : c
        if isH {
            return CGRect(
                x: CGFloat(dc) * slotSize,
                y: CGFloat(dr + 1) * slotSize - wallGap,
                width: slotSize * 2 - wallGap,
                height: wallGap)
        } else {
            return CGRect(
                x: CGFloat(dc + 1) * slotSize - wallGap,
                y: CGFloat(dr) * slotSize,
                width: wallGap,
                height: slotSize * 2 - wallGap)
        }
    }

    // MARK: - Body

    var body: some View {
        let totalSize = CGFloat(QuoridorModel.boardSize) * slotSize - wallGap
        ZStack(alignment: .topLeading) {
            // Layer 1: Board cells + walls (Canvas)
            Canvas { ctx, _ in
                drawBoard(ctx: ctx)
                drawWalls(ctx: ctx)
                drawValidMoves(ctx: ctx)
                drawWallPreview(ctx: ctx)
            }

            // Layer 2: Animated pawns (SwiftUI, spring position)
            ForEach([PlayerColor.black, PlayerColor.white], id: \.self) { player in
                if model.positions[player] != nil {
                    QuoridorPawnView(
                        player: player,
                        isSelected: selectedPawn == model.positions[player] && player == localPlayer,
                        cellSize: cellSize
                    )
                    .frame(width: cellSize, height: cellSize)
                    .position(player == .black ? blackPos : whitePos)
                    .allowsHitTesting(false)
                }
            }

            // Layer 3: Wall glow overlay
            if let w = newWall {
                let rect = wallRect(row: w.row, col: w.col, isH: w.isH)
                RoundedRectangle(cornerRadius: wallGap / 2)
                    .fill(Color.orange.opacity(wallGlowOpacity))
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: totalSize, height: totalSize)
        .contentShape(Rectangle())
        .accessibilityLabel(Text("Quoridor board"))
        .accessibilityAddTraits(.isButton)
        .onTapGesture { location in
            if inputMode == .pawn {
                let col = Int(location.x / slotSize)
                let row = Int(location.y / slotSize)
                guard (0..<9).contains(row), (0..<9).contains(col) else { return }
                onTapCell(flipBoard ? 8 - row : row, flipBoard ? 8 - col : col)
            } else {
                let wCol = Int(location.x / slotSize)
                let wRow = Int(location.y / slotSize)
                guard (0..<8).contains(wRow), (0..<8).contains(wCol) else { return }
                onTapWallSlot(flipBoard ? 7 - wRow : wRow, flipBoard ? 7 - wCol : wCol)
            }
        }
        .onAppear {
            if let bp = model.positions[.black] { blackPos = center(of: bp) }
            if let wp = model.positions[.white] { whitePos = center(of: wp) }
        }
        .onChange(of: model.positions) { old, new in
            let bothChanged = old[.black] != new[.black] && old[.white] != new[.white]
            if bothChanged {
                // Reset — snap to new positions without animation
                if let bp = new[.black] { blackPos = center(of: bp) }
                if let wp = new[.white] { whitePos = center(of: wp) }
            } else {
                withAnimation(.spring(response: 0.24, dampingFraction: 0.65)) {
                    if let bp = new[.black] { blackPos = center(of: bp) }
                    if let wp = new[.white] { whitePos = center(of: wp) }
                }
            }
        }
        .onChange(of: model.lastMove) { _, move in
            guard let move, move.kind != .pawn else { return }
            newWall = (move.row, move.col, move.kind == .wallH)
            wallGlowOpacity = 0.75
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(80))
                withAnimation(.easeOut(duration: 0.55)) {
                    wallGlowOpacity = 0.0
                }
                try? await Task.sleep(for: .milliseconds(700))
                newWall = nil
            }
        }
    }

    // MARK: - Canvas Drawing

    private func drawBoard(ctx: GraphicsContext) {
        let cellColor = Color(red: 0.85, green: 0.73, blue: 0.54)
        let cellAlt   = Color(red: 0.80, green: 0.68, blue: 0.49)
        for row in 0..<QuoridorModel.boardSize {
            for col in 0..<QuoridorModel.boardSize {
                let rect = CGRect(
                    x: CGFloat(col) * slotSize,
                    y: CGFloat(row) * slotSize,
                    width: cellSize, height: cellSize)
                let color = (row + col) % 2 == 0 ? cellColor : cellAlt
                ctx.fill(Path(roundedRect: rect, cornerRadius: 3), with: .color(color))
                ctx.stroke(
                    Path(roundedRect: rect, cornerRadius: 3),
                    with: .color(Color.black.opacity(0.06)),
                    lineWidth: 0.5)
            }
        }
    }

    private func drawWalls(ctx: GraphicsContext) {
        let wallColor = Color(red: 0.34, green: 0.22, blue: 0.10)
        for r in 0..<8 {
            for c in 0..<8 {
                if model.hWalls[r][c] {
                    let rect = wallRect(row: r, col: c, isH: true)
                    ctx.fill(
                        Path(roundedRect: rect, cornerRadius: wallGap / 2),
                        with: .color(wallColor))
                    ctx.stroke(
                        Path(roundedRect: rect, cornerRadius: wallGap / 2),
                        with: .color(Color.black.opacity(0.20)),
                        lineWidth: 0.5)
                }
                if model.vWalls[r][c] {
                    let rect = wallRect(row: r, col: c, isH: false)
                    ctx.fill(
                        Path(roundedRect: rect, cornerRadius: wallGap / 2),
                        with: .color(wallColor))
                    ctx.stroke(
                        Path(roundedRect: rect, cornerRadius: wallGap / 2),
                        with: .color(Color.black.opacity(0.20)),
                        lineWidth: 0.5)
                }
            }
        }
    }

    private func drawValidMoves(ctx: GraphicsContext) {
        for pos in validMoves {
            let pt = center(of: pos)
            let r = cellSize * 0.24
            let outer = CGRect(x: pt.x - r, y: pt.y - r, width: r * 2, height: r * 2)
            let inner = outer.insetBy(dx: 2.5, dy: 2.5)
            ctx.fill(Path(ellipseIn: outer), with: .color(Color.accentColor.opacity(0.42)))
            ctx.fill(Path(ellipseIn: inner), with: .color(Color.accentColor.opacity(0.68)))
        }
    }

    private func drawWallPreview(ctx: GraphicsContext) {
        guard let preview = wallPreview else { return }
        let rect = wallRect(row: preview.row, col: preview.col, isH: inputMode == .wallH)
        ctx.fill(
            Path(roundedRect: rect, cornerRadius: wallGap / 2),
            with: .color(Color.yellow.opacity(0.72)))
        ctx.stroke(
            Path(roundedRect: rect, cornerRadius: wallGap / 2),
            with: .color(Color.yellow.opacity(0.90)),
            lineWidth: 1)
    }
}

// MARK: - Pawn View

private struct QuoridorPawnView: View {
    let player: PlayerColor
    let isSelected: Bool
    let cellSize: CGFloat

    private var pieceColor: Color { player == .black ? .pieceBlack : .pieceWhite }
    private var edgeColor: Color  { player == .black ? .black.opacity(0.50) : .gray.opacity(0.40) }
    private var sheenAlpha: Double { player == .black ? 0.22 : 0.82 }
    private var pad: CGFloat { cellSize * 0.10 }

    var body: some View {
        ZStack {
            // Drop shadow
            Circle()
                .fill(Color.black.opacity(0.28))
                .padding(pad)
                .offset(y: 2.5)

            // Base fill with specular gradient
            Circle()
                .fill(pieceColor)
                .overlay {
                    Circle()
                        .fill(RadialGradient(
                            colors: [Color.white.opacity(sheenAlpha), .clear],
                            center: UnitPoint(x: 0.33, y: 0.26),
                            startRadius: 0,
                            endRadius: cellSize * 0.38))
                }
                .overlay {
                    Circle().stroke(edgeColor, lineWidth: 1.5)
                }
                .padding(pad)

            // Selection ring (animates in/out with scale + opacity)
            Circle()
                .stroke(Color.accentColor, lineWidth: 2.5)
                .padding(pad - 3)
                .opacity(isSelected ? 1.0 : 0.0)
                .scaleEffect(isSelected ? 1.0 : 0.72)
                .animation(.spring(response: 0.22, dampingFraction: 0.58), value: isSelected)
        }
    }
}
