//
//  ChatOverlayView.swift
//  Final Project
//
//  Compact chat capsule button + floating toast for incoming messages.
//  Tapping opens a full chat sheet.
//
//  Toast state lives on ChatManager (not on this view's @State), so multiple
//  overlays sharing the same manager never desync and never produce ghost
//  toasts when the user navigates back and forth.
//

import SwiftUI

struct ChatOverlayView: View {
    @Bindable var chatManager: ChatManager
    @State private var showChatSheet = false
    @State private var inputText = ""

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // MARK: - Floating Toast (incoming message)
            if let msg = chatManager.toastMessage {
                Button {
                    chatManager.dismissToast()
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
                                chatManager.dismissToast()
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
                .overlay(alignment: .topTrailing) {
                    if chatManager.unreadCount > 0 {
                        Text("\(min(chatManager.unreadCount, 99))")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(.red))
                            .offset(x: 6, y: -6)
                    }
                }
            }
            .padding(.bottom, 6)
        }
        .animation(.spring(duration: 0.3), value: chatManager.toastMessage != nil)
        .animation(.spring(duration: 0.2), value: chatManager.unreadCount)
        .hapticFeedback(.selection, trigger: chatManager.toastMessage)
        .sheet(isPresented: $showChatSheet) {
            chatSheet
        }
        .onChange(of: showChatSheet) { _, isShowing in
            if isShowing { chatManager.markAsRead() }
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
                            if chatManager.messages.isEmpty {
                                VStack(spacing: Spacing.s) {
                                    Image(systemName: "bubble.left.and.bubble.right")
                                        .font(.system(size: 36))
                                        .foregroundStyle(.secondary.opacity(0.5))
                                    Text("還沒有訊息")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.top, 60)
                            } else {
                                ForEach(chatManager.messages) { msg in
                                    chatBubble(msg)
                                        .id(msg.id)
                                }
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
                ScrollView(.horizontal) {
                    HStack(spacing: Spacing.xs) {
                        ForEach(ChatManager.quickReplies, id: \.self) { reply in
                            Button(reply) {
                                chatManager.sendMessage(reply)
                            }
                            .buttonStyle(PillButtonStyle(tint: .blue))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                }
                .scrollIndicators(.hidden)

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

    private var chatInputBar: some View {
        HStack(spacing: 8) {
            TextField("輸入訊息…", text: $inputText)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.gray.opacity(0.12))
                )
                .onSubmit { sendInput() }

            Button {
                sendInput()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(inputText.isEmpty ? Color.gray.opacity(0.4) : Color.blue)
            }
            .disabled(inputText.isEmpty)
            .animation(.spring(duration: 0.2), value: inputText.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(uiColor: .systemBackground))
    }

    // MARK: - Chat Bubble

    private func chatBubble(_ message: ChatMessage) -> some View {
        HStack(alignment: .bottom, spacing: Spacing.xs) {
            if message.isFromMe { Spacer(minLength: 40) }
            VStack(alignment: message.isFromMe ? .trailing : .leading, spacing: 2) {
                Text(message.text)
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(message.isFromMe ? Color.chatBubbleMine : Color.gray.opacity(0.15))
                    )
                    .foregroundStyle(message.isFromMe ? .white : .primary)
                Text(message.timestamp, style: .time)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            if !message.isFromMe { Spacer(minLength: 40) }
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
