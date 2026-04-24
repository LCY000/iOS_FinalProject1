//
//  GameTransport.swift
//  Final Project
//
//  Transport abstraction + MPC implementation.
//  BluetoothTransport lives in BluetoothTransport.swift.
//

import Foundation
import MultipeerConnectivity

// MARK: - GameTransport Protocol

protocol GameTransport: AnyObject {
    var onPeerDiscovered: ((DiscoveredPeer) -> Void)? { get set }
    /// Passes the peer's display name.
    var onPeerConnected: ((String) -> Void)? { get set }
    var onPeerDisconnected: (() -> Void)? { get set }
    var onDataReceived: ((Data) -> Void)? { get set }

    func startHosting()
    func startBrowsing()
    func invite(_ peer: DiscoveredPeer)
    func send(_ data: Data)
    func disconnect()
}

// MARK: - MPCTransport

final class MPCTransport: NSObject, GameTransport {

    // MARK: Callbacks
    var onPeerDiscovered: ((DiscoveredPeer) -> Void)?
    var onPeerConnected: ((String) -> Void)?
    var onPeerDisconnected: (() -> Void)?
    var onDataReceived: ((Data) -> Void)?

    // MARK: Private
    private let serviceType = "game-platform"
    private var myPeerID: MCPeerID
    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var isConnected = false

    override init() {
        self.myPeerID = MCPeerID(displayName: UIDevice.current.name)
        super.init()
    }

    // MARK: - GameTransport

    func startHosting() {
        cleanupMC()
        let session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .none)
        session.delegate = self
        self.session = session

        let advertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: nil, serviceType: serviceType)
        advertiser.delegate = self
        advertiser.startAdvertisingPeer()
        self.advertiser = advertiser
    }

    func startBrowsing() {
        cleanupMC()
        let session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .none)
        session.delegate = self
        self.session = session

        let browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: serviceType)
        browser.delegate = self
        browser.startBrowsingForPeers()
        self.browser = browser
    }

    func invite(_ peer: DiscoveredPeer) {
        guard let session else { return }
        browser?.invitePeer(peer.id, to: session, withContext: nil, timeout: 30)
    }

    func send(_ data: Data) {
        guard let session, !session.connectedPeers.isEmpty else { return }
        do {
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
        } catch {
            print("MPCTransport: send failed — \(error.localizedDescription)")
        }
    }

    func disconnect() {
        cleanupMC()
    }

    // MARK: - Private

    private func cleanupMC() {
        advertiser?.stopAdvertisingPeer()
        advertiser = nil
        browser?.stopBrowsingForPeers()
        browser = nil
        session?.disconnect()
        session = nil
        isConnected = false
        myPeerID = MCPeerID(displayName: UIDevice.current.name)
    }
}

// MARK: - MCSessionDelegate

extension MPCTransport: MCSessionDelegate {

    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor in
            switch state {
            case .connected:
                self.isConnected = true
                self.advertiser?.stopAdvertisingPeer()
                self.browser?.stopBrowsingForPeers()
                self.onPeerConnected?(peerID.displayName)

            case .notConnected:
                if self.isConnected {
                    self.isConnected = false
                    self.onPeerDisconnected?()
                }

            case .connecting:
                break

            @unknown default:
                break
            }
        }
    }

    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        let received = data
        Task { @MainActor in
            self.onDataReceived?(received)
        }
    }

    nonisolated func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension MPCTransport: MCNearbyServiceAdvertiserDelegate {

    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        Task { @MainActor in
            invitationHandler(true, self.session)
        }
    }

    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        print("MPCTransport: failed to advertise — \(error.localizedDescription)")
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension MPCTransport: MCNearbyServiceBrowserDelegate {

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        let peer = DiscoveredPeer(id: peerID, displayName: peerID.displayName)
        Task { @MainActor in
            self.onPeerDiscovered?(peer)
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        print("MPCTransport: failed to browse — \(error.localizedDescription)")
    }
}
