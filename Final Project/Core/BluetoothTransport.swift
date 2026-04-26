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
import OSLog

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
    var onTransportError:    ((TransportError) -> Void)?

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

    // MARK: Peer Lookup (peripheral UUID string → CBPeripheral)
    private var peripheralByID: [String: CBPeripheral] = [:]

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
        guard let peripheral = peripheralByID[peer.id],
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
        guard peripheralManager != nil, hostToGuestChar != nil else { return }
        let mtu = subscribedCentral?.maximumUpdateValueLength ?? 512
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
        if guestWriteInFlight { return }
        guard let peripheral = connectedPeripheral,
              let char = guestToHostCharRef,
              !guestSendQueue.isEmpty else { return }
        let packet = guestSendQueue.removeFirst()
        pendingWriteRetry = packet
        guestWriteInFlight = true
        peripheral.writeValue(packet, for: char, type: .withResponse)
    }

    // MARK: - Framing

    /// Prepends a 4-byte big-endian length header to `data` and splits into
    /// MTU-sized chunks. Single-packet messages are by far the common case
    /// for board games (moves + chat << 185 bytes).
    func frame(_ data: Data, mtu: Int) -> [Data] {
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

    func handleIncoming(_ chunk: Data) {
        receiveBuffer.append(chunk)
        parseBuffer()
    }

    private func parseBuffer() {
        while true {
            if expectedLength == 0 {
                guard receiveBuffer.count >= 4 else {
                    if !receiveBuffer.isEmpty { startReassemblyTimeout() }
                    return
                }
                let length = Int(receiveBuffer[receiveBuffer.startIndex]) << 24
                           | Int(receiveBuffer[receiveBuffer.startIndex + 1]) << 16
                           | Int(receiveBuffer[receiveBuffer.startIndex + 2]) << 8
                           | Int(receiveBuffer[receiveBuffer.startIndex + 3])
                guard length > 0 && length <= 64 * 1024 else {
                    Logger.bluetooth.warning("invalid frame length \(length, privacy: .public), discarding")
                    resetBuffer()
                    return
                }
                expectedLength = length
                receiveBuffer.removeFirst(4)
                startReassemblyTimeout()
            }

            guard receiveBuffer.count >= expectedLength else { return }

            let message = Data(receiveBuffer.prefix(expectedLength))
            receiveBuffer.removeFirst(expectedLength)
            expectedLength = 0
            reassemblyTimeoutTask?.cancel()
            reassemblyTimeoutTask = nil
            onDataReceived?(message)
        }
    }

    private func startReassemblyTimeout() {
        reassemblyTimeoutTask?.cancel()
        reassemblyTimeoutTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            // Only reset if we are still mid-reassembly; a completed message
            // or an explicit resetBuffer() call would have cleared these.
            guard let self, self.expectedLength > 0 || !self.receiveBuffer.isEmpty else { return }
            Logger.bluetooth.warning("reassembly timeout — resetting buffer")
            self.resetBuffer()
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
            switch peripheral.state {
            case .poweredOn:
                self.setupAndAdvertise()
            case .unauthorized:
                self.onTransportError?(.bluetoothUnauthorized)
            case .unsupported:
                self.onTransportError?(.bluetoothUnsupported)
            case .poweredOff:
                if self.subscribedCentral != nil {
                    self.onPeerDisconnected?()
                }
                self.onTransportError?(.bluetoothOff)
            case .resetting, .unknown:
                break
            @unknown default:
                break
            }
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
                Logger.bluetooth.error("didAdd service error — \(error!.localizedDescription, privacy: .public)")
                return
            }
            let suffix = UUID().uuidString.prefix(6)
            let name = "\(PlayerNameProvider.broadcastName)｜\(suffix)"
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
            self.hostSendQueue.removeAll()
            self.subscribedCentral = nil
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
            switch central.state {
            case .poweredOn:
                central.scanForPeripherals(
                    withServices: [kServiceUUID],
                    options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
                )
            case .unauthorized:
                self.onTransportError?(.bluetoothUnauthorized)
            case .unsupported:
                self.onTransportError?(.bluetoothUnsupported)
            case .poweredOff:
                if self.connectedPeripheral != nil {
                    self.onPeerDisconnected?()
                }
                self.onTransportError?(.bluetoothOff)
            case .resetting, .unknown:
                break
            @unknown default:
                break
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        Task { @MainActor in
            let id = peripheral.identifier.uuidString
            guard self.peripheralByID[id] == nil else { return }
            let name = (advertisementData[CBAdvertisementDataLocalNameKey] as? String)
                ?? peripheral.name
                ?? "未知裝置"
            self.peripheralByID[id] = peripheral
            let peer = DiscoveredPeer(id: id, displayName: name)
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
            Logger.bluetooth.error("failed to connect — \(error?.localizedDescription ?? "unknown", privacy: .public)")
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
                self.guestWriteInFlight = false
                self.drainGuestQueue()
            } else if let retryData = self.pendingWriteRetry {
                self.pendingWriteRetry = nil
                // guestWriteInFlight 仍 true — retry 也算 in-flight
                peripheral.writeValue(retryData, for: characteristic, type: .withResponse)
            } else {
                self.guestWriteInFlight = false
                self.onPeerDisconnected?()
            }
        }
    }
}
