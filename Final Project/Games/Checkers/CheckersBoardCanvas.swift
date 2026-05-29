import SwiftUI

// MARK: - Per-piece animation state (view-layer only)

private struct AnimatedPiece: Identifiable {
    let id: Int
    var row: Int
    var col: Int
    var owner: PlayerColor
    var isKing: Bool
    var scale: CGFloat = 1.0
    var opacity: Double = 1.0
}

// MARK: - Board View

struct CheckersBoardCanvas: View {
    let board: [[CheckersPiece]]
    let flipBoard: Bool
    let validDestinations: [CheckersPosition]
    let selectedFrom: CheckersPosition?
    let lastMoveInfo: CheckersMoveInfo?
    let forcedCaptureSources: [CheckersPosition]
    let onTap: (Int, Int) -> Void

    @State private var pieces: [AnimatedPiece] = []
    @State private var promotingIDs: Set<Int> = []

    private var boardSize: Int { board.count }
    private var cellSize: CGFloat { boardSize == 10 ? 36 : 44 }

    private static let lightCell = Color(red: 0.957, green: 0.855, blue: 0.694)
    private static let darkCell  = Color(red: 0.52,  green: 0.26,  blue: 0.07)

    var body: some View {
        let total = CGFloat(boardSize) * cellSize
        ZStack(alignment: .topLeading) {
            // Layer 1: Board cells and move-hint highlights
            Canvas { ctx, _ in
                drawCells(ctx: ctx)
                drawHighlights(ctx: ctx)
            }

            // Layer 2: Animated pieces (SwiftUI views, enables spring position animation)
            ForEach(pieces) { p in
                CheckersPieceView(
                    owner: p.owner,
                    isKing: p.isKing,
                    cellSize: cellSize,
                    isPromoting: promotingIDs.contains(p.id)
                )
                .frame(width: cellSize, height: cellSize)
                .scaleEffect(p.scale)
                .opacity(p.opacity)
                .position(pieceCenter(row: p.row, col: p.col))
                .allowsHitTesting(false)
            }
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
            guard (0..<boardSize).contains(row), (0..<boardSize).contains(col) else { return }
            onTap(row, col)
        }
        .onAppear { syncFromBoard(board) }
        .onChange(of: board) { _, newBoard in
            if let move = lastMoveInfo {
                animateMove(move)
            } else {
                syncFromBoard(newBoard)
            }
        }
    }

    // MARK: - Canvas Drawing (cells + highlights only)

    private func drawCells(ctx: GraphicsContext) {
        for r in 0..<boardSize {
            for c in 0..<boardSize {
                let isDark = (r + c) % 2 == 1
                let rect = CGRect(
                    x: CGFloat(c) * cellSize, y: CGFloat(r) * cellSize,
                    width: cellSize, height: cellSize)
                ctx.fill(Path(rect), with: .color(isDark ? Self.darkCell : Self.lightCell))
                if isDark {
                    ctx.stroke(Path(rect), with: .color(.black.opacity(0.06)), lineWidth: 0.5)
                }
            }
        }
    }

    private func drawHighlights(ctx: GraphicsContext) {
        // Orange ring on pieces that MUST capture (shown only when nothing is selected)
        if selectedFrom == nil {
            for pos in forcedCaptureSources {
                let d = flipped(pos)
                let cx = CGFloat(d.col) * cellSize + cellSize / 2
                let cy = CGFloat(d.row) * cellSize + cellSize / 2
                let r = cellSize * 0.43
                let rect = CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)
                ctx.stroke(Path(ellipseIn: rect),
                           with: .color(Color.orange.opacity(0.90)), lineWidth: 2.5)
            }
        }

