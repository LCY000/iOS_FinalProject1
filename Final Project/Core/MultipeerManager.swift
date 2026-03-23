//
//  MultipeerManager.swift
//  Final Project
//
//  Game-agnostic networking layer using MultipeerConnectivity.
//  Only sends/receives MessageEnvelope — never touches game logic.
//

import Foundation
import MultipeerConnectivity

// MARK: - Connection State

enum ConnectionState: String {
    case notConnected = "未連線"
    case hosting = "等待對手連線…"
    case browsing = "尋找房間中…"
    case connecting = "連線中…"
    case connected = "已連線"
    case disconnected = "連線已中斷"
}

// MARK: - Discovered Peer

struct DiscoveredPeer: Identifiable, Hashable {
    let id: MCPeerID
    let displayName: String

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: DiscoveredPeer, rhs: DiscoveredPeer) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - MultipeerManager

@Observable
class MultipeerManager: NSObject {

    // MARK: Public State

    var connectionState: ConnectionState = .notConnected
    var discoveredPeers: [DiscoveredPeer] = []
    var connectedPeerName: String?
    var isHost: Bool = false

    // MARK: Callbacks

    /// Called when a MessageEnvelope is received from the peer.
    var onEnvelopeReceived: ((MessageEnvelope) -> Void)?

    /// Called when the peer disconnects unexpectedly.
    var onDisconnected: (() -> Void)?

    /// Called when a peer successfully connects.
    var onPeerConnected: (() -> Void)?

    // MARK: Private MC Objects

    private let serviceType = "game-platform"  // ≤ 15 chars, lowercase + hyphens
    private var myPeerID: MCPeerID
    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?

    // MARK: Init

    override init() {
        let displayName = UIDevice.current.name
        self.myPeerID = MCPeerID(displayName: displayName)
        super.init()
    }

    // MARK: - Host (Advertise)

    func hostGame() {
        cleanup()
        isHost = true

        let session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .none)
        session.delegate = self
        self.session = session

        let advertiser = MCNearbyServiceAdvertiser(
            peer: myPeerID,
            discoveryInfo: nil,
            serviceType: serviceType
        )
        advertiser.delegate = self
        advertiser.startAdvertisingPeer()
        self.advertiser = advertiser

        connectionState = .hosting
    }

    // MARK: - Join (Browse)

    func joinGame() {
        cleanup()
        isHost = false

        let session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .none)
        session.delegate = self
        self.session = session

        let browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: serviceType)
        browser.delegate = self
        browser.startBrowsingForPeers()
        self.browser = browser

        connectionState = .browsing
        discoveredPeers = []
    }

    // MARK: - Invite Peer

    func invitePeer(_ peer: DiscoveredPeer) {
        guard let session = session else { return }
        browser?.invitePeer(peer.id, to: session, withContext: nil, timeout: 30)
        connectionState = .connecting
    }

    // MARK: - Send Envelope

    func send(envelope: MessageEnvelope) {
        guard let session = session,
              let data = envelope.encode(),
              !session.connectedPeers.isEmpty else { return }

        do {
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
        } catch {
            print("MultipeerManager: Failed to send data — \(error.localizedDescription)")
        }
    }

    // MARK: - Disconnect

    func disconnect() {
        cleanup()
        connectionState = .notConnected
    }

    // MARK: - Cleanup

    private func cleanup() {
        advertiser?.stopAdvertisingPeer()
        advertiser = nil
        browser?.stopBrowsingForPeers()
        browser = nil
        session?.disconnect()
        session = nil
        discoveredPeers = []
        connectedPeerName = nil
        // Clear callbacks to prevent stale closures
        onEnvelopeReceived = nil
        onDisconnected = nil
        onPeerConnected = nil
        // Create fresh peer ID for next session (avoids stale MCPeerID issues)
        myPeerID = MCPeerID(displayName: UIDevice.current.name)
    }
}

// MARK: - MCSessionDelegate

extension MultipeerManager: MCSessionDelegate {

    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor in
            switch state {
            case .connected:
                self.connectionState = .connected
                self.connectedPeerName = peerID.displayName
                self.advertiser?.stopAdvertisingPeer()
                self.browser?.stopBrowsingForPeers()
                self.onPeerConnected?()

            case .notConnected:
                if self.connectionState == .connected {
                    self.connectionState = .disconnected
                    self.connectedPeerName = nil
                    self.onDisconnected?()
                }

            case .connecting:
                self.connectionState = .connecting

            @unknown default:
                break
            }
        }
    }

    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        let receivedData = data
        Task { @MainActor in
            guard let envelope = MessageEnvelope.decode(from: receivedData) else { return }
            self.onEnvelopeReceived?(envelope)
        }
    }

    // Required delegate methods (unused for this app)
    nonisolated func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension MultipeerManager: MCNearbyServiceAdvertiserDelegate {

    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // Auto-accept invitations
        Task { @MainActor in
            invitationHandler(true, self.session)
        }
    }

    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        print("MultipeerManager: Failed to advertise — \(error.localizedDescription)")
        Task { @MainActor in
            self.connectionState = .notConnected
        }
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension MultipeerManager: MCNearbyServiceBrowserDelegate {

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        let peer = DiscoveredPeer(id: peerID, displayName: peerID.displayName)
        Task { @MainActor in
            if !self.discoveredPeers.contains(peer) {
                self.discoveredPeers.append(peer)
            }
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        Task { @MainActor in
            self.discoveredPeers.removeAll { $0.id == peerID }
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        print("MultipeerManager: Failed to browse — \(error.localizedDescription)")
        Task { @MainActor in
            self.connectionState = .notConnected
        }
    }
}
