//
//  BluetoothTransportTests.swift
//  Final ProjectTests
//
//  Unit tests for BluetoothTransport framing and reassembly.
//  These tests run on simulator — no real Bluetooth hardware required.
//

import XCTest
@testable import Final_Project

final class BluetoothTransportTests: XCTestCase {

    private var transport: BluetoothTransport!

    override func setUp() {
        super.setUp()
        transport = BluetoothTransport()
    }

    override func tearDown() {
        transport = nil
        super.tearDown()
    }

    // MARK: - Framing

    func testFrameSmallDataSinglePacket() {
        let data = Data("hello".utf8)
        let packets = transport.frame(data, mtu: 512)
        XCTAssertEqual(packets.count, 1)
        // Header (4 bytes) + payload
        XCTAssertEqual(packets[0].count, 4 + data.count)
    }

    func testFrameLargeDataMultiplePackets() {
        let data = Data(repeating: 0xAB, count: 500)
        let mtu = 100
        let packets = transport.frame(data, mtu: mtu)
        // 4-byte header + 500 bytes = 504 bytes → ceil(504/100) = 6 packets
        XCTAssertEqual(packets.count, 6)
        // All packets ≤ mtu
        for p in packets { XCTAssertLessThanOrEqual(p.count, mtu) }
    }

    func testFrameHeaderEncodesBigEndianLength() {
        let data = Data(repeating: 0x00, count: 300)
        let packets = transport.frame(data, mtu: 512)
        let first = packets[0]
        let length = Int(first[0]) << 24 | Int(first[1]) << 16 | Int(first[2]) << 8 | Int(first[3])
        XCTAssertEqual(length, 300)
    }

    func testFrameRespectsMTUMinimumOf20() {
        let data = Data(repeating: 0xFF, count: 50)
        let packets = transport.frame(data, mtu: 5)   // 5 < 20, should be clamped to 20
        for p in packets { XCTAssertLessThanOrEqual(p.count, 20) }
    }

    // MARK: - Reassembly (round-trip)

    func testRoundTripSinglePacket() {
        let original = Data("board:move:3,5".utf8)
        var received: Data?
        transport.onDataReceived = { received = $0 }

        let packets = transport.frame(original, mtu: 512)
        for p in packets { transport.handleIncoming(p) }

        XCTAssertEqual(received, original)
    }

    func testRoundTripMultiPacket() {
        let original = Data(repeating: 0xCD, count: 500)
        var received: Data?
        transport.onDataReceived = { received = $0 }

        let packets = transport.frame(original, mtu: 60)
        for p in packets { transport.handleIncoming(p) }

        XCTAssertEqual(received, original)
    }

    func testRoundTripEmptyPayload() {
        // Zero-length payload should be rejected (guard length > 0)
        var callCount = 0
        transport.onDataReceived = { _ in callCount += 1 }

        let header = withUnsafeBytes(of: UInt32(0).bigEndian) { Data($0) }
        transport.handleIncoming(header)

        XCTAssertEqual(callCount, 0, "Zero-length frame must be discarded")
    }

    func testOversizeFrameDiscarded() {
        var callCount = 0
        transport.onDataReceived = { _ in callCount += 1 }

        // Length 128KB > 64KB limit
        let header = withUnsafeBytes(of: UInt32(128 * 1024).bigEndian) { Data($0) }
        transport.handleIncoming(header)

        XCTAssertEqual(callCount, 0, "Over-size frame must be discarded")
    }

    func testSequentialMessagesAreDeliveredInOrder() {
        var received: [Data] = []
        transport.onDataReceived = { received.append($0) }

        let messages = (1...5).map { i in Data("msg\(i)".utf8) }
        for msg in messages {
            let packets = transport.frame(msg, mtu: 512)
            for p in packets { transport.handleIncoming(p) }
        }

        XCTAssertEqual(received, messages)
    }
}