        if let sel = selectedFrom {
            let d = flipped(sel)
            let rect = CGRect(
                x: CGFloat(d.col) * cellSize, y: CGFloat(d.row) * cellSize,
                width: cellSize, height: cellSize)
            ctx.fill(Path(rect), with: .color(Color.yellow.opacity(0.46)))
            ctx.stroke(Path(rect.insetBy(dx: 1.5, dy: 1.5)),
                       with: .color(Color.yellow.opacity(0.75)), lineWidth: 2)
        }
        for pos in validDestinations {
            let d = flipped(pos)
            let cx = CGFloat(d.col) * cellSize + cellSize / 2
            let cy = CGFloat(d.row) * cellSize + cellSize / 2
            let r = cellSize * 0.24
            let outer = CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)
            let inner = outer.insetBy(dx: 2.5, dy: 2.5)
            ctx.fill(Path(ellipseIn: outer), with: .color(Color.green.opacity(0.62)))
            ctx.fill(Path(ellipseIn: inner), with: .color(Color.green.opacity(0.88)))
        }
    }

    // MARK: - Coordinate helpers

    private func flipped(_ pos: CheckersPosition) -> CheckersPosition {
        flipBoard
            ? CheckersPosition(row: boardSize - 1 - pos.row, col: boardSize - 1 - pos.col)
            : pos
    }

    private func pieceCenter(row: Int, col: Int) -> CGPoint {
        let dr = flipBoard ? boardSize - 1 - row : row
        let dc = flipBoard ? boardSize - 1 - col : col
        return CGPoint(x: CGFloat(dc) * cellSize + cellSize / 2,
                       y: CGFloat(dr) * cellSize + cellSize / 2)
    }

    // MARK: - Piece state sync

    private func syncFromBoard(_ b: [[CheckersPiece]]) {
        var result: [AnimatedPiece] = []
        var id = 0
        for r in 0..<b.count {
            for c in 0..<b[r].count {
                if let owner = b[r][c].owner {
                    result.append(AnimatedPiece(
                        id: id, row: r, col: c,
                        owner: owner, isKing: b[r][c].isKing))
                    id += 1
                }
            }
        }
        pieces = result
        promotingIDs = []
    }

    // MARK: - Move animation

    private func animateMove(_ move: CheckersMoveInfo) {
        let steps = move.path.count - 1
        guard steps > 0 else { return }
        Task { @MainActor in
            for i in 0..<steps {
                let fromPos = move.path[i]
                let toPos   = move.path[i + 1]
                withAnimation(.spring(response: 0.26, dampingFraction: 0.72)) {
                    if let idx = pieces.firstIndex(where: { $0.row == fromPos.row && $0.col == fromPos.col }) {
                        pieces[idx].row = toPos.row
                        pieces[idx].col = toPos.col
                    }
                }
                if i < move.captures.count {
                    let cap = move.captures[i]
                    withAnimation(.easeOut(duration: 0.16).delay(0.05)) {
                        if let idx = pieces.firstIndex(where: { $0.row == cap.row && $0.col == cap.col }) {
                            pieces[idx].scale   = 0.05
                            pieces[idx].opacity = 0.0
                        }
                    }
                }
                try? await Task.sleep(for: .milliseconds(290))
            }
            // Promotion glow after last jump
            if move.promoted {
                if let idx = pieces.firstIndex(where: { $0.row == move.to.row && $0.col == move.to.col }) {
                    pieces[idx].isKing = true
                    SoundManager.shared.play(.promote)
                    let pid = pieces[idx].id
                    promotingIDs.insert(pid)
                    try? await Task.sleep(for: .milliseconds(900))
                    promotingIDs.remove(pid)
                }
            }
            try? await Task.sleep(for: .milliseconds(120))
            pieces.removeAll { $0.scale < 0.5 }
        }
    }
}

// MARK: - Piece Shape View

private struct CheckersPieceView: View {
    let owner: PlayerColor
    let isKing: Bool
    let cellSize: CGFloat
    let isPromoting: Bool

    private var pieceColor: Color { owner == .black ? .pieceBlack : .pieceWhite }
    private var edgeColor: Color  { owner == .black ? .black.opacity(0.50) : .gray.opacity(0.40) }
    private var sheenAlpha: Double { owner == .black ? 0.22 : 0.82 }
    private var pad: CGFloat { cellSize * 0.095 }

    var body: some View {
        ZStack {
            // Drop shadow
            Circle()
                .fill(Color.black.opacity(0.30))
                .padding(pad)
                .offset(y: 2.5)

            // Base fill with top-left specular sheen
            Circle()
                .fill(pieceColor)
                .overlay {
                    Circle()
                        .fill(RadialGradient(
                            colors: [Color.white.opacity(sheenAlpha), .clear],
                            center: UnitPoint(x: 0.33, y: 0.26),
                            startRadius: 0,
                            endRadius: cellSize * 0.40))
                }
                .overlay {
                    Circle().stroke(edgeColor, lineWidth: 1.5)
                }
                .padding(pad)

            // King decoration
            if isKing {
                Circle()
                    .stroke(Color.kingCrown, lineWidth: 2.5)
                    .padding(pad)
                    .scaleEffect(isPromoting ? 1.14 : 1.0)
                    .animation(
                        isPromoting
                            ? .spring(response: 0.22, dampingFraction: 0.38).repeatCount(4)
                            : .default,
                        value: isPromoting)

                Image(systemName: "crown.fill")
                    .font(.system(size: max(8, cellSize * 0.27)))
                    .foregroundStyle(Color.kingCrown)
                    .shadow(color: Color.kingCrown.opacity(isPromoting ? 1.0 : 0.55), radius: isPromoting ? 7 : 2)
                    .scaleEffect(isPromoting ? 1.16 : 1.0)
                    .animation(
                        isPromoting
                            ? .spring(response: 0.22, dampingFraction: 0.38).repeatCount(4)
                            : .default,
                        value: isPromoting)
            }
        }
    }
}
