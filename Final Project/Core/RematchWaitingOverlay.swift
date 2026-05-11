import SwiftUI

struct RematchWaitingOverlay: View {
    @Bindable var session: GameSessionCoordinator

    var body: some View {
        if session.rematchVoting.waitingForResponse {
            VStack(spacing: Spacing.s) {
                ProgressView()
                    .scaleEffect(1.2)
                Text("等待對手回應…")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            .padding(Spacing.l)
            .background(
                RoundedRectangle(cornerRadius: Radius.l)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.2), radius: 12)
            )
            .transition(.scale.combined(with: .opacity))
        }
    }
}
