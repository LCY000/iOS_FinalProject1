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
                .overlay(stroke ? Circle().stroke(.gray, lineWidth: 1) : nil)
            Text("\(score)").font(.appNumber)
            Text(label).font(.appCaption).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Confetti

private struct ConfettiLayer: View {
    private let pieces = 60
    @State private var animate = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<pieces, id: \.self) { i in
                    ConfettiPiece(
                        startX: CGFloat.random(in: 0...geo.size.width),
                        endY: geo.size.height + 50,
                        delay: Double(i) * 0.02,
                        animate: animate
                    )
                }
            }
        }
        .ignoresSafeArea()
        .onAppear { animate = true }
    }
}

private struct ConfettiPiece: View {
    let startX: CGFloat
    let endY: CGFloat
    let delay: Double
    let animate: Bool

    private let colors: [Color] = [.red, .blue, .green, .yellow, .orange, .pink, .purple]
    @State private var color: Color = .red
    @State private var rotation = 0.0

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: 8, height: 12)
            .offset(x: startX - 4, y: animate ? endY : -50)
            .rotationEffect(.degrees(rotation))
            .animation(.linear(duration: Double.random(in: 2.5...4.5)).delay(delay), value: animate)
            .animation(.linear(duration: 1.0).repeatForever(autoreverses: false), value: rotation)
            .onAppear {
                color = colors.randomElement()!
                rotation = Double.random(in: -360...360)
            }
    }
}
