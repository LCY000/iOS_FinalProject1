import SwiftUI

struct QuoridorGameView: View {
    @Bindable var engine: QuoridorEngine
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
                    validMoves: engine.inputMode == .pawn ? engine.cachedValidPawnMoves : [],
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
                        ? (engine.model.winner == engine.localPlayer
                            ? PlayerNameProvider.broadcastName
                            : (engine.opponentName ?? "對手"))
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
            wallCell(
                isBlack: true,
                wallCount: engine.model.wallCounts[.black, default: 0],
                isActive: engine.model.currentPlayer == .black,
                activeFill: Color.primary.opacity(0.12),
                name: blackPlayerName
            )

            Text("vs").font(.appCaption).foregroundStyle(.secondary)

            wallCell(
                isBlack: false,
                wallCount: engine.model.wallCounts[.white, default: 0],
                isActive: engine.model.currentPlayer == .white,
                activeFill: Color.gray.opacity(0.15),
                name: whitePlayerName
            )
        }
    }

    private func wallCell(
        isBlack: Bool, wallCount: Int,
        isActive: Bool, activeFill: Color, name: String
    ) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: Spacing.xs) {
                // Wall icon — use outlined+filled for white so it's visible on light backgrounds
                ZStack {
                    Image(systemName: "square.fill")
                        .foregroundStyle(isBlack ? Color.pieceBlack : Color.pieceWhite)
                    if !isBlack {
                        Image(systemName: "square")
                            .foregroundStyle(Color.gray.opacity(0.5))
                    }
                }
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text("\(wallCount)")
                        .font(.appNumber)
                        .contentTransition(.numericText())
                    Text("牆")
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, Spacing.xs)
            .background(Capsule().fill(isActive ? activeFill : .clear))
            .animation(.spring(duration: 0.3), value: engine.model.currentPlayer)

            Text(name)
                .font(.appCaption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(maxWidth: 100)
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
                      engine.pendingWall != nil ||
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
            } else if engine.pendingWall != nil {
                HStack(spacing: Spacing.s) {
                    Button { engine.cancelMove() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.red)
                    }
                    .accessibilityLabel("取消放牆")

                    Button { engine.confirmMove() } label: {
                        Label("確認放牆", systemImage: "checkmark")
                    }
                    .buttonStyle(PillButtonStyle(tint: .green))
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.2), value: engine.isGameOver || engine.pendingWall != nil)
        .frame(height: 36)
    }
}

#Preview {
    NavigationStack { QuoridorGameView(engine: QuoridorEngine()) }
}
