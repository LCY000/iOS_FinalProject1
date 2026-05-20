//
//  RoomView.swift
//  Final Project
//
//  Post-connection room where Host selects the game, configures rules, and starts.
//  Includes chat overlay for communication.
//
//  All session / rematch / disconnect state lives in GameSessionCoordinator —
//  this view is pure layout + wiring.
//

import SwiftUI

struct RoomView: View {
    @Bindable var multipeerManager: MultipeerManager
    @Environment(\.dismiss) private var dismiss

    @State private var session: GameSessionCoordinator
    @State private var selectedGameIndex: Int = 0
    @State private var settingsEngine: (any GameEngine)?
    @State private var showLeaveConfirmation: Bool = false
    @State private var tutorialGame: GameInfo?
    @State private var firstMoverConfig = FirstMoverConfig()
    @State private var checkmarkBounced = false

    init(multipeerManager: MultipeerManager) {
        self.multipeerManager = multipeerManager
        self._session = State(
            initialValue: GameSessionCoordinator(multipeerManager: multipeerManager)
        )
    }

    private var availableGames: [GameInfo] {
        GameRegistry.availableGames
    }

    var body: some View {
        ZStack {
            VStack(spacing: 24) {
                connectedHeader

                if multipeerManager.isHost {
                    gameSelectionSection

                    if let settingsEngine = settingsEngine {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("遊戲設定")
                                .font(.headline)
                                .padding(.horizontal, 24)

                            settingsEngine.makeSettingsView()
                        }
                    }

                    firstMoverSection
                } else {
                    waitingForHostSection
                }

                Spacer()

                if multipeerManager.isHost {
                    Button {
                        let game = availableGames[selectedGameIndex]
                        session.firstMoverConfig = firstMoverConfig
                        session.hostStartGame(game: game, settingsEngine: settingsEngine)
                    } label: {
                        Text("開始遊戲")
                    }
                    .buttonStyle(PrimaryActionButtonStyle(tint: .green))
                    .padding(.horizontal, Spacing.xl)
                    .padding(.bottom, Spacing.l)
                }
            }
            .animatedEntrance()
            .navigationTitle("遊戲房間")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showLeaveConfirmation = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("離開房間")
                        }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    if session.engine != nil && !session.gameStarted {
                        Button {
                            session.continueGame()
                        } label: {
                            Text("繼續遊戲")
                                .foregroundStyle(.green)
                                .bold()
                        }
                    }
                }
            }
            .navigationDestination(isPresented: $session.gameStarted) {
                if let engine = session.engine {
                    engine.makeGameView()
                        .overlay(alignment: .top) {
                            PeerLeftBanner(session: session)
                        }
                        .overlay(alignment: .center) {
                            RematchWaitingOverlay(session: session)
                        }
                        .overlay {
                            ChatOverlayView(chatManager: session.chatManager)
                        }
                        .alert("對手想再來一局", isPresented: Bindable(session.rematchVoting).showVoteAlert) {
                            Button("同意") { session.respondToRestart(accepted: true) }
                            Button("拒絕", role: .cancel) { session.respondToRestart(accepted: false) }
                        } message: {
                            Text("對手想重新開始這局遊戲，是否同意？")
                        }
                        .alert("對手拒絕了", isPresented: Bindable(session.rematchVoting).rejectedAlert) {
                            Button("OK", role: .cancel) {}
                        } message: {
                            Text("對手不想再來一局。")
                        }
                }
            }

            // Chat is available in the room too. When a game is active the
            // navigationDestination pushes a separate overlay so only one is
            // ever visible; the centralized toast state in ChatManager keeps
            // them in sync.
            if !session.gameStarted {
                ChatOverlayView(chatManager: session.chatManager)
            }
        }
        .onAppear {
            session.attachHandlers()
            updateSettingsEngine()
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(250))
                checkmarkBounced.toggle()
            }
        }
        .onChange(of: selectedGameIndex) { _, _ in
            updateSettingsEngine()
        }
        .onChange(of: multipeerManager.connectionState) { _, newState in
            session.handleConnectionStateChange(newState)
        }
        .alert("連線已中斷", isPresented: $session.showDisconnectAlert) {
            Button("返回大廳") {
                multipeerManager.disconnect()
                dismiss()
            }
        } message: {
            Text("與對手的連線已中斷，請返回大廳重新配對。")
        }
        .alert("無法開始遊戲", isPresented: $session.showStartGameErrorAlert) {
            Button("返回大廳") {
                multipeerManager.disconnect()
                dismiss()
            }
        } message: {
            Text(session.startGameErrorMessage)
        }
        .alert("同步錯誤", isPresented: $session.showDesyncAlert) {
            Button("返回大廳") {
                session.gameStarted = false
                dismiss()
            }
        } message: {
            Text("連線發生同步異常，請返回大廳重新配對。")
        }
        // Rematch alerts also live on RoomView so they trigger even when the
        // user is on the room screen (no game pushed yet).
        .alert("對手想再來一局", isPresented: roomLevelVoteBinding()) {
            Button("同意") { session.respondToRestart(accepted: true) }
            Button("拒絕", role: .cancel) { session.respondToRestart(accepted: false) }
        } message: {
            Text("對手想重新開始這局遊戲，是否同意？")
        }
        .alert("對手拒絕了", isPresented: roomLevelRejectedBinding()) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("對手不想再來一局。")
        }
        .confirmationDialog(
            "確認離開房間？",
            isPresented: $showLeaveConfirmation,
            titleVisibility: .visible
        ) {
            Button("離開並中斷連線", role: .destructive) {
                session.leaveRoom()
                dismiss()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("離開後會與對方中斷連線，確定嗎？")
        }
        .hapticFeedback(.connect, trigger: multipeerManager.connectionState == .connected)
        .hapticFeedback(.disconnect, trigger: session.showDisconnectAlert)
        .hapticFeedback(.disconnect, trigger: session.showDesyncAlert)
        .sheet(item: $tutorialGame) { game in
            TutorialView(game: game)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Room-Level Alert Bindings
    //
    // We want the rematch alerts to fire regardless of whether the game view
    // is pushed. But having the same `.alert(isPresented:)` attached twice
    // with the same binding would race. Instead we gate the RoomView alerts
    // so they only fire when gameStarted is false; the in-game alerts
    // (inside navigationDestination) handle the other case.

    private func roomLevelVoteBinding() -> Binding<Bool> {
        Binding(
            get: { session.rematchVoting.showVoteAlert && !session.gameStarted },
            set: { newValue in
                if !newValue && !session.gameStarted {
                    session.rematchVoting.showVoteAlert = false
                }
            }
        )
    }

    private func roomLevelRejectedBinding() -> Binding<Bool> {
        Binding(
            get: { session.rematchVoting.rejectedAlert && !session.gameStarted },
            set: { newValue in
                if !newValue && !session.gameStarted {
                    session.rematchVoting.rejectedAlert = false
                }
            }
        )
    }

    // MARK: - Connected Header

    private var connectedHeader: some View {
        VStack(spacing: Spacing.xs) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.12))
                    .frame(width: 80, height: 80)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.green)
                    .symbolEffect(.bounce, value: checkmarkBounced)
            }

            Text("已連線")
                .font(.title3.bold())

            if let peerName = multipeerManager.connectedPeerName {
                Text("對手：\(peerName)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 4) {
                Image(systemName: multipeerManager.connectionMode == .wifi ? "wifi" : "antenna.radiowaves.left.and.right")
                    .font(.caption)
                Text(multipeerManager.connectionMode.rawValue)
                    .font(.caption)
            }
            .padding(.horizontal, Spacing.s)
            .padding(.vertical, Spacing.xxs + 2)
            .background(Capsule().fill(Color.secondary.opacity(0.12)))
            .foregroundStyle(.secondary)
        }
        .padding(.top, Spacing.m)
    }

    // MARK: - Game Selection

    private func gameColor(for game: GameInfo) -> Color {
        switch game.gameType {
        case "reversi":  return .purple
        case "gomoku":   return .teal
        case "quoridor": return .blue
        case "checkers": return .orange
        default:         return .blue
        }
    }

    private var gameSelectionSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("選擇遊戲")
                .font(.headline)
                .padding(.horizontal, Spacing.l)

            ScrollView(.horizontal) {
                HStack(spacing: Spacing.s) {
                    ForEach(availableGames.enumerated(), id: \.element.id) { index, game in
                        let isSelected = selectedGameIndex == index
                        let accent = gameColor(for: game)
                        Button {
                            selectedGameIndex = index
                        } label: {
                            VStack(spacing: Spacing.xs) {
                                Image(systemName: game.icon)
                                    .font(.system(size: 28))
                                    .foregroundStyle(isSelected ? accent : .secondary)
                                Text(game.title)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(isSelected ? accent : .primary)
                            }
                            .frame(width: 108, height: 90)
                            .background(
                                RoundedRectangle(cornerRadius: Radius.m)
                                    .fill(isSelected ? accent.opacity(0.12) : Color.gray.opacity(0.08))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: Radius.m)
                                            .stroke(isSelected ? accent : Color.clear, lineWidth: 2)
                                    }
                            )
                            .animation(.spring(duration: 0.25), value: isSelected)
                            .overlay(alignment: .topTrailing) {
                                Button {
                                    tutorialGame = game
                                } label: {
                                    Image(systemName: "info.circle")
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                        .padding(Spacing.xs)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("\(game.title) 規則說明")
                            }
                        }
                    }
                }
                .padding(.horizontal, Spacing.l)
            }
            .scrollIndicators(.hidden)
        }
    }

    // MARK: - Guest Waiting

    private var waitingForHostSection: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            Text("等待房主選擇遊戲並開始…")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 40)
    }

    // MARK: - First Mover

    private var firstMoverSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("先後手")
                .font(.headline)
                .padding(.horizontal, Spacing.xl)

            VStack(spacing: Spacing.xs) {
                HStack {
                    Text("誰先手")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Picker("誰先手", selection: $firstMoverConfig.initial) {
                        Text("主機先").tag(FirstMoverInitial.host)
                        Text("對手先").tag(FirstMoverInitial.guest)
                        Text("隨機").tag(FirstMoverInitial.random)
                    }
                    .pickerStyle(.menu)
                }
                Divider()
                HStack {
                    Text("再來一局")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Picker("輪替", selection: $firstMoverConfig.onRematch) {
                        Text("固定先後").tag(RematchRotation.fixed)
                        Text("輪流互換").tag(RematchRotation.alternate)
                        Text("每局隨機").tag(RematchRotation.random)
                    }
                    .pickerStyle(.menu)
                }
            }
            .padding(Spacing.m)
            .card(radius: Radius.m, elevation: .low, padding: 0)
            .padding(.horizontal, Spacing.l)
        }
    }

    // MARK: - Settings Engine

    private func updateSettingsEngine() {
        let game = availableGames[selectedGameIndex]
        settingsEngine = game.createEngine()
    }
}

#Preview {
    NavigationStack {
        RoomView(multipeerManager: MultipeerManager())
    }
}
