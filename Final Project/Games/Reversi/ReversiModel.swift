//
//  ReversiModel.swift
//  Final Project
//
//  Pure game logic for Reversi/Othello.
//  No UI or networking dependency — just value types and algorithms.
//

import Foundation

// MARK: - Cell State

enum CellState: Equatable {
    case empty
    case black
    case white

    var playerColor: PlayerColor? {
        switch self {
        case .black: return .black
        case .white: return .white
        case .empty: return nil
        }
    }

    static func from(_ player: PlayerColor) -> CellState {
        switch player {
        case .black: return .black
        case .white: return .white
        }
    }
}

// MARK: - Reversi Rules

struct ReversiRules: Codable {
    var boardSize: Int = 8
    static let supportedBoardSizes = [6, 8, 10, 12]
}

// MARK: - Reversi Model

struct ReversiModel {

    var rules: ReversiRules

    /// N×N board
    var board: [[CellState]]

    /// Whose turn it is
    var currentPlayer: PlayerColor

    /// All 8 directions: (row delta, col delta)
    private static let directions: [(Int, Int)] = [
        (-1, -1), (-1, 0), (-1, 1),
        ( 0, -1),          ( 0, 1),
        ( 1, -1), ( 1, 0), ( 1, 1)
    ]

    // MARK: - Init

    init(rules: ReversiRules = ReversiRules()) {
        self.rules = rules
        let size = rules.boardSize
        board = Array(
            repeating: Array(repeating: CellState.empty, count: size),
            count: size
        )
        currentPlayer = .black

        // Standard opening: 4 pieces in the centre
        let mid = size / 2
        board[mid - 1][mid - 1] = .white
        board[mid - 1][mid]     = .black
        board[mid][mid - 1]     = .black
        board[mid][mid]         = .white
    }

    // MARK: - Score

    func score() -> (black: Int, white: Int) {
        var b = 0, w = 0
        for row in board {
            for cell in row {
                if cell == .black { b += 1 }
                else if cell == .white { w += 1 }
            }
        }
        return (b, w)
    }

    // MARK: - Valid Moves

    /// Returns all valid positions where `player` can place a piece.
    func validMoves(for player: PlayerColor) -> [(row: Int, col: Int)] {
        var moves: [(Int, Int)] = []
        for r in 0..<rules.boardSize {
            for c in 0..<rules.boardSize {
                if board[r][c] == .empty && flippableDiscs(row: r, col: c, player: player).count > 0 {
                    moves.append((r, c))
                }
            }
        }
        return moves
    }

    // MARK: - Place Piece

    /// Place a piece at (row, col) for the current player.
    /// Returns `true` if the move was valid and applied; `false` otherwise.
    mutating func placePiece(row: Int, col: Int) -> Bool {
        guard board[row][col] == .empty else { return false }

        let flips = flippableDiscs(row: row, col: col, player: currentPlayer)
        guard !flips.isEmpty else { return false }

        // Place the piece
        board[row][col] = CellState.from(currentPlayer)

        // Flip captured pieces
        for (r, c) in flips {
            board[r][c] = CellState.from(currentPlayer)
        }

        // Switch turn
        currentPlayer = currentPlayer.opposite

        return true
    }

    // MARK: - Game Over

    /// Game is over when neither player has any valid moves.
    var isGameOver: Bool {
        return validMoves(for: .black).isEmpty && validMoves(for: .white).isEmpty
    }

    /// Returns the winner, or nil for a tie.
    var winner: PlayerColor? {
        let s = score()
        if s.black > s.white { return .black }
        if s.white > s.black { return .white }
        return nil
    }

    // MARK: - Skip Turn

    /// If the current player has no moves but the opponent does, skip the turn.
    /// Returns `true` if the turn was skipped.
    mutating func skipTurnIfNeeded() -> Bool {
        if validMoves(for: currentPlayer).isEmpty && !validMoves(for: currentPlayer.opposite).isEmpty {
            currentPlayer = currentPlayer.opposite
            return true
        }
        return false
    }

    // MARK: - Flip Algorithm

    /// Returns all disc positions that would be flipped if `player` places at (row, col).
    private func flippableDiscs(row: Int, col: Int, player: PlayerColor) -> [(Int, Int)] {
        let own = CellState.from(player)
        let opponent = CellState.from(player.opposite)
        var allFlips: [(Int, Int)] = []

        for (dr, dc) in ReversiModel.directions {
            var flips: [(Int, Int)] = []
            var r = row + dr
            var c = col + dc

            // Walk in this direction, collecting opponent pieces
            while r >= 0 && r < rules.boardSize &&
                  c >= 0 && c < rules.boardSize &&
                  board[r][c] == opponent {
                flips.append((r, c))
                r += dr
                c += dc
            }

            // Valid only if we end on our own piece (and flipped at least one)
            if r >= 0 && r < rules.boardSize &&
               c >= 0 && c < rules.boardSize &&
               board[r][c] == own && !flips.isEmpty {
                allFlips.append(contentsOf: flips)
            }
        }

        return allFlips
    }

    // MARK: - Reset

    mutating func reset() {
        self = ReversiModel(rules: rules)
    }
}
