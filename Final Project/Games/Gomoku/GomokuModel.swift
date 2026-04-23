//
//  GomokuModel.swift
//  Final Project
//
//  Pure game logic for Gomoku (五子棋).
//  Supports configurable board size and optional 禁手 (forbidden moves).
//

import Foundation

// MARK: - Forbidden Rule Target

enum ForbiddenTarget: String, Codable, CaseIterable {
    case blackOnly = "僅黑方"
    case both = "雙方"
}

// MARK: - Gomoku Rules

struct GomokuRules: Codable {
    var boardSize: Int = 19

    // Individual forbidden move toggles
    var doubleThreeEnabled: Bool = false    // 三三禁手
    var doubleFourEnabled: Bool = false     // 四四禁手
    var overlineEnabled: Bool = false       // 長連禁手（六子以上）

    // Per-rule targeting
    var doubleThreeTarget: ForbiddenTarget = .blackOnly
    var doubleFourTarget: ForbiddenTarget = .blackOnly
    var overlineTarget: ForbiddenTarget = .blackOnly

    static let supportedBoardSizes = [15, 19, 21, 23, 25]

    /// Check if any forbidden rule applies to the given player
    func hasForbiddenRules(for player: PlayerColor) -> Bool {
        if doubleThreeEnabled && ruleApplies(target: doubleThreeTarget, player: player) { return true }
        if doubleFourEnabled && ruleApplies(target: doubleFourTarget, player: player) { return true }
        if overlineEnabled && ruleApplies(target: overlineTarget, player: player) { return true }
        return false
    }

    func ruleApplies(target: ForbiddenTarget, player: PlayerColor) -> Bool {
        switch target {
        case .blackOnly: return player == .black
        case .both: return true
        }
    }
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

        // Check forbidden moves (if any rule enabled for current player)
        if rules.hasForbiddenRules(for: currentPlayer) {
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

    // MARK: - Forbidden Move Detection (per-rule)

    /// Check if placing current player's piece at (row, col) is a forbidden move.
    /// Checks each rule independently based on its enabled state and target.
    private func isForbiddenMove(row: Int, col: Int) -> Bool {
        let playerState = CellState.from(currentPlayer)
        var tempBoard = board
        tempBoard[row][col] = playerState

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
                                              state: playerState, axis: axis)
            if lineCount == 3 {
                if isOpenLine(board: tempBoard, row: row, col: col, state: playerState, axis: axis, length: 3) {
                    threeCount += 1
                }
            } else if lineCount == 4 {
                // Only "open fours" (both ends clear) count toward the double-four rule.
                // A four blocked on one side (dead four) cannot be played around freely,
                // so it does not create the branching threat the rule is designed to prevent.
                if isOpenLine(board: tempBoard, row: row, col: col, state: playerState, axis: axis, length: 4) {
                    fourCount += 1
                }
            } else if lineCount >= 6 {
                // Overline check
                if rules.overlineEnabled && rules.ruleApplies(target: rules.overlineTarget, player: currentPlayer) {
                    return true
                }
            }
        }

        // Double-three check
        if rules.doubleThreeEnabled && rules.ruleApplies(target: rules.doubleThreeTarget, player: currentPlayer) {
            if threeCount >= 2 { return true }
        }

        // Double-four check
        if rules.doubleFourEnabled && rules.ruleApplies(target: rules.doubleFourTarget, player: currentPlayer) {
            if fourCount >= 2 { return true }
        }

        return false
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
