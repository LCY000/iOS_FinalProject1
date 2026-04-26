import SwiftUI

struct PrimaryActionButtonStyle: ButtonStyle {
    var tint: Color = .blue
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.appButton)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.m)
            .background(RoundedRectangle(cornerRadius: Radius.m).fill(tint))
            .foregroundStyle(.white)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}

struct SecondaryActionButtonStyle: ButtonStyle {
    var tint: Color = .blue
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.appButton)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.m)
            .background(RoundedRectangle(cornerRadius: Radius.m).stroke(tint, lineWidth: 2))
            .foregroundStyle(tint)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}

struct PillButtonStyle: ButtonStyle {
    var tint: Color = .green
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.bold())
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, Spacing.xs)
            .background(Capsule().fill(tint))
            .foregroundStyle(.white)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(duration: 0.18), value: configuration.isPressed)
    }
}
