//
//  BluetoothTransport.swift
//  Final Project
//
//  CoreBluetooth-based GameTransport for offline peer-to-peer play.
//  Works in airplane mode (Bluetooth on) without any router.
//
//  Topology: Host acts as Peripheral (advertises + receives writes),
//            Guest acts as Central (scans + subscribes to indications).
//
//  Reliability:
//    Host → Guest: GATT Indicate — Central sends ATT Confirmation per packet.
//    Guest → Host: GATT Write With Response — Peripheral sends ATT Write Response.
//    Both directions use length-prefix framing for messages > MTU.
//

import Foundation
import CoreBluetooth
import MultipeerConnectivity

// MARK: - UUIDs

private let kServiceUUID         = CBUUID(string: "B8A7C6D5-E4F3-1A2B-3C4D-5E6F7A8B9C0D")
private let kHostToGuestCharUUID = CBUUID(string: "B8A7C6D5-E4F3-1A2B-3C4D-000000000001")
private let kGuestToHostCharUUID = CBUUID(string: "B8A7C6D5-E4F3-1A2B-3C4D-000000000002")

// MARK: - Role

private enum BTRole { case none, host, guest }

// MARK: - BluetoothTransport

final class BluetoothTransport: NSObject, GameTransport {

    // MARK: GameTransport Callbacks
    var onPeerDiscovered:    ((DiscoveredPeer) -> Void)?
    var onPeerConnected:     ((String) -> Void)?
    var onPeerDisconnected:  (() -> Void)?
    var onDataReceived:      ((Data) -> Void)?

    // MARK: Role
    private var role: BTRole = .none

    // MARK: Host (Peripheral)
    private var peripheralManager:  CBPeripheralManager?
    private var hostToGuestChar:    CBMutableCharacteristic?
    private var guestToHostChar:    CBMutableCharacteristic?
    private var subscribedCentral:  CBCentral?
    private var hostSendQueue:      [Data] = []

    // MARK: Guest (Central)
    private var centralManager:     CBCentralManager?
    private var connectedPeripheral: CBPeripheral?
    private var hostToGuestCharRef: CBCharacteristic?
    private var guestToHostCharRef: CBCharacteristic?
    private var guestSendQueue:     [Data] = []
    private var guestWriteInFlight: Bool = false
    private var pendingWriteRetry:  Data?

    // MARK: Peer Lookup (fake MCPeerID → real CBPeripheral)
    private var peripheralByID: [ObjectIdentifier: CBPeripheral] = [:]

    // MARK: Reassembly
    private var receiveBuffer   = Data()
    private var expectedLength  = 0
    private var reassemblyTimeoutTask: Task<Void, Never>?

    // MARK: - GameTransport

    func startHosting() {
        role = .host
        resetBuffer()
        hostSendQueue = []
        peripheralManager = CBPeripheralManager(delegate: self, queue: .main)
    }

    func startBrowsing() {
        role = .guest
        resetBuffer()
        peripheralByID = [:]
        guestSendQueue = []
        guestWriteInFlight = false
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }

    func invite(_ peer: DiscoveredPeer) {
        guard let peripheral = peripheralByID[ObjectIdentifier(peer.id)],
              let cm = centralManager else { return }
        connectedPeripheral = peripheral
        peripheral.delegate = self
        cm.stopScan()
        cm.connect(peripheral, options: nil)
    }

    func send(_ data: Data) {
        switch role {
        case .host:  sendAsHost(data)
        case .guest: sendAsGuest(data)
        case .none:  break
        }
    }

    func disconnect() {
        reassemblyTimeoutTask?.cancel()
        reassemblyTimeoutTask = nil
        resetBuffer()
        pendingWriteRetry = nil
        guestSendQueue = []
        guestWriteInFlight = false
        hostSendQueue = []

        switch role {
        case .host:
            peripheralManager?.delegate = nil
            peripheralManager?.stopAdvertising()
            peripheralManager?.removeAllServices()
            peripheralManager = nil
            hostToGuestChar = nil
            guestToHostChar = nil
            subscribedCentral = nil
        case .guest:
            centralManager?.delegate = nil
            centralManager?.stopScan()
            if let p = connectedPeripheral {
                centralManager?.cancelPeripheralConnection(p)
            }
            centralManager = nil
            connectedPeripheral = nil
            hostToGuestCharRef = nil
            guestToHostCharRef = nil
        case .none:
            break
        }

        peripheralByID = [:]
        role = .none
    }

    // MARK: - Host Send

