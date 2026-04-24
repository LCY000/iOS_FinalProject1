//
//  GomokuModelTests.swift
//  Final ProjectTests
//
//  Unit tests for GomokuModel pure game logic, including five-in-a-row detection
//  and all three forbidden move rules (三三 / 四四 / 長連).
//
//  Setup: add a Unit Testing Bundle target "Final ProjectTests" in Xcode and
//  include this file.
//

import XCTest
@testable import Final_Project

final class GomokuModelTests: XCTestCase {

    // MARK: - Initial State

    func testInitialBoardIsEmpty() {
        let model = GomokuModel()
        for row in model.board {
            for cell in row {
                XCTAssertEqual(cell, .empty)
            }
        }
    }

    func testDefaultBoardSize() {
        let model = GomokuModel()
        XCTAssertEqual(model.rules.boardSize, 19)
        XCTAssertEqual(model.board.count, 19)
        XCTAssertEqual(model.board[0].count, 19)
    }

    func testInitialCurrentPlayerIsBlack() {
        let model = GomokuModel()
        XCTAssertEqual(model.currentPlayer, .black)
    }

    func testInitialLastMoveIsNil() {
        let model = GomokuModel()
        XCTAssertNil(model.lastMove)
    }

    // MARK: - Place Piece

    func testPlacePieceSucceeds() {
        var model = GomokuModel()
        XCTAssertTrue(model.placePiece(row: 9, col: 9))
        XCTAssertEqual(model.board[9][9], .black)
    }

    func testPlacePieceAdvancesPlayer() {
        var model = GomokuModel()
        _ = model.placePiece(row: 9, col: 9)
        XCTAssertEqual(model.currentPlayer, .white)
    }

    func testPlacePieceSetsLastMove() {
        var model = GomokuModel()
        _ = model.placePiece(row: 5, col: 7)
        XCTAssertEqual(model.lastMove?.row, 5)
        XCTAssertEqual(model.lastMove?.col, 7)
    }

    func testPlacePieceFailsOnOccupied() {
        var model = GomokuModel()
        _ = model.placePiece(row: 9, col: 9)
        XCTAssertFalse(model.placePiece(row: 9, col: 9))
    }

    func testPlacePieceFailsOutOfBounds() {
        var model = GomokuModel()
        XCTAssertFalse(model.placePiece(row: -1, col: 0))
        XCTAssertFalse(model.placePiece(row: 0, col: 19))
    }

    // MARK: - Win Detection (checkWin)

    /// Helper: fill a line of `count` stones for `player` starting at `start`,
    /// advancing by `delta`, and set `lastMove` to the final position.
    private func fillLine(
        model: inout GomokuModel,
        start: (row: Int, col: Int),
        delta: (dr: Int, dc: Int),
        player: PlayerColor,
        count: Int
    ) {
        let state = CellState.from(player)
        for i in 0..<count {
            let r = start.row + i * delta.dr
            let c = start.col + i * delta.dc
            model.board[r][c] = state
        }
        let lastR = start.row + (count - 1) * delta.dr
        let lastC = start.col + (count - 1) * delta.dc
        model.lastMove = (lastR, lastC)
        model.currentPlayer = player.opposite
    }

    func testCheckWinHorizontal5() {
        var model = GomokuModel()
        fillLine(model: &model, start: (5, 5), delta: (0, 1), player: .black, count: 5)
        XCTAssertEqual(model.checkWin(), .black)
    }

    func testCheckWinVertical5() {
        var model = GomokuModel()
        fillLine(model: &model, start: (5, 5), delta: (1, 0), player: .black, count: 5)
        XCTAssertEqual(model.checkWin(), .black)
    }

    func testCheckWinDiagonalDownRight5() {
        var model = GomokuModel()
        fillLine(model: &model, start: (5, 5), delta: (1, 1), player: .white, count: 5)
        XCTAssertEqual(model.checkWin(), .white)
    }

    func testCheckWinDiagonalUpRight5() {
        var model = GomokuModel()
        fillLine(model: &model, start: (9, 5), delta: (-1, 1), player: .black, count: 5)
        XCTAssertEqual(model.checkWin(), .black)
    }

    func testCheckWinNilFor4InARow() {
        var model = GomokuModel()
        fillLine(model: &model, start: (5, 5), delta: (0, 1), player: .black, count: 4)
        XCTAssertNil(model.checkWin())
    }

    func testCheckWinForSixInARow() {
        // 6+ in a row still wins unless overline rule blocks placement
        var model = GomokuModel()
        fillLine(model: &model, start: (5, 5), delta: (0, 1), player: .black, count: 6)
        XCTAssertEqual(model.checkWin(), .black)
    }

