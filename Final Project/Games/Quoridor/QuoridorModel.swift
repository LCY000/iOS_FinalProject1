//
//  QuoridorModel.swift
//  Final Project
//
//  Foundational data structures for the Quoridor board game.
//  PlayerColor is defined in Core/GameEngine.swift — do not redefine here.
//

import Foundation

// MARK: - Position

struct QuoridorPosition: Equatable, Hashable, Codable, Sendable {
    let row: Int  // 0–8, canonical: 0 = north (black starts at row 0)
    let col: Int  // 0–8

    var isValid: Bool { (0...8).contains(row) && (0...8).contains(col) }

    func moved(_ dir: QuoridorDirection) -> QuoridorPosition {
        switch dir {
        case .north: return QuoridorPosition(row: row - 1, col: col)
        case .south: return QuoridorPosition(row: row + 1, col: col)
        case .east:  return QuoridorPosition(row: row, col: col + 1)
        case .west:  return QuoridorPosition(row: row, col: col - 1)
        }
    }
}

// MARK: - Direction

enum QuoridorDirection: CaseIterable, Sendable {
    case north, south, east, west

    var perpendiculars: [QuoridorDirection] {
        switch self {
        case .north, .south: return [.east, .west]
        case .east, .west:   return [.north, .south]
        }
    }
}

// MARK: - Move

enum QuoridorMoveKind: String, Codable, Sendable {
    case pawn
    case wallH  // horizontal: spans (row r↔r+1) at cols c and c+1
    case wallV  // vertical:   spans (col c↔c+1) at rows r and r+1
}

struct QuoridorMove: Codable, Sendable {
    let kind: QuoridorMoveKind
    let row: Int
    let col: Int
    let seq: UInt32

    func toData() -> Data { (try? JSONEncoder().encode(self)) ?? Data() }
    static func fromData(_ data: Data) -> QuoridorMove? {
        try? JSONDecoder().decode(QuoridorMove.self, from: data)
    }
}

// MARK: - Model

struct QuoridorModel: Sendable {
    static let boardSize = 9

    // Canonical: black starts north (row 0), white starts south (row 8)
    var positions: [PlayerColor: QuoridorPosition] = [
        .black: QuoridorPosition(row: 0, col: 4),
        .white: QuoridorPosition(row: 8, col: 4)
    ]
    var wallCounts: [PlayerColor: Int] = [.black: 10, .white: 10]

    // hWalls[r][c]: horizontal wall between rows r↔r+1, spanning cols c and c+1
    // r ∈ [0,7], c ∈ [0,7]
    var hWalls: [[Bool]] = Array(repeating: Array(repeating: false, count: 8), count: 8)

    // vWalls[r][c]: vertical wall between cols c↔c+1, spanning rows r and r+1
    // r ∈ [0,7], c ∈ [0,7]
    var vWalls: [[Bool]] = Array(repeating: Array(repeating: false, count: 8), count: 8)

    var currentPlayer: PlayerColor = .black
    var winner: PlayerColor?
    var isGameOver: Bool { winner != nil }
    var lastMove: QuoridorMove?
}