    private func sendAsHost(_ data: Data) {
        guard let pm = peripheralManager, let char = hostToGuestChar else { return }
        let mtu: Int
        if let central = subscribedCentral {
            mtu = pm.maximumUpdateValueLength(for: central)
        } else {
            mtu = 512
        }
        for packet in frame(data, mtu: mtu) {
            hostSendQueue.append(packet)
        }
        drainHostQueue()
    }

    private func drainHostQueue() {
        guard let pm = peripheralManager, let char = hostToGuestChar else { return }
        while !hostSendQueue.isEmpty {
            let packet = hostSendQueue[0]
            let sent = pm.updateValue(packet, for: char, onSubscribedCentrals: nil)
            if sent {
                hostSendQueue.removeFirst()
            } else {
                break   // queue full; peripheralManagerIsReady will drain the rest
            }
        }
    }

    // MARK: - Guest Send

    private func sendAsGuest(_ data: Data) {
        guard let peripheral = connectedPeripheral else { return }
        let mtu = peripheral.maximumWriteValueLength(for: .withResponse)
        let packets = frame(data, mtu: mtu)
        guestSendQueue.append(contentsOf: packets)
        if !guestWriteInFlight {
            drainGuestQueue()
        }
    }

    private func drainGuestQueue() {
        guard let peripheral = connectedPeripheral,
              let char = guestToHostCharRef,
              !guestSendQueue.isEmpty else {
            guestWriteInFlight = false
            return
        }
        let packet = guestSendQueue.removeFirst()
        pendingWriteRetry = packet
        guestWriteInFlight = true
        peripheral.writeValue(packet, for: char, type: .withResponse)
    }

    // MARK: - Framing

    /// Prepends a 4-byte big-endian length header to `data` and splits into
    /// MTU-sized chunks. Single-packet messages are by far the common case
    /// for board games (moves + chat << 185 bytes).
    private func frame(_ data: Data, mtu: Int) -> [Data] {
        let effective = max(mtu, 20)
        let header = withUnsafeBytes(of: UInt32(data.count).bigEndian) { Data($0) }
        let combined = header + data
        guard combined.count > effective else { return [combined] }

        var result: [Data] = []
        var offset = 0
        while offset < combined.count {
            let end = min(offset + effective, combined.count)
            result.append(combined[offset ..< end])
            offset = end
        }
        return result
    }

    // MARK: - Reassembly (shared by both roles)

    private func handleIncoming(_ chunk: Data) {
        if receiveBuffer.isEmpty && expectedLength == 0 {
            guard chunk.count >= 4 else {
                print("BluetoothTransport: chunk too short for length header")
                return
            }
            let length = Int(chunk[0]) << 24 | Int(chunk[1]) << 16
                       | Int(chunk[2]) << 8  | Int(chunk[3])
            guard length > 0 && length <= 64 * 1024 else {
                print("BluetoothTransport: invalid frame length \(length), discarding")
                return
            }
            expectedLength = length
            receiveBuffer.append(chunk.dropFirst(4))
            startReassemblyTimeout()
        } else {
            receiveBuffer.append(chunk)
        }

        if receiveBuffer.count >= expectedLength {
            let message = Data(receiveBuffer.prefix(expectedLength))
            resetBuffer()
            onDataReceived?(message)
        }
    }

    private func startReassemblyTimeout() {
        reassemblyTimeoutTask?.cancel()
        reassemblyTimeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { [weak self] in
                print("BluetoothTransport: reassembly timeout — resetting buffer")
                self?.resetBuffer()
            }
        }
    }

    private func resetBuffer() {
        receiveBuffer = Data()
        expectedLength = 0
        reassemblyTimeoutTask?.cancel()
        reassemblyTimeoutTask = nil
    }
}

// MARK: - CBPeripheralManagerDelegate

extension BluetoothTransport: CBPeripheralManagerDelegate {

