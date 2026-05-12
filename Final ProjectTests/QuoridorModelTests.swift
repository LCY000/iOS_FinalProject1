import XCTest
@testable import Final_Project

final class QuoridorModelTests: XCTestCase {

    // MARK: - Initial State

    func testInitialPositions() {
        let m = QuoridorModel()
        XCTAssertEqual(m.positions[.black], QuoridorPosition(row: 0, col: 4))
        XCTAssertEqual(m.positions[.white], QuoridorPosition(row: 8, col: 4))
    }

    func testInitialWallCounts() {
        let m = QuoridorModel()
        XCTAssertEqual(m.wallCounts[.black], 10)
        XCTAssertEqual(m.wallCounts[.white], 10)
    }

    // MARK: - Pawn Movement

    func testBasicPawnMoveSouth() {
        let m = QuoridorModel()
        let moves = m.validPawnMoves(for: .black)
        XCTAssertTrue(moves.contains(QuoridorPosition(row: 1, col: 4)))
    }

    func testPawnCannotLeaveBoard() {
        let m = QuoridorModel()
        // Black is at (0,4) — cannot move north (off board)
        let moves = m.validPawnMoves(for: .black)
        XCTAssertFalse(moves.contains(QuoridorPosition(row: -1, col: 4)))
    }

    func testWallBlocksPawnMovement() {
        var m = QuoridorModel()
        // Place a horizontal wall at (0, 4) — blocks (0,4)→(1,4) for black
        m.hWalls[0][4] = true
        let moves = m.validPawnMoves(for: .black)
        XCTAssertFalse(moves.contains(QuoridorPosition(row: 1, col: 4)))
    }

    func testPawnJumpsStraightOverOpponent() {
        var m = QuoridorModel()
        // Move black to (3, 4), white to (4, 4)
        m.positions[.black] = QuoridorPosition(row: 3, col: 4)
        m.positions[.white] = QuoridorPosition(row: 4, col: 4)
        let moves = m.validPawnMoves(for: .black)
        // Should be able to jump straight to (5, 4)
        XCTAssertTrue(moves.contains(QuoridorPosition(row: 5, col: 4)))
    }

    func testPawnJumpsLaterallyWhenStraightBlocked() {
        var m = QuoridorModel()
        m.positions[.black] = QuoridorPosition(row: 3, col: 4)
        m.positions[.white] = QuoridorPosition(row: 4, col: 4)
        // Block the straight jump with a wall
        m.hWalls[4][4] = true  // blocks (4,4)→(5,4)
        let moves = m.validPawnMoves(for: .black)
        XCTAssertFalse(moves.contains(QuoridorPosition(row: 5, col: 4)))
        // Should allow lateral jumps instead
        XCTAssertTrue(moves.contains(QuoridorPosition(row: 4, col: 5)) ||
                      moves.contains(QuoridorPosition(row: 4, col: 3)))
    }

    // MARK: - Win Condition

    func testBlackWinsOnRow8() {
        var m = QuoridorModel()
        m.positions[.black] = QuoridorPosition(row: 7, col: 4)
        m.applyPawnMove(QuoridorPosition(row: 8, col: 4))
        XCTAssertEqual(m.winner, .black)
        XCTAssertTrue(m.isGameOver)
    }

    func testWhiteWinsOnRow0() {
        var m = QuoridorModel()
        m.currentPlayer = .white
        m.positions[.white] = QuoridorPosition(row: 1, col: 4)
        m.applyPawnMove(QuoridorPosition(row: 0, col: 4))
        XCTAssertEqual(m.winner, .white)
    }

    // MARK: - Wall Placement

    func testCanPlaceHWallOnEmptyBoard() {
        let m = QuoridorModel()
        XCTAssertTrue(m.canPlaceHWall(row: 3, col: 3))
    }

    func testCannotPlaceHWallOnExistingWall() {
        var m = QuoridorModel()
        m.hWalls[3][3] = true
        XCTAssertFalse(m.canPlaceHWall(row: 3, col: 3))
    }

    func testCannotPlaceAdjacentHWallSharingColumn() {
        var m = QuoridorModel()
        m.hWalls[3][3] = true  // covers cols 3 and 4
        XCTAssertFalse(m.canPlaceHWall(row: 3, col: 4))  // would share col 4
        XCTAssertFalse(m.canPlaceHWall(row: 3, col: 2))  // would share col 3
    }

    func testCannotPlaceCrossingVWall() {
        var m = QuoridorModel()
        m.vWalls[3][3] = true
        XCTAssertFalse(m.canPlaceHWall(row: 3, col: 3))  // same intersection → cross
    }

    func testHasPathOnOpenBoard() {
        let m = QuoridorModel()
        XCTAssertTrue(m.hasPath(from: m.positions[.black]!, toRow: 8))
        XCTAssertTrue(m.hasPath(from: m.positions[.white]!, toRow: 0))
    }

    // MARK: - Reset

    func testResetRestoresInitialState() {
        var m = QuoridorModel()
        m.applyPawnMove(QuoridorPosition(row: 1, col: 4))
        m.reset()
        XCTAssertEqual(m.positions[.black], QuoridorPosition(row: 0, col: 4))
        XCTAssertEqual(m.wallCounts[.black], 10)
        XCTAssertNil(m.winner)
        XCTAssertEqual(m.currentPlayer, .black)
    }
}
