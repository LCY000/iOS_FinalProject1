// CheckersModel.swift
// Final Project
//
// Foundational data structures for the Checkers game.
// PlayerColor is defined in Core/GameEngine.swift — same module, do NOT redefine.

import Foundation

// MARK: - Piece

enum CheckersPiece: Equatable {
    case empty
    case man(PlayerColor)   // 普通棋
    case king(PlayerColor)  // 王

    var owner: PlayerColor? {
        switch self {
        case .man(let p), .king(let p): return p
        case .empty: return nil
        }
    }

    var isKing: Bool {
        if case .king = self { return true }
        return false
    }

    var isEmpty: Bool { self == .empty }
}

// MARK: - Position

struct CheckersPosition: Equatable, Hashable, Codable {
    let row: Int
    let col: Int
}

// MARK: - Variant

enum CheckersVariant: String, Codable {
    case american      // 8×8, non-flying kings
    case international // 10×10, flying kings, max-capture mandatory
}

// MARK: - Move Payload (for networking)

struct CheckersMovePayload: Codable {
    let path: [CheckersPosition]        // full route including start
    let captures: [CheckersPosition]    // all captured squares
    let promoted: Bool
    let seq: UInt32

    func toData() -> Data { (try? JSONEncoder().encode(self)) ?? Data() }
    static func fromData(_ data: Data) -> CheckersMovePayload? {
        try? JSONDecoder().decode(CheckersMovePayload.self, from: data)
    }
}

// MARK: - Model

struct CheckersModel {
    var board: [[CheckersPiece]]
    var currentPlayer: PlayerColor = .black
    var winner: PlayerColor?
    var variant: CheckersVariant

    var boardSize: Int { board.count }
    var isGameOver: Bool { winner != nil }

    // MARK: - Init

    init(variant: CheckersVariant = .american) {
        self.variant = variant
        let size = variant == .american ? 8 : 10
        board = Array(repeating: Array(repeating: CheckersPiece.empty, count: size), count: size)
        placeInitialPieces()
    }

    private mutating func placeInitialPieces() {
        let size = boardSize
        let rows = variant == .american ? 3 : 4  // rows of pieces per side
        // Black pieces on top (rows 0..<rows), only dark squares (row+col odd)
        for r in 0..<rows {
            for c in 0..<size where (r + c) % 2 == 1 {
                board[r][c] = .man(.black)
            }
        }
        // White pieces on bottom (last `rows` rows)
        for r in (size - rows)..<size {
            for c in 0..<size where (r + c) % 2 == 1 {
                board[r][c] = .man(.white)
            }
        }
    }

    mutating func reset() {
        let v = variant
        self = CheckersModel(variant: v)
    }
}
