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
                } else {
                    waitingForHostSection
                }

                Spacer()

                if multipeerManager.isHost {
                    Button {
                        let game = availableGames[selectedGameIndex]
                        session.hostStartGame(game: game, settingsEngine: settingsEngine)
                    } label: {
                        Text("開始遊戲")
                            .font(.title2.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.green)
                            )
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 20)
                }
            }
            .animatedEntrance()
            .navigationTitle("遊戲房間")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showLeaveConfirmation = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("離開房間")
                        }
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
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
                        .overlay(
                            ChatOverlayView(chatManager: session.chatManager)
                        )
                        .alert("對手想再來一局", isPresented: $session.showRestartVoteAlert) {
                            Button("同意") { session.respondToRestart(accepted: true) }
                            Button("拒絕", role: .cancel) { session.respondToRestart(accepted: false) }
                        } message: {
                            Text("對手想重新開始這局遊戲，是否同意？")
                        }
                        .alert("對手拒絕了", isPresented: $session.restartRejectedAlert) {
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
        // Rematch alerts also live on RoomView so they trigger even when the
        // user is on the room screen (no game pushed yet).
        .alert("對手想再來一局", isPresented: roomLevelRestartVoteBinding()) {
            Button("同意") { session.respondToRestart(accepted: true) }
            Button("拒絕", role: .cancel) { session.respondToRestart(accepted: false) }
        } message: {
            Text("對手想重新開始這局遊戲，是否同意？")
        }
        .alert("對手拒絕了", isPresented: roomLevelRestartRejectedBinding()) {
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
    }

    // MARK: - Room-Level Alert Bindings
    //
    // We want the rematch alerts to fire regardless of whether the game view
    // is pushed. But having the same `.alert(isPresented:)` attached twice
    // with the same binding would race. Instead we gate the RoomView alerts
    // so they only fire when gameStarted is false; the in-game alerts
    // (inside navigationDestination) handle the other case.

    private func roomLevelRestartVoteBinding() -> Binding<Bool> {
        Binding(
            get: { session.showRestartVoteAlert && !session.gameStarted },
            set: { newValue in
                if !newValue && !session.gameStarted {
                    session.showRestartVoteAlert = false
                }
            }
        )
    }

    private func roomLevelRestartRejectedBinding() -> Binding<Bool> {
        Binding(
            get: { session.restartRejectedAlert && !session.gameStarted },
            set: { newValue in
                if !newValue && !session.gameStarted {
                    session.restartRejectedAlert = false
                }
            }
        )
    }

    // MARK: - Connected Header

    private var connectedHeader: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.green)

            Text("已連線")
                .font(.headline)

            if let peerName = multipeerManager.connectedPeerName {
                Text("對手:\(peerName)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 20)
    }

    // MARK: - Game Selection

    private var gameSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("選擇遊戲")
                .font(.headline)
                .padding(.horizontal, 24)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(availableGames.enumerated()), id: \.element.id) { index, game in
                        Button {
                            selectedGameIndex = index
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: game.icon)
                                    .font(.system(size: 28))
                                Text(game.title)
                                    .font(.subheadline.bold())
                            }
                            .frame(width: 100, height: 90)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(selectedGameIndex == index
                                          ? Color.blue.opacity(0.15)
                                          : Color.gray.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(selectedGameIndex == index
                                                    ? Color.blue : Color.clear,
                                                    lineWidth: 2)
                                    )
                            )
                        }
                        .foregroundStyle(selectedGameIndex == index ? .blue : .primary)
                    }
                }
                .padding(.horizontal, 24)
            }
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

    // MARK: - Settings Engine

    private func updateSettingsEngine() {
        let game = availableGames[selectedGameIndex]
        settingsEngine = game.createEngine()
    }
}

// MARK: - Peer Left Banner (in-game, non-blocking)

private struct PeerLeftBanner: View {
    @Bindable var session: GameSessionCoordinator

    var body: some View {
        if session.showPeerLeftBanner {
            HStack(spacing: 8) {
                Image(systemName: "person.slash.fill")
                    .foregroundStyle(.orange)
                Text("對方已離開房間")
                    .font(.subheadline.bold())
                Spacer(minLength: 8)
                Button {
                    session.showPeerLeftBanner = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
            )
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

// MARK: - Rematch Waiting Overlay

private struct RematchWaitingOverlay: View {
    @Bindable var session: GameSessionCoordinator

    var body: some View {
        if session.waitingForRestartResponse {
            VStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(1.2)
                Text("等待對手回應…")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.2), radius: 12)
            )
            .transition(.scale.combined(with: .opacity))
        }
    }
}

#Preview {
    NavigationStack {
        RoomView(multipeerManager: MultipeerManager())
    }
}
