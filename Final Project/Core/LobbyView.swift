//
//  LobbyView.swift
//  Final Project
//
//  Game-agnostic lobby for peer-to-peer matchmaking.
//  Players choose to Host or Browse, then connect → go to Room.
//

import OSLog
import SwiftUI

struct LobbyView: View {
    @State private var multipeerManager = MultipeerManager()
    @State private var navigateToRoom = false
    @State private var draftNickname: String = ""
    @State private var isEditingNickname = false
    @State private var dotPulsing = false

    var body: some View {
        VStack(spacing: 24) {
            // MARK: - Connection Status Badge
            statusBadge

            // MARK: - Nickname (always visible)
            nicknameSection

            // MARK: - Host / Browse Buttons
            if multipeerManager.connectionState == .notConnected ||
               multipeerManager.connectionState == .disconnected {
                actionButtons
            }

            // MARK: - Hosting State
            if multipeerManager.connectionState == .hosting {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("等待對手連線…")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    Button("取消", role: .cancel) {
                        multipeerManager.disconnect()
                    }
                    .foregroundStyle(.red)
                }
                .padding(.top, 20)
            }

            // MARK: - Browsing State — Discovered Peers
            if multipeerManager.connectionState == .browsing ||
               multipeerManager.connectionState == .connecting {
                VStack(alignment: .leading, spacing: 12) {
                    Text("可用的房間")
                        .font(.headline)
                        .padding(.horizontal)

                    if multipeerManager.discoveredPeers.isEmpty {
                        VStack(spacing: 8) {
                            ProgressView()
                            Text("搜尋中…")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 20)
                    } else {
                        List(multipeerManager.discoveredPeers) { peer in
                            Button {
                                multipeerManager.invitePeer(peer)
                            } label: {
                                HStack {
                                    Image(systemName: "iphone")
                                        .foregroundStyle(.blue)
                                    Text(peer.displayName)
                                        .font(.body)
                                    Spacer()
                                    if multipeerManager.connectionState == .connecting {
                                        ProgressView()
                                    } else {
                                        Image(systemName: "chevron.right")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .listStyle(.insetGrouped)
                        .frame(maxHeight: 300)
                    }

                    Button("取消搜尋", role: .cancel) {
                        multipeerManager.disconnect()
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(.red)
                }
            }

            Spacer()
        }
        .padding(.top, 20)
        .animatedEntrance(delay: 0.12)
        .navigationTitle("連線對戰")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $navigateToRoom) {
            RoomView(multipeerManager: multipeerManager)
        }
        // Use onChange instead of callback — more reliable with SwiftUI lifecycle
        .onChange(of: multipeerManager.connectionState) { oldState, newState in
            Logger.session.debug("Lobby connectionState: \(oldState.rawValue) → \(newState.rawValue)")
            if newState == .connected && !navigateToRoom {
                navigateToRoom = true
            }
            // Reset navigation when disconnected — ensures RoomView is popped
            if newState == .disconnected || newState == .notConnected {
                navigateToRoom = false
            }
        }
        .onAppear {
            multipeerManager.disconnect()
            navigateToRoom = false
            if PlayerNameProvider.needsOnboarding && !isEditingNickname {
                draftNickname = ""
                isEditingNickname = true
            }
        }
        .onDisappear {
            // If we haven't connected yet, clean up
            if multipeerManager.connectionState != .connected {
                multipeerManager.disconnect()
            }
        }
        .hapticFeedback(.connect, trigger: multipeerManager.connectionState == .connected)
        .hapticFeedback(.disconnect, trigger: multipeerManager.transportError != nil)
        .alert(
            "藍牙連線問題",
            isPresented: Bindable(multipeerManager).hasTransportError
        ) {
            Button("確定", role: .cancel) {
                multipeerManager.transportError = nil
            }
        } message: {
            if let err = multipeerManager.transportError {
                Text(err.userMessage)
            }
        }
    }

    // MARK: - Status Badge

    private var isActiveDot: Bool {
        switch multipeerManager.connectionState {
        case .hosting, .browsing, .connecting: return true
        default: return false
        }
    }

    private var statusBadge: some View {
        HStack(spacing: 8) {
            ZStack {
                // Sonar ripple for active states
                Circle()
                    .fill(statusColor.opacity(0.30))
                    .frame(width: 10, height: 10)
                    .scaleEffect(dotPulsing ? 2.6 : 1.0)
                    .opacity(dotPulsing ? 0 : 0.7)
                    .animation(.easeOut(duration: 1.0).repeatForever(autoreverses: false), value: dotPulsing)
                    .opacity(isActiveDot ? 1 : 0)
                    .animation(.easeOut(duration: 0.3), value: isActiveDot)

                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)
            }
            Text(multipeerManager.connectionState.rawValue)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(statusColor.opacity(0.1))
        )
        .onAppear { dotPulsing = true }
    }

    private var statusColor: Color {
        switch multipeerManager.connectionState {
        case .connected: return .green
        case .hosting, .browsing, .connecting: return .orange
        case .notConnected: return .gray
        case .disconnected: return .red
        }
    }

    // MARK: - Nickname Section

    private var nicknameSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Label("你的暱稱", systemImage: "person.circle")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: Spacing.s) {
                if isEditingNickname {
                    TextField("最多 12 字", text: $draftNickname)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .submitLabel(.done)
                        .onSubmit { saveNickname() }
                    Button("儲存") { saveNickname() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .tint(.blue)
                    if !PlayerNameProvider.needsOnboarding {
                        Button("取消") { isEditingNickname = false }
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                } else {
                    Text(PlayerNameProvider.broadcastName)
                        .font(.body.bold())
                    Spacer()
                    Button {
                        draftNickname = PlayerNameProvider.savedNickname ?? ""
                        isEditingNickname = true
                    } label: {
                        Text("變更")
                            .font(.caption.bold())
                    }
                    .buttonStyle(PillButtonStyle(tint: .blue))
                }
            }
            .animation(.spring(duration: 0.25), value: isEditingNickname)
        }
        .padding(Spacing.m)
        .card(radius: Radius.m, elevation: .low, padding: 0)
        .padding(.horizontal, Spacing.xl)
    }

    private func saveNickname() {
        let trimmed = String(
            draftNickname.trimmingCharacters(in: .whitespacesAndNewlines).prefix(12)
        )
        PlayerNameProvider.savedNickname = trimmed.isEmpty ? nil : trimmed
        isEditingNickname = false
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: Spacing.m) {
            Picker("連線方式", selection: $multipeerManager.connectionMode) {
                ForEach(ConnectionMode.allCases, id: \.self) { mode in
                    Label(mode.rawValue,
                          systemImage: mode == .wifi ? "wifi" : "airplane")
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .disabled(!canChangeMode)

            Button {
                multipeerManager.hostGame()
            } label: {
                Label("建立房間", systemImage: "antenna.radiowaves.left.and.right")
            }
            .buttonStyle(PrimaryActionButtonStyle(tint: .blue))

            Button {
                multipeerManager.joinGame()
            } label: {
                Label("尋找房間", systemImage: "magnifyingglass")
            }
            .buttonStyle(SecondaryActionButtonStyle(tint: .blue))
        }
        .padding(.horizontal, Spacing.xl)
    }

    private var canChangeMode: Bool {
        multipeerManager.connectionState == .notConnected ||
        multipeerManager.connectionState == .disconnected
    }
}

#Preview {
    NavigationStack {
        LobbyView()
    }
}
