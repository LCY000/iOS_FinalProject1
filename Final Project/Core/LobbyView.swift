//
//  LobbyView.swift
//  Final Project
//
//  Game-agnostic lobby for peer-to-peer matchmaking.
//  Players choose to Host or Browse, then connect → go to Room.
//

import SwiftUI

struct LobbyView: View {
    @State private var multipeerManager = MultipeerManager()
    @State private var navigateToRoom = false

    var body: some View {
        VStack(spacing: 24) {
            // MARK: - Connection Status Badge
            statusBadge

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
        .animatedEntrance()
        .navigationTitle("連線對戰")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $navigateToRoom) {
            RoomView(multipeerManager: multipeerManager)
        }
        // Use onChange instead of callback — more reliable with SwiftUI lifecycle
        .onChange(of: multipeerManager.connectionState) { oldState, newState in
            print("🔵 [Lobby] connectionState: \(oldState.rawValue) → \(newState.rawValue)")
            if newState == .connected && !navigateToRoom {
                navigateToRoom = true
            }
            // Reset navigation when disconnected — ensures RoomView is popped
            if newState == .disconnected || newState == .notConnected {
                navigateToRoom = false
            }
        }
        .onAppear {
            // Reset state when re-entering lobby
            if multipeerManager.connectionState == .disconnected {
                multipeerManager.disconnect()
            }
            // Reset navigation flag when re-entering
            navigateToRoom = false
        }
        .onDisappear {
            // If we haven't connected yet, clean up
            if multipeerManager.connectionState != .connected {
                multipeerManager.disconnect()
            }
        }
    }

    // MARK: - Status Badge

    private var statusBadge: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
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
    }

    private var statusColor: Color {
        switch multipeerManager.connectionState {
        case .connected: return .green
        case .hosting, .browsing, .connecting: return .orange
        case .notConnected: return .gray
        case .disconnected: return .red
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 16) {
            Button {
                multipeerManager.hostGame()
            } label: {
                Label("建立房間", systemImage: "antenna.radiowaves.left.and.right")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.blue)
                    )
                    .foregroundStyle(.white)
            }

            Button {
                multipeerManager.joinGame()
            } label: {
                Label("尋找房間", systemImage: "magnifyingglass")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.blue, lineWidth: 2)
                    )
                    .foregroundStyle(.blue)
            }
        }
        .padding(.horizontal, 32)
    }
}

#Preview {
    NavigationStack {
        LobbyView()
    }
}
