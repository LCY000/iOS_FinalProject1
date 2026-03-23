//
//  ChatOverlayView.swift
//  Final Project
//
//  Compact chat capsule button + floating toast for incoming messages.
//  Tapping opens a full chat sheet.
//

import SwiftUI

struct ChatOverlayView: View {
    @Bindable var chatManager: ChatManager
    @State private var showChatSheet = false
    @State private var toastMessage: String?
    @State private var toastTimer: Timer?

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // MARK: - Floating Toast (incoming message)
            if let msg = toastMessage {
                Button {
                    dismissToast()
                    showChatSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "bubble.left.fill")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                        Text(msg)
                            .font(.caption)
                            .lineLimit(1)
                            .foregroundStyle(.primary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
                    )
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .gesture(
                    DragGesture(minimumDistance: 10)
                        .onEnded { value in
                            if value.translation.height > 0 {
                                dismissToast()
                            }
                        }
                )
                .padding(.bottom, 4)
            }

            // MARK: - Chat Capsule Button
            Button {
                showChatSheet = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "bubble.left.fill")
                        .font(.caption)
                    Text("聊天")
                        .font(.caption.bold())
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                )
                .foregroundStyle(.blue)
            }
            .padding(.bottom, 6)
        }
        .animation(.spring(duration: 0.3), value: toastMessage != nil)
        .sheet(isPresented: $showChatSheet) {
            chatSheet
        }
        .onChange(of: chatManager.latestPeerMessage?.id) { _, _ in
            if let msg = chatManager.latestPeerMessage {
                showToast(msg.text)
            }
        }
    }

    // MARK: - Toast Logic

    private func showToast(_ text: String) {
        toastTimer?.invalidate()
        let preview = String(text.prefix(20)) + (text.count > 20 ? "…" : "")
        toastMessage = preview
        toastTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { _ in
            Task { @MainActor in
                dismissToast()
            }
        }
    }

    private func dismissToast() {
        toastTimer?.invalidate()
        toastTimer = nil
        withAnimation {
            toastMessage = nil
        }
    }

    // MARK: - Chat Sheet

    private var chatSheet: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(chatManager.messages) { msg in
                                chatBubble(msg)
                                    .id(msg.id)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                    .onChange(of: chatManager.messages.count) { _, _ in
                        if let last = chatManager.messages.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }

                Divider()

                // Quick Replies
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(ChatManager.quickReplies, id: \.self) { reply in
                            Button {
                                chatManager.sendMessage(reply)
                            } label: {
                                Text(reply)
                                    .font(.caption.bold())
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule().fill(Color.blue.opacity(0.1))
                                    )
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                }

                // Input
                chatInputBar
            }
            .navigationTitle("聊天室")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { showChatSheet = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Input Bar

    @State private var inputText = ""

    private var chatInputBar: some View {
        HStack(spacing: 8) {
            TextField("輸入訊息…", text: $inputText)
                .textFieldStyle(.roundedBorder)
                .onSubmit { sendInput() }

            Button {
                sendInput()
            } label: {
                Image(systemName: "paperplane.fill")
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(Circle().fill(inputText.isEmpty ? Color.gray : Color.blue))
            }
            .disabled(inputText.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Chat Bubble

    private func chatBubble(_ message: ChatMessage) -> some View {
        HStack {
            if message.isFromMe { Spacer() }
            Text(message.text)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(message.isFromMe ? Color.blue : Color.gray.opacity(0.2))
                )
                .foregroundStyle(message.isFromMe ? .white : .primary)
            if !message.isFromMe { Spacer() }
        }
    }

    // MARK: - Helpers

    private func sendInput() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        chatManager.sendMessage(text)
        inputText = ""
    }
}
