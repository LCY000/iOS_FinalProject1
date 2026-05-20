// CheckersModel.swift
// Final Project
//
// Foundational data structures for the Checkers game.
// PlayerColor is defined in Core/GameEngine.swift — same module, do NOT redefine.

import Foundation

// MARK: - Piece

enum CheckersPiece: Equatable, Sendable {
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

struct CheckersPosition: Equatable, Hashable, Codable, Sendable {
    let row: Int
    let col: Int
}

// MARK: - Variant

enum CheckersVariant: String, Codable, Sendable {
    case american      // 8×8, non-flying kings
    case international // 10×10, flying kings, max-capture mandatory
}

// MARK: - Move Payload (for networking)

struct CheckersMovePayload: Codable, Sendable {
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

struct CheckersModel: Sendable {
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

// MARK: - Jump

struct CheckersJump: Codable, Sendable {
    let from: CheckersPosition
    let over: CheckersPosition
    let to: CheckersPosition
}

// MARK: - Move Generation

extension CheckersModel {

    private func forwardDirs(for player: PlayerColor) -> [(Int, Int)] {
        player == .black ? [(1, -1), (1, 1)] : [(-1, -1), (-1, 1)]
    }

    private func allDirs() -> [(Int, Int)] { [(1,-1),(1,1),(-1,-1),(-1,1)] }

    private func inBounds(_ r: Int, _ c: Int) -> Bool {
        (0..<boardSize).contains(r) && (0..<boardSize).contains(c)
    }

    func simpleMoves(for player: PlayerColor) -> [(CheckersPosition, CheckersPosition)] {
        var result: [(CheckersPosition, CheckersPosition)] = []
        for r in 0..<boardSize {
            for c in 0..<boardSize {
                let piece = board[r][c]
                guard piece.owner == player else { continue }
                let dirs = (piece.isKing || variant == .international) ? allDirs() : forwardDirs(for: player)
                for (dr, dc) in dirs {
                    if variant == .international && piece.isKing {
                        var nr = r + dr; var nc = c + dc
                        while inBounds(nr, nc) && board[nr][nc].isEmpty {
                            result.append((CheckersPosition(row: r, col: c),
                                           CheckersPosition(row: nr, col: nc)))
                            nr += dr; nc += dc
                        }
                    } else {
                        let nr = r + dr; let nc = c + dc
                        if inBounds(nr, nc) && board[nr][nc].isEmpty {
                            result.append((CheckersPosition(row: r, col: c),
                                           CheckersPosition(row: nr, col: nc)))
                        }
                    }
                }
            }
        }
        return result
    }

    func captureSequences(
        from pos: CheckersPosition,
        piece: CheckersPiece,
        board intermediateBoard: [[CheckersPiece]],
        visited: Set<CheckersPosition>
    ) -> [[CheckersJump]] {
        guard let pieceOwner = piece.owner else { return [] }
        let dirs = (piece.isKing || variant == .international) ? allDirs() : forwardDirs(for: pieceOwner)
        var sequences: [[CheckersJump]] = []

        for (dr, dc) in dirs {
            if variant == .international && piece.isKing {
                var nr = pos.row + dr; var nc = pos.col + dc
                while inBounds(nr, nc) && intermediateBoard[nr][nc].isEmpty {
                    nr += dr; nc += dc
                }
                guard inBounds(nr, nc),
                      let owner = intermediateBoard[nr][nc].owner,
                      owner != pieceOwner,
                      !visited.contains(CheckersPosition(row: nr, col: nc)) else { continue }
                let capPos = CheckersPosition(row: nr, col: nc)
                nr += dr; nc += dc
                while inBounds(nr, nc) && intermediateBoard[nr][nc].isEmpty {
                    let landPos = CheckersPosition(row: nr, col: nc)
                    let jump = CheckersJump(from: pos, over: capPos, to: landPos)
                    var nextBoard = intermediateBoard
                    nextBoard[pos.row][pos.col] = .empty
                    nextBoard[capPos.row][capPos.col] = .empty
                    nextBoard[landPos.row][landPos.col] = piece
                    let sub = captureSequences(from: landPos, piece: piece,
                                               board: nextBoard,
                                               visited: visited.union([capPos]))
                    if sub.isEmpty {
                        sequences.append([jump])
                    } else {
                        for s in sub { sequences.append([jump] + s) }
                    }
                    nr += dr; nc += dc
                }
            } else {
                let mr = pos.row + dr; let mc = pos.col + dc
                let lr = pos.row + 2*dr; let lc = pos.col + 2*dc
                guard inBounds(lr, lc),
                      let midOwner = intermediateBoard[mr][mc].owner,
                      midOwner != pieceOwner,
                      intermediateBoard[lr][lc].isEmpty,
                      !visited.contains(CheckersPosition(row: mr, col: mc)) else { continue }
                let capPos  = CheckersPosition(row: mr, col: mc)
                let landPos = CheckersPosition(row: lr, col: lc)
                let jump = CheckersJump(from: pos, over: capPos, to: landPos)
                var nextBoard = intermediateBoard
                nextBoard[pos.row][pos.col] = .empty
                nextBoard[capPos.row][capPos.col] = .empty
                nextBoard[landPos.row][landPos.col] = piece
                let sub = captureSequences(from: landPos, piece: piece,
                                           board: nextBoard,
                                           visited: visited.union([capPos]))
                if sub.isEmpty {
                    sequences.append([jump])
                } else {
                    for s in sub { sequences.append([jump] + s) }
                }
            }
        }
        return sequences
    }

