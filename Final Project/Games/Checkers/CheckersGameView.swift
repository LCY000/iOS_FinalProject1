import SwiftUI

struct CheckersGameView: View {
    @Bindable var engine: CheckersEngine
    @Environment(\.dismiss) private var dismiss

    @State private var displayBoard: [[CheckersPiece]] = []
    @State private var animating = false

    private var flipBoard: Bool {
        engine.isMultiplayer && engine.localPlayer == .white
    }

    private var isLocalWinner: Bool {
        guard let w = engine.model.winner else { return false }
        return engine.isMultiplayer ? w == engine.localPlayer : true
    }

    var body: some View {
        VStack(spacing: Spacing.s) {
            scoreBar

            Text(engine.statusMessage)
                .font(.headline)
                .foregroundStyle(engine.isGameOver ? .orange : .primary)

            ScrollView([.horizontal, .vertical]) {
                CheckersBoardCanvas(
                    board: displayBoard.isEmpty ? engine.board : displayBoard,
                    flipBoard: flipBoard,
                    validDestinations: animating ? [] : engine.validDestinations,
                    selectedFrom: animating ? nil : engine.selectedFrom,
                    onTap: { r, c in
                        guard !animating else { return }
                        engine.handleTap(row: r, col: c)
                    }
                )
                .padding(Spacing.s)
            }
            .scrollIndicators(.hidden)
            .frame(maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: Radius.m))

            bottomBar
                .padding(.horizontal, Spacing.m)
                .padding(.bottom, Spacing.xs)
        }
        .padding(.top)
        .animatedEntrance()
        .navigationTitle("西洋跳棋")
        .navigationBarTitleDisplayMode(.inline)
        .hapticFeedback(.win, trigger: engine.isGameOver)
        .onChange(of: engine.isGameOver) { _, over in
            if over { SoundManager.shared.play(.gameOver) }
        }
        .onAppear { displayBoard = engine.board }
        .onChange(of: engine.board) { _, newBoard in
            if !animating { displayBoard = newBoard }
        }
        .overlay {
            if engine.isGameOver {
                GameResultOverlay(
                    isWinner: isLocalWinner,
                    isDraw: false,
                    winnerLabel: engine.isMultiplayer
                        ? (engine.model.winner == engine.localPlayer ? "你" : "對手")
                        : (engine.model.winner?.displayName ?? ""),
                    blackScore: engine.scores.black,
                    whiteScore: engine.scores.white,
                    onRematch: {
                        if engine.isMultiplayer { engine.onRestartRequested?() } else { engine.reset() }
                    },
                    onLeave: { dismiss() }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: engine.isGameOver)
    }

    // MARK: - Score Bar

    private var scoreBar: some View {
        HStack(spacing: Spacing.l) {
            HStack(spacing: Spacing.xs) {
                Circle()
                    .fill(Color.pieceBlack)
                    .frame(width: 22, height: 22)
                Text("\(engine.scores.black)").font(.appNumber)
            }
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, Spacing.xs)
            .background(
                Capsule().fill(engine.currentPlayer == .black
                    ? Color.primary.opacity(0.12) : Color.clear)
            )

            Text("vs").font(.appCaption).foregroundStyle(.secondary)

            HStack(spacing: Spacing.xs) {
                Circle()
                    .fill(Color.pieceWhite)
                    .stroke(Color.gray, lineWidth: 1)
                    .frame(width: 22, height: 22)
                Text("\(engine.scores.white)").font(.appNumber)
            }
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, Spacing.xs)
            .background(
                Capsule().fill(engine.currentPlayer == .white
                    ? Color.gray.opacity(0.15) : Color.clear)
            )
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack {
            if engine.isGameOver {
                Button {
                    if engine.isMultiplayer { engine.onRestartRequested?() } else { engine.reset() }
                } label: {
                    Label("再來一局", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(PillButtonStyle(tint: .green))
            }
            Spacer()
        }
        .frame(height: 36)
    }
}

#Preview {
    NavigationStack { CheckersGameView(engine: CheckersEngine()) }
}
