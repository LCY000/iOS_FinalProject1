//
//  PlayerNameProvider.swift
//  Final Project
//
//  Centralizes the broadcast name used by both MPC and Bluetooth transports.
//  Uses a user-set nickname (UserDefaults), never leaking UIDevice.current.name.
//

import Foundation

enum PlayerNameProvider {
    private static let defaultsKey = "playerNickname"

    static var savedNickname: String? {
        get {
            let raw = UserDefaults.standard.string(forKey: defaultsKey)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return (raw?.isEmpty == false) ? raw : nil
        }
        set {
            let trimmed = newValue?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let trimmed, !trimmed.isEmpty {
                UserDefaults.standard.set(trimmed, forKey: defaultsKey)
            } else {
                UserDefaults.standard.removeObject(forKey: defaultsKey)
            }
        }
    }

    /// True if user has not yet set a nickname; LobbyView uses this to prompt.
    static var needsOnboarding: Bool { savedNickname == nil }

    /// The name to broadcast. Falls back to an anonymous identifier if no nickname is set.
    static var broadcastName: String {
        savedNickname ?? "玩家\(anonymousSuffix)"
    }

    private static var anonymousSuffix: String {
        let key = "playerAnonymousSuffix"
        if let existing = UserDefaults.standard.string(forKey: key) { return existing }
        let generated = String(UUID().uuidString.prefix(4))
        UserDefaults.standard.set(generated, forKey: key)
        return generated
    }
}
