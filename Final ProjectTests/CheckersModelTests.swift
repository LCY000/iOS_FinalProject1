import XCTest
@testable import Final_Project

final class CheckersModelTests: XCTestCase {

    // MARK: - Initial State

    func testAmericanBoardSize() {
        let m = CheckersModel(variant: .american)
        XCTAssertEqual(m.boardSize, 8)
    }

    func testInternationalBoardSize() {
        let m = CheckersModel(variant: .international)
        XCTAssertEqual(m.boardSize, 10)
    }

    func testAmericanInitialPieceCount() {
        let m = CheckersModel(variant: .american)
        var black = 0; var white = 0
        for r in m.board { for p in r {
            if p.owner == .black { black += 1 }
            else if p.owner == .white { white += 1 }
        }}
        XCTAssertEqual(black, 12)
        XCTAssertEqual(white, 12)
    }

    func testInitialPiecesOnDarkSquaresOnly() {
        let m = CheckersModel(variant: .american)
        for r in 0..<m.boardSize {
            for c in 0..<m.boardSize {
                if (r + c) % 2 == 0 {
                    XCTAssertEqual(m.board[r][c], .empty, "Light square (\(r),\(c)) should be empty")
                }
            }
        }
    }

    // MARK: - Simple Moves

    func testBlackHasMovesAtStart() {
        let m = CheckersModel(variant: .american)
        XCTAssertFalse(m.validMoves(for: .black).isEmpty)
    }

    func testManCannotMoveBackward() {
        var m = CheckersModel(variant: .american)
        // Clear board, place one black man at center
        m.board = Array(repeating: Array(repeating: .empty, count: 8), count: 8)
        m.board[4][3] = .man(.black)
        let moves = m.validMoves(for: .black)
        // Black man can only move to row 5 (south), not row 3
        XCTAssertTrue(moves.allSatisfy { $0.to.row > 4 })
    }

    func testKingCanMoveBothDirections() {
        var m = CheckersModel(variant: .american)
        m.board = Array(repeating: Array(repeating: .empty, count: 8), count: 8)
        m.board[4][3] = .king(.black)
        let moves = m.validMoves(for: .black)
        let hasNorthMove = moves.contains { $0.to.row < 4 }
        let hasSouthMove = moves.contains { $0.to.row > 4 }
        XCTAssertTrue(hasNorthMove)
        XCTAssertTrue(hasSouthMove)
    }

    // MARK: - Mandatory Capture

    func testMandatoryCaptureOverridesSimpleMove() {
        var m = CheckersModel(variant: .american)
        m.board = Array(repeating: Array(repeating: .empty, count: 8), count: 8)
        // Black at (2,2), white at (3,3), empty at (4,4)
        m.board[2][2] = .man(.black)
        m.board[3][3] = .man(.white)
        let moves = m.validMoves(for: .black)
        // Only capture move should appear
        XCTAssertEqual(moves.count, 1)
        XCTAssertEqual(moves[0].to, CheckersPosition(row: 4, col: 4))
        XCTAssertEqual(moves[0].captures, [CheckersPosition(row: 3, col: 3)])
    }

    // MARK: - Multi-Jump

    func testMultiJumpSequence() {
        var m = CheckersModel(variant: .american)
        m.board = Array(repeating: Array(repeating: .empty, count: 8), count: 8)
        // Black at (0,0), white at (1,1) and (3,3), empty at (2,2) and (4,4)
        m.board[0][0] = .man(.black)
        m.board[1][1] = .man(.white)
        m.board[3][3] = .man(.white)
        let moves = m.validMoves(for: .black)
        // Should find a sequence that captures both white pieces
        let doubleCapture = moves.first { $0.captures.count == 2 }
        XCTAssertNotNil(doubleCapture)
    }

    // MARK: - International Max Capture

    func testInternationalRequiresMaxCapture() {
        var m = CheckersModel(variant: .international)
        m.board = Array(repeating: Array(repeating: .empty, count: 10), count: 10)
        // Black man at (0,0). Two paths: one captures 1, another captures 2.
        m.board[0][0] = .man(.black)
        m.board[1][1] = .man(.white)
        m.board[3][3] = .man(.white)
        let moves = m.validMoves(for: .black)
        // All returned moves must capture 2 pieces (max)
        XCTAssertTrue(moves.allSatisfy { $0.captures.count == 2 })
    }

    // MARK: - King Promotion

    func testManPromotesToKingOnLastRow() {
        var m = CheckersModel(variant: .american)
        m.board = Array(repeating: Array(repeating: .empty, count: 8), count: 8)
        m.board[6][1] = .man(.black)
        _ = m.applyMove(path: [CheckersPosition(row: 6, col: 1),
                                CheckersPosition(row: 7, col: 2)],
                         captures: [])
        XCTAssertEqual(m.board[7][2], .king(.black))
    }

    // MARK: - Win Condition

    func testNoMovesLoses() {
        var m = CheckersModel(variant: .american)
        m.board = Array(repeating: Array(repeating: .empty, count: 8), count: 8)
        // Place one black man, no white pieces at all
        m.board[4][4] = .man(.black)
        m.currentPlayer = .black
        // Apply a move as black; white has no pieces → checkWinner fires
        _ = m.applyMove(path: [CheckersPosition(row: 4, col: 4),
                                CheckersPosition(row: 5, col: 5)],
                         captures: [])
        XCTAssertEqual(m.winner, .black)
    }

    // MARK: - Reset

    func testResetRestoresInitialState() {
        var m = CheckersModel(variant: .american)
        _ = m.applyMove(path: [CheckersPosition(row: 2, col: 1),
                                CheckersPosition(row: 3, col: 2)],
                         captures: [])
        m.reset()
        XCTAssertNil(m.winner)
        XCTAssertEqual(m.currentPlayer, .black)
        var count = 0
        for r in m.board { for p in r { if p.owner != nil { count += 1 } } }
        XCTAssertEqual(count, 24)
    }
}
