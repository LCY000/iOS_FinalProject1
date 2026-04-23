//
//  ViewModifiers.swift
//  Final Project
//
//  Shared view modifiers used across screens.
//

import SwiftUI

// MARK: - Animated Entrance

/// Fades + slides the attached view into place shortly after it appears so
/// the whole screen feels coherent with the NavigationStack push animation,
/// not just the nav bar. Apply once at the root container of each screen.
private struct AnimatedEntranceModifier: ViewModifier {
    var delay: Double = 0
    var offsetY: CGFloat = 14

    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : offsetY)
            .onAppear {
                withAnimation(.easeOut(duration: 0.35).delay(delay)) {
                    appeared = true
                }
            }
    }
}

extension View {
    /// Fades the view in with a small upward slide after it appears.
    /// Use once per top-level screen container for a consistent feel.
    func animatedEntrance(delay: Double = 0, offsetY: CGFloat = 14) -> some View {
        modifier(AnimatedEntranceModifier(delay: delay, offsetY: offsetY))
    }
}
