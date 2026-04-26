//
//  ContentView.swift
//  Final Project
//
//  Home screen — choose single-player or online first, then pick game.
//

import SwiftUI

// MARK: - Debug Mode Toggle
// Controlled by the build configuration: present in Debug builds only so
// production / Release archives never include the test-mode button.
#if DEBUG
let DEBUG_TEST_MODE = true
#else
let DEBUG_TEST_MODE = false
#endif

struct ContentView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // MARK: - Header
                VStack(spacing: 8) {
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Text("Game Center")
                        .font(.largeTitle.bold())

                    Text("選擇遊玩方式")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 60)
                .padding(.bottom, 48)

                // MARK: - Mode Selection
                VStack(spacing: 16) {
                    NavigationLink {
                        GamePickerView(mode: .local)
                    } label: {
                        modeCard(
                            icon: "person.2.fill",
                            title: "單機對戰",
                            subtitle: "同一台裝置輪流下棋"
                        )
                    }
                    .foregroundStyle(.primary)

                    NavigationLink {
                        LobbyView()
                    } label: {
                        modeCard(
                            icon: "wifi",
                            title: "連線對戰",
                            subtitle: "透過藍牙 / Wi-Fi 近距離對戰"
                        )
                    }
                    .foregroundStyle(.primary)

                    // MARK: - Debug Test Mode
                    if DEBUG_TEST_MODE {
                        NavigationLink {
                            GamePickerView(mode: .debugTest)
                        } label: {
                            modeCard(
                                icon: "ant.fill",
                                title: "🛠 測試模式",
                                subtitle: "模擬雙人連線，一人操作雙方 + 聊天"
                            )
                        }
                        .foregroundStyle(.primary)
                    }
                }
                .padding(.horizontal, 24)

                Spacer()
            }
            .animatedEntrance()
        }
    }

    private func modeCard(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: Spacing.m) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .frame(width: 44)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title).font(.appButton)
                Text(subtitle).font(.appCaption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(.secondary)
        }
        .card(radius: Radius.l, elevation: .mid, padding: Spacing.l)
    }
}

// MARK: - Play Mode

enum PlayMode {
    case local       // Single player (hot-seat)
    case debugTest   // Debug: simulates online but local, both sides playable
}

// MARK: - Game Picker (for single-player & debug test modes)

struct GamePickerView: View {
    let mode: PlayMode

    @State private var selectedEngine: (any GameEngine)?
    @State private var showSettings = false

    var body: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 150, maximum: 200))],
                spacing: 16
            ) {
                ForEach(GameRegistry.availableGames) { game in
                    Button {
                        let engine = game.createEngine()
                        selectedEngine = engine
                        showSettings = true
                    } label: {
                        VStack(spacing: Spacing.s) {
                            Image(systemName: game.icon)
                                .font(.system(size: 36))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.green, .teal],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(height: 44)
                            Text(game.title).font(.appButton)
                        }
                        .frame(maxWidth: .infinity)
                        .card(radius: Radius.l, elevation: .mid, padding: Spacing.l)
                    }
                    .foregroundStyle(.primary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
        }
        .animatedEntrance()
        .navigationTitle("選擇遊戲")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showSettings) {
            if let engine = selectedEngine {
                GameSettingsView(engine: engine, mode: mode)
            }
        }
    }
}

// MARK: - Game Settings Screen (before starting single-player or debug game)

struct GameSettingsView: View {
    let engine: any GameEngine
    let mode: PlayMode

    @State private var navigateToGame = false
    @State private var chatManager = ChatManager()

    var body: some View {
        VStack(spacing: 24) {
            // Game icon & title
            VStack(spacing: 8) {
                Image(systemName: type(of: engine).gameIcon)
                    .font(.system(size: 40))
                    .foregroundStyle(.blue)
                Text(type(of: engine).gameTitle)
                    .font(.title2.bold())
            }
            .padding(.top, 20)

            // Game-specific settings
            engine.makeSettingsView()

            if mode == .debugTest {
                VStack(spacing: 4) {
                    Image(systemName: "ant.fill")
                        .foregroundStyle(.orange)
                    Text("測試模式：你可以同時操作黑白雙方")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.orange.opacity(0.1))
                )
                .padding(.horizontal, 24)
            }

            Spacer()

            // Start button
            Button {
                navigateToGame = true
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
        .animatedEntrance()
        .navigationTitle("遊戲設定")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $navigateToGame) {
            if mode == .debugTest {
                // Debug test mode: enable chat overlay, no multiplayer lock
                engine.makeGameView()
                    .overlay(
                        ChatOverlayView(chatManager: chatManager)
                    )
            } else {
                engine.makeGameView()
            }
        }
    }
}

#Preview {
    ContentView()
}
