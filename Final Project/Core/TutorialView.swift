import SwiftUI

struct TutorialView: View {
    let game: GameInfo

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    Text(game.tutorial.overview)
                        .font(.appBody)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, Spacing.l)

                    ForEach(game.tutorial.sections) { section in
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text(section.heading)
                                .font(.appSection)
                            Text(section.body)
                                .font(.appBody)
                                .foregroundStyle(.secondary)
                        }
                        .padding(Spacing.m)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .card(radius: Radius.m, elevation: .low, padding: 0)
                        .padding(.horizontal, Spacing.m)
                    }
                }
                .padding(.top, Spacing.m)
            }
            .navigationTitle("\(game.title) — 規則說明")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    TutorialView(game: GameRegistry.availableGames[0])
}
