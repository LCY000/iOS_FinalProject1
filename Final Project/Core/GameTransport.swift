//
//  GameTransport.swift
//  Final Project
//
//  Transport abstraction + MPC implementation.
//  BluetoothTransport lives in BluetoothTransport.swift.
//

import Foundation
import MultipeerConnectivity
import OSLog

// MARK: - Transport Error

enum TransportError: Equatable {
    case bluetoothUnauthorized
    case bluetoothUnsupported
    case bluetoothOff
    case wifiUnavailable
    case unknown(String)

    var userMessage: String {
        switch self {
        case .bluetoothUnauthorized:
            return "需要藍牙權限才能使用此模式，請至「設定 > 隱私權 > 藍牙」開啟。"
        case .bluetoothUnsupported:
            return "此裝置不支援藍牙連線。"
        case .bluetoothOff:
            return "請先開啟藍牙。"
        case .wifiUnavailable:
            return "Wi-Fi 連線啟動失敗，請確認區域網路權限。"
        case .unknown(let detail):
            return "連線錯誤：\(detail)"
        }
    }
}

// MARK: - Discovered Peer

struct DiscoveredPeer: Identifiable, Hashable {
    /// Stable string ID within a session.
    /// MPC: "mpc:<displayName>:<objectIdentifierHash>"; BLE: peripheral.identifier.uuidString
    let id: String
    let displayName: String
}

// MARK: - GameTransport Protocol

protocol GameTransport: AnyObject {
    var onPeerDiscovered: ((DiscoveredPeer) -> Void)? { get set }
    var onPeerConnected: ((String) -> Void)? { get set }
    var onPeerDisconnected: (() -> Void)? { get set }
    var onDataReceived: ((Data) -> Void)? { get set }
    var onTransportError: ((TransportError) -> Void)? { get set }

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
    var onTransportError: ((TransportError) -> Void)?

    // MARK: Private
    private let serviceType = "game-platform"
    private var myPeerID: MCPeerID
    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var isConnected = false
    private var peerIDByDiscoveredID: [String: MCPeerID] = [:]

    override init() {
        self.myPeerID = MCPeerID(displayName: PlayerNameProvider.broadcastName)
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
        guard let session, let peerID = peerIDByDiscoveredID[peer.id] else { return }
        browser?.invitePeer(peerID, to: session, withContext: nil, timeout: 30)
    }

    func send(_ data: Data) {
        guard let session, !session.connectedPeers.isEmpty else { return }
        do {
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
        } catch {
            Logger.mpc.error("send failed — \(error.localizedDescription, privacy: .public)")
        }
    }

    func disconnect() {
        cleanupMC()
    }

    // MARK: - Private

    private func discoveredID(for peerID: MCPeerID) -> String {
        "mpc:\(peerID.displayName):\(ObjectIdentifier(peerID).hashValue)"
    }

    private func cleanupMC() {
        advertiser?.stopAdvertisingPeer()
        advertiser = nil
        browser?.stopBrowsingForPeers()
        browser = nil
        session?.disconnect()
        session = nil
        isConnected = false
        peerIDByDiscoveredID.removeAll()
        myPeerID = MCPeerID(displayName: PlayerNameProvider.broadcastName)
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
        Logger.mpc.error("failed to advertise — \(error.localizedDescription, privacy: .public)")
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension MPCTransport: MCNearbyServiceBrowserDelegate {

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        let id = self.discoveredID(for: peerID)
        let peer = DiscoveredPeer(id: id, displayName: peerID.displayName)
        Task { @MainActor in
            guard self.peerIDByDiscoveredID[id] == nil else { return }
            self.peerIDByDiscoveredID[id] = peerID
            self.onPeerDiscovered?(peer)
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        Logger.mpc.error("failed to browse — \(error.localizedDescription, privacy: .public)")
    }
}
