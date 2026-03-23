//
//  ChatManager.swift
//  Final Project
//
//  Manages chat messages between connected peers.
//  Game-agnostic — works with any game via MessageEnvelope.
//

import SwiftUI

@Observable
class ChatManager {
    // MARK: State
    var messages: [ChatMessage] = []
    var latestPeerMessage: ChatMessage?

    // MARK: Quick Replies
    static let quickReplies = ["👍", "好棋！", "哈哈", "等一下", "GG", "再來一局"]

    // MARK: Callbacks
    var onSendEnvelope: ((MessageEnvelope) -> Void)?

    // MARK: Send

    func sendMessage(_ text: String) {
        let message = ChatMessage(text: text, isFromMe: true)
        messages.append(message)

        let envelope = MessageEnvelope(
            type: .chat,
            gameType: nil,
            payload: message.toData()
        )
        onSendEnvelope?(envelope)
    }

    // MARK: Receive

    func receiveEnvelope(_ envelope: MessageEnvelope) {
        guard envelope.type == .chat else { return }
        guard let message = ChatMessage.fromData(envelope.payload) else { return }
        // Override isFromMe since the sender thinks it's "from me"
        let receivedMessage = ChatMessage(text: message.text, isFromMe: false)
        messages.append(receivedMessage)
        latestPeerMessage = receivedMessage
    }

    // MARK: Reset

    func reset() {
        messages = []
        latestPeerMessage = nil
    }
}

