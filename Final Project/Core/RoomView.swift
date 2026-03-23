//
//  RoomView.swift
//  Final Project
//
//  Post-connection room where Host selects the game, configures rules, and starts.
//  Includes chat overlay for communication.
//

import SwiftUI

struct RoomView: View {
    @Bindable var multipeerManager: MultipeerManager

    @State private var selectedGameIndex: Int = 0
    @State private var gameStarted = false
    @State private var engine: (any GameEngine)?
    @State private var showDisconnectAlert = false
    @State private var chatManager = ChatManager()

    // Create a temporary engine for settings preview
    @State private var settingsEngine: (any GameEngine)?

    private var availableGames: [GameInfo] {
        GameRegistry.availableGames
    }

    var body: some View {
        ZStack {
            VStack(spacing: 24) {
                // MARK: - Connected Info
                connectedHeader

                // MARK: - Game Selection (Host only)
                if multipeerManager.isHost {
                    gameSelectionSection

                    // MARK: - Game Settings
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

                // MARK: - Start Button (Host only)
                if multipeerManager.isHost {
                    Button {
                        startGame()
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
            .navigationTitle("遊戲房間")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        multipeerManager.disconnect()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("離開房間")
                        }
                    }
                }
            }
            .navigationDestination(isPresented: $gameStarted) {
                if let engine = engine {
                    engine.makeGameView()
                        .overlay(
                            ChatOverlayView(chatManager: chatManager)
                        )
                        .onDisappear {
                            engine.onMoveToSend = nil
                        }
                }
            }

            // MARK: - Chat Overlay (available in room too)
            ChatOverlayView(chatManager: chatManager)
        }
        .onAppear {
            setupCallbacks()
            updateSettingsEngine()
        }
        .onChange(of: selectedGameIndex) { _, _ in
            updateSettingsEngine()
        }
        .onChange(of: multipeerManager.connectionState) { _, newState in
            if newState == .disconnected || newState == .notConnected {
                if !gameStarted {
                    showDisconnectAlert = true
                }
            }
        }
        .alert("連線已中斷", isPresented: $showDisconnectAlert) {
            Button("返回大廳") {
                multipeerManager.disconnect()
            }
        } message: {
            Text("與對手的連線已中斷，請返回大廳重新配對。")
        }
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
                Text("對手：\(peerName)")
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

    // MARK: - Actions

    private func startGame() {
        let selectedGame = availableGames[selectedGameIndex]
        let newEngine: any GameEngine

        // Use settings from the settingsEngine if it exists
        if let se = settingsEngine {
            newEngine = se
        } else {
            newEngine = selectedGame.createEngine()
        }

        newEngine.isMultiplayer = true
        newEngine.localPlayer = .black

        // Wire networking
        newEngine.onMoveToSend = { [weak multipeerManager] envelope in
            multipeerManager?.send(envelope: envelope)
        }

        self.engine = newEngine
        gameStarted = true

        // Send startGame envelope with settings to peer
        let settingsData = newEngine.exportSettings()
        let startInfo = StartGamePayload(
            gameType: selectedGame.gameType,
            settings: settingsData
        )
        let startPayload = try! JSONEncoder().encode(startInfo)
        let envelope = MessageEnvelope(
            type: .startGame,
            gameType: selectedGame.gameType,
            payload: startPayload
        )
        multipeerManager.send(envelope: envelope)

        // Re-wire envelope handler for game moves (host side)
        multipeerManager.onEnvelopeReceived = { [weak newEngine, weak chatManager] envelope in
            switch envelope.type {
            case .playerMove:
                newEngine?.receiveRemoteMove(data: envelope.payload)
            case .chat:
                chatManager?.receiveEnvelope(envelope)
            default:
                break
            }
        }
    }

    private func setupCallbacks() {
        // Wire chat sending
        chatManager.onSendEnvelope = { [weak multipeerManager] envelope in
            multipeerManager?.send(envelope: envelope)
        }

        multipeerManager.onEnvelopeReceived = { envelope in
            switch envelope.type {
            case .startGame:
                // Guest receives startGame — create engine with settings
                if let startInfo = try? JSONDecoder().decode(StartGamePayload.self, from: envelope.payload),
                   let game = availableGames.first(where: { $0.gameType == startInfo.gameType }) {

                    let newEngine = game.createEngine()
                    newEngine.applySettings(data: startInfo.settings)
                    newEngine.isMultiplayer = true
                    newEngine.localPlayer = .white

                    newEngine.onMoveToSend = { [weak multipeerManager] envelope in
                        multipeerManager?.send(envelope: envelope)
                    }

                    self.engine = newEngine
                    self.gameStarted = true

                    self.multipeerManager.onEnvelopeReceived = { [weak newEngine, weak chatManager] envelope in
                        switch envelope.type {
                        case .playerMove:
                            newEngine?.receiveRemoteMove(data: envelope.payload)
                        case .chat:
                            chatManager?.receiveEnvelope(envelope)
                        default:
                            break
                        }
                    }
                }

            case .chat:
                chatManager.receiveEnvelope(envelope)

            case .playerMove:
                engine?.receiveRemoteMove(data: envelope.payload)

            default:
                break
            }
        }

        multipeerManager.onDisconnected = {
            showDisconnectAlert = true
        }
    }
}

// MARK: - Start Game Payload

struct StartGamePayload: Codable {
    let gameType: String
    let settings: Data
}

#Preview {
    NavigationStack {
        RoomView(multipeerManager: MultipeerManager())
    }
}
