//
//  SoundManager.swift
//  Final Project
//
//  Thin wrapper around AudioServicesPlaySystemSound.
//  Uses well-known system sound IDs so no audio files need to be bundled.
//

import AudioToolbox
import Foundation

enum SoundEvent {
    case placePiece    // local move confirmed
    case opponentMove  // remote move received
    case gameOver      // game ended (win/lose/draw)
    case connect       // peer connected
    case disconnect    // peer disconnected

    fileprivate var id: SystemSoundID {
        switch self {
        case .placePiece:   return 1104
        case .opponentMove: return 1107
        case .gameOver:     return 1025
        case .connect:      return 1117
        case .disconnect:   return 1006
        }
    }
}

final class SoundManager {
    static let shared = SoundManager()
    private init() {}

    private static let defaultsKey = "soundEnabled"

    var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: Self.defaultsKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Self.defaultsKey) }
    }

    func play(_ event: SoundEvent) {
        guard isEnabled else { return }
        AudioServicesPlaySystemSound(event.id)
    }
}
