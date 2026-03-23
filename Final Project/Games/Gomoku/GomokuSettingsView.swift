//
//  GomokuSettingsView.swift
//  Final Project
//
//  Game-specific settings for Gomoku: board size and 禁手 rules.
//  Shown in RoomView before game starts.
//

import SwiftUI

struct GomokuSettingsView: View {
    @Bindable var engine: GomokuEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Board size picker
            VStack(alignment: .leading, spacing: 8) {
                Text("棋盤大小")
                    .font(.subheadline.bold())

                HStack(spacing: 8) {
                    ForEach(GomokuRules.supportedBoardSizes, id: \.self) { size in
                        Button {
                            engine.rules.boardSize = size
                            engine.model = GomokuModel(rules: engine.rules)
                        } label: {
                            Text("\(size)×\(size)")
                                .font(.caption.bold())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(engine.rules.boardSize == size
                                              ? Color.blue : Color.gray.opacity(0.15))
                                )
                                .foregroundStyle(engine.rules.boardSize == size
                                                 ? .white : .primary)
                        }
                    }
                }
            }

            // Forbidden moves toggle
            Toggle(isOn: Binding(
                get: { engine.rules.forbiddenMovesEnabled },
                set: { newValue in
                    engine.rules.forbiddenMovesEnabled = newValue
                    engine.model = GomokuModel(rules: engine.rules)
                }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("禁手規則")
                        .font(.subheadline.bold())
                    Text("三三禁手、四四禁手、長連禁手（僅限黑方）")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(.blue)
        }
        .padding(.horizontal, 24)
    }
}

#Preview {
    GomokuSettingsView(engine: GomokuEngine())
}
