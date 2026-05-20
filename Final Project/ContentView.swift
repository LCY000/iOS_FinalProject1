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
            ZStack(alignment: .top) {
                // Brand gradient behind content
                LinearGradient(
                    colors: [Color.blue.opacity(0.07), Color.purple.opacity(0.04), Color.clear],
                    startPoint: .top,
                    endPoint: UnitPoint(x: 0.5, y: 0.50)
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    // MARK: - Header
                    VStack(spacing: Spacing.s) {
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 100, height: 100)
                                .shadow(color: Color.blue.opacity(0.14), radius: 20, y: 6)
                            Image(systemName: "gamecontroller.fill")
                                .font(.system(size: 50))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }

                        Text("Game Center")
                            .font(.largeTitle.bold())

                        Text("選擇遊玩方式")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, Spacing.xl + Spacing.l + Spacing.xxs)
                    .padding(.bottom, Spacing.xl + Spacing.m)

                    // MARK: - Mode Selection
                    VStack(spacing: Spacing.m) {
                        NavigationLink {
                            GamePickerView(mode: .local)
                        } label: {
                            modeCard(
                                icon: "person.2.fill",
                                title: "單機對戰",
                                subtitle: "同一台裝置輪流下棋",
                                tint: .blue
                            )
                        }
                        .foregroundStyle(.primary)

                        NavigationLink {
                            LobbyView()
                        } label: {
                            modeCard(
                                icon: "wifi",
                                title: "連線對戰",
                                subtitle: "透過藍牙 / Wi-Fi 近距離對戰",
                                tint: .green
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
                                    subtitle: "模擬雙人連線，一人操作雙方 + 聊天",
                                    tint: .orange
                                )
                            }
                            .foregroundStyle(.primary)
                        }
                    }
                    .padding(.horizontal, Spacing.l)

                    Spacer()
                }
            }
            .animatedEntrance()
        }
    }

    private func modeCard(icon: String, title: String, subtitle: String, tint: Color) -> some View {
        HStack(spacing: Spacing.m) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.12))
                    .frame(width: 48, height: 48)
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title).font(.appButton)
                Text(subtitle).font(.appCaption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.tertiary)
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
    @State private var selectedGame: GameInfo?
    @State private var showSettings = false

    var body: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 150, maximum: 200))],
                spacing: Spacing.m
            ) {
                ForEach(GameRegistry.availableGames) { game in
                    Button {
                        let engine = game.createEngine()
                        selectedEngine = engine
                        selectedGame = game
                        showSettings = true
                    } label: {
                        let (c1, c2) = gameGradient(for: game)
                        VStack(spacing: Spacing.s) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [c1.opacity(0.15), c2.opacity(0.08)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 64, height: 64)
                                Image(systemName: game.icon)
                                    .font(.system(size: 30))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [c1, c2],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                            Text(game.title).font(.appButton)
                        }
                        .frame(maxWidth: .infinity)
                        .card(radius: Radius.l, elevation: .mid, padding: Spacing.l)
                    }
                    .foregroundStyle(.primary)
                }
            }
            .padding(.horizontal, Spacing.l)
            .padding(.top, Spacing.m)
        }
        .animatedEntrance()
        .navigationTitle("選擇遊戲")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showSettings) {
            if let engine = selectedEngine, let game = selectedGame {
                GameSettingsView(engine: engine, game: game, mode: mode)
            }
        }
    }

    private func gameGradient(for game: GameInfo) -> (Color, Color) {
        switch game.gameType {
        case "reversi":  return (.purple, .pink)
        case "gomoku":   return (.teal, .green)
        case "quoridor": return (.blue, .indigo)
        case "checkers": return (.orange, .yellow)
        default:         return (.blue, .teal)
        }
    }
}

// MARK: - Game Settings Screen (before starting single-player or debug game)

struct GameSettingsView: View {
    let engine: any GameEngine
    let game: GameInfo
    let mode: PlayMode

    @State private var navigateToGame = false
    @State private var chatManager = ChatManager()
    @State private var showTutorial = false
    @State private var firstPlayer: PlayerColor = .black

    private var gameAccentColor: Color {
        switch type(of: engine).gameType {
        case "reversi":  return .purple
        case "gomoku":   return .teal
        case "quoridor": return .blue
        case "checkers": return .orange
        default:         return .blue
        }
    }

    var body: some View {
        VStack(spacing: 24) {
            // Game icon & title
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(gameAccentColor.opacity(0.12))
                        .frame(width: 80, height: 80)
                    Image(systemName: type(of: engine).gameIcon)
                        .font(.system(size: 38))
                        .foregroundStyle(gameAccentColor)
                }
                Text(type(of: engine).gameTitle)
                    .font(.title2.bold())
            }
            .padding(.top, 20)

            // Game-specific settings
            engine.makeSettingsView()

            if mode == .local {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("先手")
                        .font(.headline)
                    Picker("先手", selection: $firstPlayer) {
                        Text("黑方先").tag(PlayerColor.black)
                        Text("白方先").tag(PlayerColor.white)
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.horizontal, Spacing.l)
            }

            if mode == .debugTest {
                VStack(spacing: Spacing.xxs) {
                    Image(systemName: "ant.fill")
                        .foregroundStyle(.orange)
                    Text("測試模式：你可以同時操作黑白雙方")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(Spacing.m)
                .background(
                    RoundedRectangle(cornerRadius: Radius.m)
                        .fill(Color.orange.opacity(0.1))
                )
                .padding(.horizontal, Spacing.l)
            }

            Spacer()

            // Start button
            Button("開始遊戲") {
                engine.applyFirstMover(firstPlayer)
                navigateToGame = true
            }
            .buttonStyle(PrimaryActionButtonStyle(tint: .green))
            .padding(.horizontal, Spacing.xl)
            .padding(.bottom, Spacing.m)
        }
        .animatedEntrance()
        .navigationTitle("遊戲設定")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showTutorial = true
                } label: {
                    Image(systemName: "info.circle")
                }
                .accessibilityLabel("遊戲說明")
            }
        }
        .sheet(isPresented: $showTutorial) {
            TutorialView(game: game)
        }
        .navigationDestination(isPresented: $navigateToGame) {
            if mode == .debugTest {
                // Debug test mode: enable chat overlay, no multiplayer lock
                engine.makeGameView()
                    .overlay {
                        ChatOverlayView(chatManager: chatManager)
                    }
            } else {
                engine.makeGameView()
            }
        }
    }
}

#Preview {
    ContentView()
}
