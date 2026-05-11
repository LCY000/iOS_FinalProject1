//
//  GameResultOverlay.swift
//  Final Project
//
//  Full-screen result card shown when isGameOver becomes true.
//  Animates in with scale + opacity; confetti particles fall behind the card.
//

import SwiftUI

struct GameResultOverlay: View {
    let isWinner: Bool
    let isDraw: Bool
    let winnerLabel: String
    let blackScore: Int
    let whiteScore: Int
    let onRematch: () -> Void
    let onLeave: () -> Void

    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()

            ConfettiLayer().opacity(isDraw ? 0 : (isWinner ? 1 : 0))

            VStack(spacing: Spacing.l) {
                Image(systemName: isDraw ? "equal.circle.fill"
                                        : (isWinner ? "trophy.fill" : "flag.fill"))
                    .font(.system(size: 72))
                    .foregroundStyle(
                        LinearGradient(
                            colors: isDraw ? [.gray, .secondary]
                                          : (isWinner ? [.yellow, .orange] : [.blue, .purple]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .symbolEffect(.bounce, value: appeared)

                Text(isDraw ? "平手！" : "\(winnerLabel) 獲勝！")
                    .font(.appHero)

                HStack(spacing: Spacing.l) {
                    scoreCell(label: "黑", color: .pieceBlack, score: blackScore)
                    Text("vs").font(.appCaption).foregroundStyle(.secondary)
                    scoreCell(label: "白", color: .pieceWhite, score: whiteScore, stroke: true)
                }

                VStack(spacing: Spacing.s) {
                    Button("再來一局", action: onRematch)
                        .buttonStyle(PrimaryActionButtonStyle(tint: .green))
                    Button("離開", action: onLeave)
                        .buttonStyle(SecondaryActionButtonStyle(tint: .blue))
                }
                .padding(.horizontal, Spacing.l)
            }
            .padding(Spacing.xl)
            .card(radius: Radius.l, elevation: .high, padding: Spacing.xl)
            .padding(.horizontal, Spacing.xl)
            .scaleEffect(appeared ? 1 : 0.8)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
                appeared = true
            }
        }
    }

    private func scoreCell(label: String, color: Color, score: Int, stroke: Bool = false) -> some View {
        VStack(spacing: Spacing.xs) {
            Circle()
                .fill(color)
                .frame(width: 36, height: 36)
                .overlay {
                    if stroke { Circle().stroke(.gray, lineWidth: 1) }
                }
            Text("\(score)").font(.appNumber)
            Text(label).font(.appCaption).foregroundStyle(.secondary)
        }
    }
}

