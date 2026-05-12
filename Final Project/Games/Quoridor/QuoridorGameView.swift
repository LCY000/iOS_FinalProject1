import SwiftUI

struct QuoridorGameView: View {
    @Bindable var engine: QuoridorEngine
    @Environment(\.dismiss) private var dismiss

    // Perspective: guest sees board flipped 180°
    private var flipBoard: Bool {
        engine.isMultiplayer && engine.localPlayer == .white
    }

    private var isLocalWinner: Bool {
        guard let w = engine.model.winner else { return false }
        return engine.isMultiplayer ? w == engine.localPlayer : true
    }

    var body: some View {
        VStack(spacing: 12) {
            wallCountBar

            Text(engine.statusMessage)
                .font(.headline)
                .foregroundStyle(engine.isGameOver ? .orange : .primary)

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
                .padding(12)
            }
            .scrollIndicators(.hidden)
            .frame(maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            modeBar
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
        }
        .padding(.top)
        .animatedEntrance()
        .navigationTitle("步步為營")
        .navigationBarTitleDisplayMode(.inline)
        .hapticFeedback(.selection, trigger: engine.selectedPawn?.row ?? -1)
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
            }
            Text("vs").font(.appCaption).foregroundStyle(.secondary)
            HStack(spacing: Spacing.xs) {
                Image(systemName: "square.fill")
                    .foregroundStyle(Color.pieceWhite)
                Text("牆 \(engine.model.wallCounts[.white, default: 0])")
                    .font(.appNumber)
            }
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
            }
        }
        .frame(height: 36)
    }
}

#Preview {
    NavigationStack { QuoridorGameView(engine: QuoridorEngine()) }
}
