//
//  BluetoothStressTests.swift
//  Final ProjectTests
//
//  Stress tests for BluetoothTransport framing and reassembly.
//  These tests are CPU-only (no real BLE hardware needed) but are marked
//  as device-only to keep CI fast.
//
//  To run on device: set BT_STRESS_ENABLED=1 in the scheme's environment variables.
//

import XCTest
@testable import Final_Project

final class BluetoothStressTests: XCTestCase {

    private var transport: BluetoothTransport!

    override func setUp() {
        super.setUp()
        guard isEnabled else { return }
        transport = BluetoothTransport()
    }

    override func tearDown() {
        transport = nil
        super.tearDown()
    }

    // MARK: - Guard

    private var isEnabled: Bool {
        ProcessInfo.processInfo.environment["BT_STRESS_ENABLED"] == "1"
    }

    private func skipIfDisabled() throws {
        try XCTSkipUnless(isEnabled, "Set BT_STRESS_ENABLED=1 to run Bluetooth stress tests")
    }

    // MARK: - Stress Tests

    func testHighVolumeSinglePacketMessages() throws {
        try skipIfDisabled()
        var count = 0
        transport.onDataReceived = { _ in count += 1 }

        for i in 0..<1000 {
            let data = Data("message-\(i)".utf8)
            for p in transport.frame(data, mtu: 512) {
                transport.handleIncoming(p)
            }
        }
        XCTAssertEqual(count, 1000)
    }

    func testHighVolumeMultiPacketMessages() throws {
        try skipIfDisabled()
        var received: [Data] = []
        transport.onDataReceived = { received.append($0) }

        let messages = (0..<200).map { i in Data(repeating: UInt8(i % 256), count: 300) }
        for msg in messages {
            for p in transport.frame(msg, mtu: 50) {
                transport.handleIncoming(p)
            }
        }
        XCTAssertEqual(received.count, messages.count)
        for (original, decoded) in zip(messages, received) {
            XCTAssertEqual(original, decoded)
        }
    }

    func testLargePayloadRoundTrip() throws {
        try skipIfDisabled()
        let original = Data(repeating: 0xAB, count: 60 * 1024)  // 60 KB — near max
        var received: Data?
        transport.onDataReceived = { received = $0 }

        for p in transport.frame(original, mtu: 185) {
            transport.handleIncoming(p)
        }
        XCTAssertEqual(received, original)
    }

    func testInterleavedSmallAndLargeMessages() throws {
        try skipIfDisabled()
        var received: [Data] = []
        transport.onDataReceived = { received.append($0) }

        let small = Data("hi".utf8)
        let large = Data(repeating: 0xFF, count: 512)

        for _ in 0..<50 {
            for p in transport.frame(small, mtu: 512) { transport.handleIncoming(p) }
            for p in transport.frame(large, mtu: 50)  { transport.handleIncoming(p) }
        }
        XCTAssertEqual(received.count, 100)
    }

    func testMinimumMTUThroughput() throws {
        try skipIfDisabled()
        var count = 0
        transport.onDataReceived = { _ in count += 1 }

        let data = Data(repeating: 0x01, count: 100)
        for _ in 0..<500 {
            for p in transport.frame(data, mtu: 20) {
                transport.handleIncoming(p)
            }
        }
        XCTAssertEqual(count, 500)
    }
}
