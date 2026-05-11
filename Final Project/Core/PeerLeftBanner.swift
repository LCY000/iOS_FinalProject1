import SwiftUI

struct PeerLeftBanner: View {
    @Bindable var session: GameSessionCoordinator

    var body: some View {
        if session.showPeerLeftBanner {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "person.slash.fill")
                    .foregroundStyle(.orange)
                Text("對方已離開房間")
                    .font(.subheadline.bold())
                Spacer(minLength: Spacing.xs)
                Button {
                    session.showPeerLeftBanner = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("關閉")
            }
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, Spacing.s)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
            )
            .padding(.horizontal, Spacing.m)
            .padding(.top, Spacing.xs)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}
