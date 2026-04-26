import SwiftUI

private struct CardModifier: ViewModifier {
    var radius: CGFloat
    var elev: Elevation
    var padding: CGFloat?

    func body(content: Content) -> some View {
        content
            .padding(padding ?? Spacing.l)
            .background(
                RoundedRectangle(cornerRadius: radius)
                    .fill(.ultraThinMaterial)
                    .elevation(elev)
            )
    }
}

extension View {
    func card(
        radius: CGFloat = Radius.l,
        elevation: Elevation = .mid,
        padding: CGFloat? = nil
    ) -> some View {
        modifier(CardModifier(radius: radius, elev: elevation, padding: padding))
    }
}