    func allCaptureSequences(for player: PlayerColor) -> [[CheckersJump]] {
        var all: [[CheckersJump]] = []
        for r in 0..<boardSize {
            for c in 0..<boardSize {
                let piece = board[r][c]
                guard piece.owner == player else { continue }
                let seqs = captureSequences(from: CheckersPosition(row: r, col: c),
                                            piece: piece,
                                            board: board,
                                            visited: [])
                all += seqs
            }
        }
        if variant == .international && !all.isEmpty {
            let maxLen = all.map(\.count).max()!
            return all.filter { $0.count == maxLen }
        }
        return all
    }

    func validMoves(for player: PlayerColor) -> [(from: CheckersPosition, to: CheckersPosition, path: [CheckersPosition], captures: [CheckersPosition])] {
        let captureSeqs = allCaptureSequences(for: player)
        if !captureSeqs.isEmpty {
            return captureSeqs.map { seq in
                let path = [seq.first!.from] + seq.map(\.to)
                return (from: seq.first!.from, to: seq.last!.to, path: path, captures: seq.map(\.over))
            }
        }
        return simpleMoves(for: player).map { (from: $0.0, to: $0.1, path: [$0.0, $0.1], captures: []) }
    }
}

// MARK: - Apply Move

extension CheckersModel {

    // Applies a complete move (possibly multi-jump).
    // `path`: full sequence of positions [start, land1, land2, ...]
    // `captures`: all captured squares
    @discardableResult
    mutating func applyMove(path: [CheckersPosition], captures: [CheckersPosition]) -> Bool {
        guard let from = path.first, let to = path.last else { return false }
        let piece = board[from.row][from.col]
        guard piece.owner == currentPlayer else { return false }

        // Remove captured pieces
        for cap in captures { board[cap.row][cap.col] = .empty }
        // Move piece
        board[from.row][from.col] = .empty
        board[to.row][to.col] = piece

        // King promotion (only at end of full turn)
        let promoted = tryPromote(at: to)

        checkWinner()
        if winner == nil { currentPlayer = currentPlayer.opposite }
        return promoted
    }

    // Returns true if promotion happened
    @discardableResult
    private mutating func tryPromote(at pos: CheckersPosition) -> Bool {
        let piece = board[pos.row][pos.col]
        guard case .man(let owner) = piece else { return false }
        let kingRow = (owner == .black) ? boardSize - 1 : 0
        guard pos.row == kingRow else { return false }
        board[pos.row][pos.col] = .king(owner)
        return true
    }

    private mutating func checkWinner() {
        let opp = currentPlayer.opposite
        let oppMoves = validMoves(for: opp)
        if oppMoves.isEmpty { winner = currentPlayer }
    }
}
