//
//  GameRegistry.swift
//  Final Project
//
//  Central registry of all available games.
//  To add a new game, just append a GameInfo entry here.
//

import SwiftUI

// MARK: - Game Info

struct GameInfo: Identifiable {
    let id = UUID()
    let title: String
    let icon: String          // SF Symbol name
    let gameType: String      // unique identifier
    let createEngine: () -> any GameEngine
}

// MARK: - Game Registry

struct GameRegistry {
    /// All games available on the platform.
    /// To add a new game: implement GameEngine protocol, then add one line here.
    static let availableGames: [GameInfo] = [
        GameInfo(
            title: ReversiEngine.gameTitle,
            icon: ReversiEngine.gameIcon,
            gameType: ReversiEngine.gameType,
            createEngine: { ReversiEngine() }
        ),
        GameInfo(
            title: GomokuEngine.gameTitle,
            icon: GomokuEngine.gameIcon,
            gameType: GomokuEngine.gameType,
            createEngine: { GomokuEngine() }
        )
    ]
}
