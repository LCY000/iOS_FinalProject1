import SwiftUI

struct QuoridorGameView: View {
    @Bindable var engine: QuoridorEngine
    @Environment(\.dismiss) private var dismiss

    private var flipBoard: Bool {
        engine.isMultiplayer && engine.localPlayer == .white
    }

    private var isLocalWinner: Bool {
        guard let w = engine.model.winner else { return false }
        return engine.isMultiplayer ? w == engine.localPlayer : true
    }

    var body: some View {
        VStack(spacing: Spacing.s) {
            wallCountBar

            Text(engine.statusMessage)
                .font(.headline)
                .foregroundStyle(engine.isGameOver ? .orange : .primary)
                .animation(.easeInOut, value: engine.statusMessage)

            ScrollView([.horizontal, .vertical]) {
                QuoridorBoardCanvas(
                    model: engine.model,
                    localPlayer: engine.localPlayer,
                    flipBoard: flipBoard,
                    inputMode: engine.inputMode,
                    selectedPawn: engine.selectedPawn,
                    validMoves: engine.inputMode == .pawn
                        ? engine.model.validPawnMoves(for: engine.currentPlayer) : [],
                    wallPreview: engine.wallPreview,
                    onTapCell: { r, c in engine.handleTap(row: r, col: c) },
                    onTapWallSlot: { r, c in engine.handleWallTap(row: r, col: c) }
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

            modeBar
                .padding(.horizontal, Spacing.m)
                .padding(.bottom, Spacing.xs)
        }
        .padding(.top)
        .animatedEntrance()
        .navigationTitle("步步為營")
        .navigationBarTitleDisplayMode(.inline)
        .hapticFeedback(.selection, trigger: engine.selectedPawn?.row ?? -1)
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
                        ? (engine.model.winner == engine.localPlayer ? "你" : "對手")
                        : (engine.model.winner?.displayName ?? ""),
                    blackScore: 0,
                    whiteScore: 0,
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

    // MARK: - Wall Count Bar

    private var wallCountBar: some View {
        HStack(spacing: Spacing.l) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "square.fill")
                    .foregroundStyle(Color.pieceBlack)
                Text("牆 \(engine.model.wallCounts[.black, default: 0])")
                    .font(.appNumber)
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, Spacing.xs)
            .background(
                Capsule().fill(engine.model.currentPlayer == .black
                    ? Color.primary.opacity(0.12) : Color.clear)
            )
            .animation(.spring(duration: 0.3), value: engine.model.currentPlayer)

            Text("vs").font(.appCaption).foregroundStyle(.secondary)

            HStack(spacing: Spacing.xs) {
                Image(systemName: "square.fill")
                    .foregroundStyle(Color.pieceWhite)
                Text("牆 \(engine.model.wallCounts[.white, default: 0])")
                    .font(.appNumber)
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, Spacing.xs)
            .background(
                Capsule().fill(engine.model.currentPlayer == .white
                    ? Color.gray.opacity(0.15) : Color.clear)
            )
            .animation(.spring(duration: 0.3), value: engine.model.currentPlayer)
        }
    }

    // MARK: - Mode Bar

    private var modeBar: some View {
        HStack {
            Picker("模式", selection: $engine.inputMode) {
                Text("移動").tag(QuoridorInputMode.pawn)
                Text("橫牆").tag(QuoridorInputMode.wallH)
                Text("縱牆").tag(QuoridorInputMode.wallV)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 200)
            .disabled(engine.isGameOver ||
                      (engine.isMultiplayer && engine.currentPlayer != engine.localPlayer) ||
                      engine.model.wallCounts[engine.currentPlayer, default: 0] == 0)

            Spacer()

            if engine.isGameOver {
                Button {
                    if engine.isMultiplayer { engine.onRestartRequested?() } else { engine.reset() }
                } label: {
                    Label("再來一局", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(PillButtonStyle(tint: .green))
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.2), value: engine.isGameOver)
        .frame(height: 36)
    }
}

#Preview {
    NavigationStack { QuoridorGameView(engine: QuoridorEngine()) }
}
