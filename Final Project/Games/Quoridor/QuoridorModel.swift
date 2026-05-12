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

    // MARK: - Wall Blocking Checks

    // Moving south from (r, c) → (r+1, c) is blocked by any hWall covering column c at row gap r.
    // hWalls[r][c] covers cols c and c+1; hWalls[r][c-1] covers cols c-1 and c.
    func isBlockedSouth(row r: Int, col c: Int) -> Bool {
        guard r < 8 else { return true }
        let byAnchorHere = c < 8 && hWalls[r][c]       // wall anchored at c, covers cols c and c+1
        let byAnchorLeft = c > 0 && hWalls[r][c - 1]   // wall anchored at c-1, right half covers c
        return byAnchorHere || byAnchorLeft
    }

    func isBlockedNorth(row r: Int, col c: Int) -> Bool {
        guard r > 0 else { return true }
        return isBlockedSouth(row: r - 1, col: c)
    }

    // Moving east from (r, c) → (r, c+1) is blocked by any vWall covering row r at col gap c.
    func isBlockedEast(row r: Int, col c: Int) -> Bool {
        guard c < 8 else { return true }
        let byAnchorHere = r < 8 && vWalls[r][c]       // wall anchored at r, covers rows r and r+1
        let byAnchorAbove = r > 0 && vWalls[r - 1][c]  // wall anchored at r-1, bottom half covers r
        return byAnchorHere || byAnchorAbove
    }

    func isBlockedWest(row r: Int, col c: Int) -> Bool {
        guard c > 0 else { return true }
        return isBlockedEast(row: r, col: c - 1)
    }

    func isBlocked(from pos: QuoridorPosition, direction: QuoridorDirection) -> Bool {
        switch direction {
        case .north: return isBlockedNorth(row: pos.row, col: pos.col)
        case .south: return isBlockedSouth(row: pos.row, col: pos.col)
        case .east:  return isBlockedEast(row: pos.row, col: pos.col)
        case .west:  return isBlockedWest(row: pos.row, col: pos.col)
        }
    }

    // MARK: - BFS Path Check

    // Returns true if there is a path from `start` to any square in `goalRow`.
    func hasPath(from start: QuoridorPosition, toRow goalRow: Int) -> Bool {
        var visited = Set<QuoridorPosition>()
        var queue = [start]
        var head = 0
        visited.insert(start)
        while head < queue.count {
            let pos = queue[head]
            head += 1
            if pos.row == goalRow { return true }
            for dir in QuoridorDirection.allCases {
                guard !isBlocked(from: pos, direction: dir) else { continue }
                let next = pos.moved(dir)
                guard next.isValid, !visited.contains(next) else { continue }
                visited.insert(next)
                queue.append(next)
            }
        }
        return false
    }
}