    func testCheckWinNilWhenNoPieceAtLastMove() {
        var model = GomokuModel()
        model.lastMove = (5, 5)  // lastMove set but board[5][5] is empty
        XCTAssertNil(model.checkWin())
    }

    // MARK: - Game Over

    func testGameOverWhenBoardFull() {
        var rules = GomokuRules()
        rules.boardSize = 15
        var model = GomokuModel(rules: rules)
        for r in 0..<15 {
            for c in 0..<15 {
                model.board[r][c] = (r + c) % 2 == 0 ? .black : .white
            }
        }
        // No 5-in-a-row with alternating stones, but board is full
        XCTAssertTrue(model.isGameOver)
    }

    // MARK: - Forbidden: Double-Three (三三)

    func testDoubleThreeForbidsPlacement() {
        var rules = GomokuRules()
        rules.boardSize = 15
        rules.doubleThreeEnabled = true
        rules.doubleThreeTarget = .blackOnly
        var model = GomokuModel(rules: rules)

        // Set up open threes in two axes converging at (7,7):
        // Horizontal open-3: B(7,5) B(7,6) → play (7,7) extends to 3 with both ends open
        model.board[7][5] = .black
        model.board[7][6] = .black
        // Vertical open-3: B(5,7) B(6,7) → play (7,7)
        model.board[5][7] = .black
        model.board[6][7] = .black

        XCTAssertFalse(model.placePiece(row: 7, col: 7),
                       "Double-three should be forbidden for black")
    }

    func testDoubleThreeNotAppliedToWhite() {
        var rules = GomokuRules()
        rules.boardSize = 15
        rules.doubleThreeEnabled = true
        rules.doubleThreeTarget = .blackOnly  // only black is restricted
        var model = GomokuModel(rules: rules)

        // Same double-three setup but for white
        model.board[7][5] = .white
        model.board[7][6] = .white
        model.board[5][7] = .white
        model.board[6][7] = .white
        model.currentPlayer = .white

        // White is NOT restricted — placement should succeed
        XCTAssertTrue(model.placePiece(row: 7, col: 7),
                      "Double-three should not be forbidden for white when target is blackOnly")
    }

    // MARK: - Forbidden: Double-Four (四四) — Open-Four Fix

    func testDoubleFourForbidsOpenFours() {
        var rules = GomokuRules()
        rules.boardSize = 15
        rules.doubleFourEnabled = true
        rules.doubleFourTarget = .blackOnly
        var model = GomokuModel(rules: rules)

        // Two open fours converging at (7,7): both axes have empty ends on both sides
        // Horizontal: B(7,4) B(7,5) B(7,6)  — playing (7,7) makes 4, ends (7,3) and (7,8) empty
        model.board[7][4] = .black
        model.board[7][5] = .black
        model.board[7][6] = .black
        // Vertical: B(4,7) B(5,7) B(6,7) — playing (7,7) makes 4, ends (3,7) and (8,7) empty
        model.board[4][7] = .black
        model.board[5][7] = .black
        model.board[6][7] = .black

        XCTAssertFalse(model.placePiece(row: 7, col: 7),
                       "Double open-four should be forbidden")
    }

    func testDoubleFourPermitsDeadFours() {
        // Dead four: one end blocked by opponent — should NOT count toward double-four.
        // This verifies the open-four fix introduced in the forbidden-move logic.
        var rules = GomokuRules()
        rules.boardSize = 15
        rules.doubleFourEnabled = true
        rules.doubleFourTarget = .blackOnly
        var model = GomokuModel(rules: rules)

        // Horizontal dead four: B(7,4) B(7,5) B(7,6), left end blocked by W(7,3)
        model.board[7][4] = .black
        model.board[7][5] = .black
        model.board[7][6] = .black
        model.board[7][3] = .white  // blocks left → dead four

        // Vertical dead four: B(4,7) B(5,7) B(6,7), top end blocked by W(3,7)
        model.board[4][7] = .black
        model.board[5][7] = .black
        model.board[6][7] = .black
        model.board[3][7] = .white  // blocks top → dead four

        // Neither is an open four → double-four rule should NOT fire → placement succeeds
        XCTAssertTrue(model.placePiece(row: 7, col: 7),
                      "Dead fours should not trigger double-four forbidden rule")
    }

    // MARK: - Forbidden: Overline (長連)

