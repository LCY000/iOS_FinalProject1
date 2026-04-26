//
//  ChatManager.swift
//  Final Project
//
//  Manages chat messages between connected peers.
//  Game-agnostic — works with any game via MessageEnvelope.
//
//  Toast visibility is centralized here (rather than per-overlay @State) so that
//  multiple ChatOverlayView instances in the view hierarchy share one source of
//  truth and cannot produce "ghost" toasts when switching between screens.
//

import SwiftUI

@Observable
final class ChatManager {
    // MARK: State
    var messages: [ChatMessage] = []

    /// Non-nil while a toast should be shown. Cleared automatically after the
    /// auto-dismiss delay, or immediately when the user taps / dismisses it.
    var toastMessage: String?

    // MARK: Quick Replies
    static let quickReplies = ["👍", "好棋！", "哈哈", "等一下", "GG", "再來一局"]

    // MARK: Callbacks
    var onSendEnvelope: ((MessageEnvelope) -> Void)?

    // MARK: Private
    private var toastDismissTask: Task<Void, Never>?
    private static let toastDuration: Duration = .seconds(4)
    private static let toastPreviewLength = 20

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
        scheduleToast(for: receivedMessage.text)
    }

    // MARK: Toast

    /// Manually dismiss the current toast (e.g. user tapped / swiped it).
    func dismissToast() {
        toastDismissTask?.cancel()
        toastDismissTask = nil
        toastMessage = nil
    }

    private func scheduleToast(for text: String) {
        toastDismissTask?.cancel()
        let preview = String(text.prefix(ChatManager.toastPreviewLength))
            + (text.count > ChatManager.toastPreviewLength ? "…" : "")
        toastMessage = preview
        toastDismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: ChatManager.toastDuration)
            guard !Task.isCancelled else { return }
            self?.toastMessage = nil
        }
    }

    // MARK: Reset

    func reset() {
        toastDismissTask?.cancel()
        toastDismissTask = nil
        messages = []
        toastMessage = nil
    }
}
