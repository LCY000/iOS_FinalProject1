//
//  MultipeerManager.swift
//  Final Project
//
//  Game-agnostic networking layer.
//  Internally delegates to a GameTransport (MPCTransport or BluetoothTransport).
//  All public API and @Observable state are unchanged — RoomView/Coordinator
//  require zero modifications.
//

import Foundation
import OSLog

// MARK: - Connection Mode

enum ConnectionMode: String, CaseIterable {
    case wifi      = "WiFi"
    case bluetooth = "藍牙"
}

// MARK: - Connection State

enum ConnectionState: String {
    case notConnected = "未連線"
    case hosting      = "等待對手連線…"
    case browsing     = "尋找房間中…"
    case connecting   = "連線中…"
    case connected    = "已連線"
    case disconnected = "連線已中斷"
}

// MARK: - MultipeerManager

@Observable
@MainActor
final class MultipeerManager: NSObject {

    // MARK: Public State

    var connectionState: ConnectionState = .notConnected
    var discoveredPeers: [DiscoveredPeer] = []
    var connectedPeerName: String?
    var isHost: Bool = false
    var connectionMode: ConnectionMode = .wifi
    var transportError: TransportError?

    // MARK: Callbacks (set by GameSessionCoordinator)

    var onEnvelopeReceived: ((MessageEnvelope) -> Void)?
    var onDisconnected: (() -> Void)?
    var onPeerConnected: (() -> Void)?

    // MARK: Private

    private var transport: (any GameTransport)?

    // MARK: - Host

    func hostGame() {
        cleanup()
        isHost = true
        let t = makeTransport()
        wire(t)
        transport = t
        t.startHosting()
        connectionState = .hosting
    }

    // MARK: - Join

    func joinGame() {
        cleanup()
        isHost = false
        let t = makeTransport()
        wire(t)
        transport = t
        t.startBrowsing()
        connectionState = .browsing
        discoveredPeers = []
    }

    // MARK: - Invite

    func invitePeer(_ peer: DiscoveredPeer) {
        transport?.invite(peer)
        connectionState = .connecting
    }

    // MARK: - Send

    func send(envelope: MessageEnvelope) {
        guard let data = envelope.encode() else { return }
        transport?.send(data)
    }

    // MARK: - Disconnect

    func disconnect() {
        cleanup()
        connectionState = .notConnected
    }

    // MARK: - Private

    private func makeTransport() -> any GameTransport {
        switch connectionMode {
        case .wifi:      return MPCTransport()
        case .bluetooth: return BluetoothTransport()
        }
    }

    private func wire(_ t: any GameTransport) {
        t.onPeerDiscovered = { [weak self] peer in
            guard let self else { return }
            if !self.discoveredPeers.contains(peer) {
                self.discoveredPeers.append(peer)
            }
        }
        t.onPeerConnected = { [weak self] name in
            guard let self else { return }
            self.connectionState = .connected
            self.connectedPeerName = name
            self.onPeerConnected?()
        }
        t.onPeerDisconnected = { [weak self] in
            guard let self else { return }
            guard self.connectionState == .connected else { return }
            self.connectionState = .disconnected
            self.connectedPeerName = nil
            self.onDisconnected?()
        }
        t.onDataReceived = { [weak self] data in
            guard let self else { return }
            guard let envelope = MessageEnvelope.decode(from: data) else {
                Logger.session.warning("envelope decode failed — possible desync")
                return
            }
            self.onEnvelopeReceived?(envelope)
        }
        t.onTransportError = { [weak self] error in
            guard let self else { return }
            self.transportError = error
            self.connectionState = .notConnected
            self.transport?.disconnect()
            self.transport = nil
        }
    }

    private func cleanup() {
        // Nil upper-layer callbacks before disconnecting so async transport
        // events fired during teardown are silently dropped.
        onEnvelopeReceived = nil
        onDisconnected = nil
        onPeerConnected = nil
        // Silence transport callbacks too.
        transport?.onPeerConnected = nil
        transport?.onPeerDisconnected = nil
        transport?.onDataReceived = nil
        transport?.onPeerDiscovered = nil
        transport?.onTransportError = nil
        transport?.disconnect()
        transport = nil
        discoveredPeers = []
        connectedPeerName = nil
    }
}
