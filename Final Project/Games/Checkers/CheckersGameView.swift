import SwiftUI

struct CheckersGameView: View {
    @Bindable var engine: CheckersEngine
    @Environment(\.dismiss) private var dismiss

    private var flipBoard: Bool {
        engine.isMultiplayer && engine.localPlayer == .black
    }

    private var isLocalWinner: Bool {
        guard let w = engine.model.winner else { return false }
        return engine.isMultiplayer ? w == engine.localPlayer : true
    }

    private var blackPlayerName: String {
        guard engine.isMultiplayer else { return "黑方" }
        return engine.localPlayer == .black
            ? PlayerNameProvider.broadcastName
            : (engine.opponentName ?? "對手")
    }

    private var whitePlayerName: String {
        guard engine.isMultiplayer else { return "白方" }
        return engine.localPlayer == .white
            ? PlayerNameProvider.broadcastName
            : (engine.opponentName ?? "對手")
    }

    var body: some View {
        VStack(spacing: Spacing.s) {
            scoreBar

            Text(engine.statusMessage)
                .font(.headline)
                .foregroundStyle(engine.isGameOver ? .orange : .primary)
                .animation(.easeInOut, value: engine.statusMessage)

            ScrollView([.horizontal, .vertical]) {
                CheckersBoardCanvas(
                    board: engine.board,
                    flipBoard: flipBoard,
                    validDestinations: engine.validDestinations,
                    selectedFrom: engine.selectedFrom,
                    lastMoveInfo: engine.lastMoveInfo,
                    onTap: { r, c in engine.handleTap(row: r, col: c) }
                )
                .clipShape(RoundedRectangle(cornerRadius: Radius.s))
                .shadow(color: .black.opacity(0.40), radius: 10, x: 0, y: 5)
                .padding(Spacing.s)
            }
            .scrollIndicators(.hidden)
            .frame(maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: Radius.m)
                    .fill(Color.black.opacity(0.07))
            )

            bottomBar
                .padding(.horizontal, Spacing.m)
                .padding(.bottom, Spacing.xs)
        }
        .padding(.top)
        .animatedEntrance()
        .navigationTitle("西洋跳棋")
        .navigationBarTitleDisplayMode(.inline)
        .hapticFeedback(.selection, trigger: engine.selectedFrom?.row ?? -1)
        .hapticFeedback(.confirm, trigger: engine.model.currentPlayer == .black ? 0 : 1)
        .hapticFeedback(.opponentMove, trigger: engine.expectedRecvSeq)
        .hapticFeedback(.win, trigger: engine.isGameOver)
        .onChange(of: engine.isGameOver) { _, over in
            if over { SoundManager.shared.play(.gameOver) }
        }
        .overlay {
            if engine.isGameOver {
                GameResultOverlay(
                    isWinner: isLocalWinner,
                    isDraw: false,
                    winnerLabel: engine.isMultiplayer
                        ? (engine.model.winner == engine.localPlayer
                            ? PlayerNameProvider.broadcastName
                            : (engine.opponentName ?? "對手"))
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
            pieceCountCell(
                pieceColor: .pieceBlack, strokeColor: .pieceWhite,
                score: engine.scores.black,
                isActive: engine.currentPlayer == .black,
                activeFill: Color.primary.opacity(0.12),
                name: blackPlayerName
            )

            Text("vs").font(.appCaption).foregroundStyle(.secondary)

            pieceCountCell(
                pieceColor: .pieceWhite, strokeColor: .gray,
                score: engine.scores.white,
                isActive: engine.currentPlayer == .white,
                activeFill: Color.gray.opacity(0.15),
                name: whitePlayerName
            )
        }
    }

    private func pieceCountCell(
        pieceColor: Color, strokeColor: Color,
        score: Int, isActive: Bool, activeFill: Color,
        name: String
    ) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: Spacing.xs) {
                Circle()
                    .fill(pieceColor)
                    .stroke(strokeColor, lineWidth: 1)
                    .frame(width: 22, height: 22)
                Text("\(score)")
                    .font(.appNumber)
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, Spacing.xs)
            .background(Capsule().fill(isActive ? activeFill : .clear))
            .animation(.spring(duration: 0.3), value: engine.currentPlayer)

            Text(name)
                .font(.appCaption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(maxWidth: 100)
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
            } else if engine.selectedFrom != nil {
                Button { engine.cancelMove() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("取消選擇")
                .transition(.scale.combined(with: .opacity))
            }
            Spacer()
        }
        .animation(.spring(duration: 0.2), value: engine.selectedFrom != nil || engine.isGameOver)
        .frame(height: 36)
    }
}

#Preview {
    NavigationStack { CheckersGameView(engine: CheckersEngine()) }
}