    func testOverlineForbids6InARow() {
        var rules = GomokuRules()
        rules.boardSize = 15
        rules.overlineEnabled = true
        rules.overlineTarget = .blackOnly
        var model = GomokuModel(rules: rules)

        // Five black stones in a row — playing next to them would make 6
        model.board[5][3] = .black
        model.board[5][4] = .black
        model.board[5][5] = .black
        model.board[5][6] = .black
        model.board[5][7] = .black

        XCTAssertFalse(model.placePiece(row: 5, col: 8),
                       "Overline (6+ in a row) should be forbidden for black")
    }

    func testOverlineNotFiredForExactly5() {
        var rules = GomokuRules()
        rules.boardSize = 15
        rules.overlineEnabled = true
        rules.overlineTarget = .blackOnly
        var model = GomokuModel(rules: rules)

        // Four black stones — playing next to them makes exactly 5, not 6
        model.board[5][3] = .black
        model.board[5][4] = .black
        model.board[5][5] = .black
        model.board[5][6] = .black

        // (5,7) should produce exactly 5 in a row — win, not overline
        XCTAssertTrue(model.placePiece(row: 5, col: 7),
                      "Exactly 5 in a row is a win, not an overline")
    }

    func testOverlineNotAppliedToWhite() {
        var rules = GomokuRules()
        rules.boardSize = 15
        rules.overlineEnabled = true
        rules.overlineTarget = .blackOnly
        var model = GomokuModel(rules: rules)

        model.board[5][3] = .white
        model.board[5][4] = .white
        model.board[5][5] = .white
        model.board[5][6] = .white
        model.board[5][7] = .white
        model.currentPlayer = .white

        XCTAssertTrue(model.placePiece(row: 5, col: 8),
                      "Overline should not restrict white when target is blackOnly")
    }

    // MARK: - Reset

    func testResetClearsBoard() {
        var model = GomokuModel()
        _ = model.placePiece(row: 9, col: 9)
        model.reset()
        XCTAssertNil(model.lastMove)
        XCTAssertEqual(model.currentPlayer, .black)
        for row in model.board {
            for cell in row { XCTAssertEqual(cell, .empty) }
        }
    }

    func testResetPreservesRules() {
        var rules = GomokuRules()
        rules.boardSize = 15
        rules.overlineEnabled = true
        var model = GomokuModel(rules: rules)
        _ = model.placePiece(row: 7, col: 7)
        model.reset()
        XCTAssertEqual(model.rules.boardSize, 15)
        XCTAssertTrue(model.rules.overlineEnabled)
    }

    // MARK: - Custom Board Size

    func testCustomBoardSize15() {
        var rules = GomokuRules()
        rules.boardSize = 15
        let model = GomokuModel(rules: rules)
        XCTAssertEqual(model.board.count, 15)
        XCTAssertEqual(model.board[0].count, 15)
    }

    // MARK: - Desync Detection

    func testDesyncFiresOnWrongSeq() {
        let engine = GomokuEngine()
        engine.isMultiplayer = true
        engine.localPlayer = .white

        var desyncFired = false
        engine.onDesyncDetected = { desyncFired = true }

        // Feed seq=2 when expectedRecvSeq=1
        let move = MoveMessage(row: 7, col: 7, seq: 2)
        engine.receiveRemoteMove(data: move.toData())

        XCTAssertTrue(desyncFired, "onDesyncDetected should fire on seq mismatch")
        XCTAssertEqual(engine.model.board[7][7], .empty, "Board must not change on desync")
    }

    func testDesyncDoesNotFireOnCorrectSeq() {
        let engine = GomokuEngine()
        engine.isMultiplayer = true
        engine.localPlayer = .white

        var desyncFired = false
        engine.onDesyncDetected = { desyncFired = true }

        let move = MoveMessage(row: 9, col: 9, seq: 1)
        engine.receiveRemoteMove(data: move.toData())

        XCTAssertFalse(desyncFired, "onDesyncDetected must not fire on correct seq")
        XCTAssertNotEqual(engine.model.board[9][9], .empty)
        XCTAssertEqual(engine.expectedRecvSeq, 2)
    }

    func testDesyncFiresOnGarbageData() {
        let engine = GomokuEngine()
        engine.isMultiplayer = true
        engine.localPlayer = .white

        var desyncFired = false
        engine.onDesyncDetected = { desyncFired = true }

        engine.receiveRemoteMove(data: Data([0xDE, 0xAD]))

        XCTAssertTrue(desyncFired, "onDesyncDetected should fire when payload cannot be decoded")
    }

    func testSeqResetsOnEngineReset() {
        let engine = GomokuEngine()
        engine.nextSendSeq = 5
        engine.expectedRecvSeq = 3

        engine.reset()

        XCTAssertEqual(engine.nextSendSeq, 1)
        XCTAssertEqual(engine.expectedRecvSeq, 1)
    }
}
