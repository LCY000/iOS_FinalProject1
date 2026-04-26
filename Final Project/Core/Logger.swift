//
//  Logger.swift
//  Final Project
//
//  Centralized OSLog loggers. Use instead of print() for structured logging.
//  OSLog output is visible in Console.app and Instruments.
//

import OSLog

extension Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.finalproject"

    /// Bluetooth / BLE transport events (framing, connection lifecycle).
    static let bluetooth = Logger(subsystem: subsystem, category: "bluetooth")

    /// MultipeerConnectivity (WiFi) transport events.
    static let mpc = Logger(subsystem: subsystem, category: "mpc")

    /// Game session coordination (envelope routing, version checks, desync).
    static let session = Logger(subsystem: subsystem, category: "session")

    /// Game logic events (move placement, rule checks, state changes).
    static let game = Logger(subsystem: subsystem, category: "game")
}