    nonisolated func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        Task { @MainActor in
            guard peripheral.state == .poweredOn else { return }
            self.setupAndAdvertise()
        }
    }

    private func setupAndAdvertise() {
        guard let pm = peripheralManager else { return }

        let h2g = CBMutableCharacteristic(
            type: kHostToGuestCharUUID,
            properties: [.indicate],
            value: nil,
            permissions: []
        )
        let g2h = CBMutableCharacteristic(
            type: kGuestToHostCharUUID,
            properties: [.write],
            value: nil,
            permissions: [.writeable]
        )
        hostToGuestChar = h2g
        guestToHostChar = g2h

        let service = CBMutableService(type: kServiceUUID, primary: true)
        service.characteristics = [h2g, g2h]
        pm.add(service)
        // advertising starts in peripheralManager(_:didAdd:error:)
    }

    nonisolated func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        Task { @MainActor in
            guard error == nil else {
                print("BluetoothTransport: didAdd service error — \(error!.localizedDescription)")
                return
            }
            let suffix = UUID().uuidString.prefix(6)
            let name = "\(UIDevice.current.name)｜\(suffix)"
            self.peripheralManager?.startAdvertising([
                CBAdvertisementDataServiceUUIDsKey: [kServiceUUID],
                CBAdvertisementDataLocalNameKey:    name
            ])
        }
    }

    nonisolated func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        Task { @MainActor in
            guard characteristic.uuid == kHostToGuestCharUUID else { return }
            self.subscribedCentral = central
            self.peripheralManager?.stopAdvertising()
            self.resetBuffer()
            self.hostSendQueue = []
            // Central's display name is not available via GATT; use a placeholder.
            self.onPeerConnected?("對手")
        }
    }

    nonisolated func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        Task { @MainActor in
            guard characteristic.uuid == kHostToGuestCharUUID else { return }
            self.resetBuffer()
            self.onPeerDisconnected?()
        }
    }

    nonisolated func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        Task { @MainActor in
            for request in requests where request.characteristic.uuid == kGuestToHostCharUUID {
                if let data = request.value {
                    peripheral.respond(to: request, withResult: .success)
                    self.handleIncoming(data)
                }
            }
        }
    }

    nonisolated func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        Task { @MainActor in
            self.drainHostQueue()
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension BluetoothTransport: CBCentralManagerDelegate {

    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            guard central.state == .poweredOn else { return }
            central.scanForPeripherals(
                withServices: [kServiceUUID],
                options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
            )
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        Task { @MainActor in
            let name = (advertisementData[CBAdvertisementDataLocalNameKey] as? String)
                ?? peripheral.name
                ?? "未知裝置"
            let fakePeerID = MCPeerID(displayName: name)
            // Guard against duplicate discovers of the same peripheral.
            let key = ObjectIdentifier(fakePeerID)
            guard self.peripheralByID[key] == nil else { return }
            self.peripheralByID[key] = peripheral
            let peer = DiscoveredPeer(id: fakePeerID, displayName: name)
            self.onPeerDiscovered?(peer)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor in
            self.resetBuffer()
            peripheral.discoverServices([kServiceUUID])
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            self.connectedPeripheral = nil
            self.hostToGuestCharRef  = nil
            self.guestToHostCharRef  = nil
            self.resetBuffer()
            self.onPeerDisconnected?()
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            print("BluetoothTransport: failed to connect — \(error?.localizedDescription ?? "unknown")")
            self.onPeerDisconnected?()
        }
    }
}

// MARK: - CBPeripheralDelegate

extension BluetoothTransport: CBPeripheralDelegate {

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        Task { @MainActor in
            guard error == nil,
                  let service = peripheral.services?.first(where: { $0.uuid == kServiceUUID })
            else { return }
            peripheral.discoverCharacteristics([kHostToGuestCharUUID, kGuestToHostCharUUID], for: service)
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        Task { @MainActor in
            guard error == nil else { return }
            for char in service.characteristics ?? [] {
                switch char.uuid {
                case kHostToGuestCharUUID:
                    self.hostToGuestCharRef = char
                    peripheral.setNotifyValue(true, for: char)
                case kGuestToHostCharUUID:
                    self.guestToHostCharRef = char
                default:
                    break
                }
            }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        Task { @MainActor in
            guard error == nil,
                  characteristic.uuid == kHostToGuestCharUUID,
                  characteristic.isNotifying else { return }
            let name = peripheral.name ?? "對手"
            self.onPeerConnected?(name)
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        Task { @MainActor in
            guard error == nil,
                  characteristic.uuid == kHostToGuestCharUUID,
                  let data = characteristic.value else { return }
            self.handleIncoming(data)
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        Task { @MainActor in
            if error == nil {
                self.pendingWriteRetry = nil
                self.drainGuestQueue()
            } else if let retryData = self.pendingWriteRetry {
                // Single retry — CoreBT already retried at L2CAP; one more at app level is enough.
                self.pendingWriteRetry = nil
                peripheral.writeValue(retryData, for: characteristic, type: .withResponse)
            } else {
                // Second consecutive failure: treat as disconnect.
                self.guestWriteInFlight = false
                self.onPeerDisconnected?()
            }
        }
    }
}
