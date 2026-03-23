//
//  GomokuModel.swift
//  Final Project
//
//  Pure game logic for Gomoku (五子棋).
//  Supports configurable board size and optional 禁手 (forbidden moves).
//

import Foundation

// MARK: - Gomoku Rules

struct GomokuRules: Codable {
    var boardSize: Int = 19
    var forbiddenMovesEnabled: Bool = false  // 三三禁手、四四禁手、長連禁手

    static let supportedBoardSizes = [15, 19, 21, 23, 25]
}

// MARK: - Gomoku Model

struct GomokuModel {

    var rules: GomokuRules
    var board: [[CellState]]
    var currentPlayer: PlayerColor
    var lastMove: (row: Int, col: Int)?

    /// All 8 directions
    private static let directions: [(Int, Int)] = [
        (-1, -1), (-1, 0), (-1, 1),
        ( 0, -1),          ( 0, 1),
        ( 1, -1), ( 1, 0), ( 1, 1)
    ]

    // MARK: - Init

    init(rules: GomokuRules = GomokuRules()) {
        self.rules = rules
        self.board = Array(
            repeating: Array(repeating: CellState.empty, count: rules.boardSize),
            count: rules.boardSize
        )
        self.currentPlayer = .black
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

    // MARK: - Place Piece

    mutating func placePiece(row: Int, col: Int) -> Bool {
        guard row >= 0 && row < rules.boardSize &&
              col >= 0 && col < rules.boardSize &&
              board[row][col] == .empty else {
            return false
        }

        // Check forbidden moves for black (if enabled)
        if rules.forbiddenMovesEnabled && currentPlayer == .black {
            if isForbiddenMove(row: row, col: col) {
                return false
            }
        }

        board[row][col] = CellState.from(currentPlayer)
        lastMove = (row, col)
        currentPlayer = currentPlayer.opposite
        return true
    }

    // MARK: - Win Check

    /// Check if the last move resulted in a win (5+ in a row).
    func checkWin() -> PlayerColor? {
        guard let last = lastMove else { return nil }
        let state = board[last.row][last.col]
        guard state != .empty else { return nil }

        // Check 4 axes: horizontal, vertical, diagonal-down, diagonal-up
        let axes: [[(Int, Int)]] = [
            [( 0, -1), ( 0,  1)],  // horizontal
            [(-1,  0), ( 1,  0)],  // vertical
            [(-1, -1), ( 1,  1)],  // diagonal ↘
            [(-1,  1), ( 1, -1)],  // diagonal ↗
        ]

        for axis in axes {
            var count = 1

            for (dr, dc) in axis {
                var r = last.row + dr
                var c = last.col + dc
                while r >= 0 && r < rules.boardSize &&
                      c >= 0 && c < rules.boardSize &&
                      board[r][c] == state {
                    count += 1
                    r += dr
                    c += dc
                }
            }

            if count >= 5 {
                return state.playerColor
            }
        }

        return nil
    }

    // MARK: - Game Over

    var isGameOver: Bool {
        if checkWin() != nil { return true }
        // Check if board is full
        return board.allSatisfy { row in row.allSatisfy { $0 != .empty } }
    }

    var winner: PlayerColor? {
        checkWin()
    }

    // MARK: - Forbidden Move Detection (簡化版)

    /// Check if placing black at (row, col) is a forbidden move.
    /// Simplified: checks for double-three (三三) and double-four (四四).
    private func isForbiddenMove(row: Int, col: Int) -> Bool {
        // Temporarily place the piece
        var tempBoard = board
        tempBoard[row][col] = .black

        var threeCount = 0
        var fourCount = 0

        let axes: [[(Int, Int)]] = [
            [( 0, -1), ( 0,  1)],
            [(-1,  0), ( 1,  0)],
            [(-1, -1), ( 1,  1)],
            [(-1,  1), ( 1, -1)],
        ]

        for axis in axes {
            let lineCount = countInDirection(board: tempBoard, row: row, col: col,
                                              state: .black, axis: axis)
            if lineCount == 3 {
                // Check if it's an "open three" (both ends open)
                if isOpenLine(board: tempBoard, row: row, col: col, state: .black, axis: axis, length: 3) {
                    threeCount += 1
                }
            } else if lineCount == 4 {
                fourCount += 1
            } else if lineCount >= 6 {
                return true // Overline forbidden
            }
        }

        return threeCount >= 2 || fourCount >= 2
    }

    private func countInDirection(board: [[CellState]], row: Int, col: Int,
                                   state: CellState, axis: [(Int, Int)]) -> Int {
        var count = 1
        for (dr, dc) in axis {
            var r = row + dr
            var c = col + dc
            while r >= 0 && r < rules.boardSize &&
                  c >= 0 && c < rules.boardSize &&
                  board[r][c] == state {
                count += 1
                r += dr
                c += dc
            }
        }
        return count
    }

    private func isOpenLine(board: [[CellState]], row: Int, col: Int,
                             state: CellState, axis: [(Int, Int)], length: Int) -> Bool {
        // Check if both ends of the line are empty
        for (dr, dc) in axis {
            var r = row + dr
            var c = col + dc
            while r >= 0 && r < rules.boardSize &&
                  c >= 0 && c < rules.boardSize &&
                  board[r][c] == state {
                r += dr
                c += dc
            }
            // End of line — check if this cell is empty
            if r < 0 || r >= rules.boardSize || c < 0 || c >= rules.boardSize {
                return false  // Hit the wall
            }
            if board[r][c] != .empty {
                return false  // Blocked
            }
        }
        return true
    }

    // MARK: - Reset

    mutating func reset() {
        self = GomokuModel(rules: rules)
    }
}
