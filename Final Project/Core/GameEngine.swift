//
//  GameEngine.swift
//  Final Project
//
//  Core protocol that all games must conform to.
//  The lobby, room, and networking layers only talk to this protocol.
//

import SwiftUI

// MARK: - Player Color

enum PlayerColor: String, Codable {
    case black
    case white

    var opposite: PlayerColor {
        switch self {
        case .black: return .white
        case .white: return .black
        }
    }

    var displayName: String {
        switch self {
        case .black: return "黑方"
        case .white: return "白方"
        }
    }
}

// MARK: - Message Envelope (game-agnostic networking)

enum MessageType: String, Codable {
    case startGame
    case playerMove
    case setRules
    case gameOver
    case chat
    case restartVote
    case restartResponse
    /// Sent by a peer right before they intentionally leave the room so the other
    /// side can show a non-blocking banner instead of a generic "disconnected" alert.
    case peerLeftRoom
}

struct MessageEnvelope: Codable {
    let type: MessageType
    let gameType: String?   // e.g., "reversi", "gomoku"; nil for system-level messages
    let payload: Data       // game-specific JSON encoded data

    func encode() -> Data? {
        try? JSONEncoder().encode(self)
    }

    static func decode(from data: Data) -> MessageEnvelope? {
        try? JSONDecoder().decode(MessageEnvelope.self, from: data)
    }
}

// MARK: - Move Message (common payload for board games)

struct MoveMessage: Codable {
    let row: Int
    let col: Int

    func toData() -> Data {
        try! JSONEncoder().encode(self)
    }

    static func fromData(_ data: Data) -> MoveMessage? {
        try? JSONDecoder().decode(MoveMessage.self, from: data)
    }
}

// MARK: - Chat Message

struct ChatMessage: Codable, Identifiable {
    let id: UUID
    let text: String
    let isFromMe: Bool
    let timestamp: Date

    init(text: String, isFromMe: Bool) {
        self.id = UUID()
        self.text = text
        self.isFromMe = isFromMe
        self.timestamp = Date()
    }

    func toData() -> Data {
        try! JSONEncoder().encode(self)
    }

    static func fromData(_ data: Data) -> ChatMessage? {
        try? JSONDecoder().decode(ChatMessage.self, from: data)
    }
}

// MARK: - Start Game Payload

/// Sent by host → guest when a game starts. Carries the game type identifier
/// and the game-specific encoded settings so the guest can construct a
/// matching engine.
struct StartGamePayload: Codable {
    let gameType: String
    let settings: Data
}

// MARK: - Restart Vote Response

struct RestartResponsePayload: Codable {
    let accepted: Bool

    func toData() -> Data {
        try! JSONEncoder().encode(self)
    }

    static func fromData(_ data: Data) -> RestartResponsePayload? {
        try? JSONDecoder().decode(RestartResponsePayload.self, from: data)
    }
}

// MARK: - Game Engine Protocol Extension (shared helpers)

extension GameEngine {
    /// Encodes a player move and sends it to the peer via `onMoveToSend`.
    /// No-op in single-player mode. Call this immediately after a valid placement.
    func sendMoveEnvelope(row: Int, col: Int, gameType: String) {
        guard isMultiplayer else { return }
        let move = MoveMessage(row: row, col: col)
        let envelope = MessageEnvelope(type: .playerMove, gameType: gameType, payload: move.toData())
        onMoveToSend?(envelope)
    }
}

// MARK: - Game Engine Protocol

/// All games must conform to this protocol to plug into the platform.
/// The Core layer (Lobby, Room, MultipeerManager) only interacts through this interface.
protocol GameEngine: AnyObject, Observable {
    // MARK: Identity
    static var gameTitle: String { get }
    static var gameIcon: String { get }  // SF Symbol name
    static var gameType: String { get }  // unique identifier, e.g. "reversi"

    // MARK: State
    var currentPlayer: PlayerColor { get }
    var scores: (black: Int, white: Int) { get }
    var isGameOver: Bool { get }
    var statusMessage: String { get }
    var boardSize: Int { get }

    // MARK: Multiplayer
    var isMultiplayer: Bool { get set }
    var localPlayer: PlayerColor { get set }

    // MARK: Move Confirmation
    var pendingMove: (row: Int, col: Int)? { get }
    func confirmMove()
    func cancelMove()

    // MARK: Actions
    func handleTap(row: Int, col: Int) -> Bool
    func receiveRemoteMove(data: Data)
    func reset()

    // MARK: Settings
    /// Each game provides its own settings UI (shown in Room before game starts).
    @ViewBuilder func makeSettingsView() -> AnyView
    /// Export current settings as Data to send to peer via .setRules envelope.
    func exportSettings() -> Data
    /// Apply settings received from peer.
    func applySettings(data: Data)

    // MARK: Network Hook
    /// Set by the Room/networking layer. Called when a move needs to be sent to the peer.
    var onMoveToSend: ((MessageEnvelope) -> Void)? { get set }

    /// Set by the Room layer. Called when the player requests a restart (triggers voting in multiplayer).
    var onRestartRequested: (() -> Void)? { get set }

    // MARK: View Factory
    @ViewBuilder func makeGameView() -> AnyView
}
