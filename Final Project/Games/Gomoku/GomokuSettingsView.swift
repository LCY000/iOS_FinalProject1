//
//  GomokuSettingsView.swift
//  Final Project
//
//  Game-specific settings for Gomoku: board size and granular 禁手 rules.
//  Each rule can be toggled independently and applied to black-only or both players.
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
                            var r = engine.rules; r.boardSize = size
                            engine.updateRules(r)
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

            // MARK: - Forbidden Move Rules (individual toggles)
            VStack(alignment: .leading, spacing: 4) {
                Text("禁手規則")
                    .font(.subheadline.bold())
                Text("可逐條開啟，並設定適用對象")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            // 三三禁手
            forbiddenRuleRow(
                title: "三三禁手",
                description: "同時形成兩個活三",
                isEnabled: Binding(
                    get: { engine.rules.doubleThreeEnabled },
                    set: { newValue in
                        var r = engine.rules; r.doubleThreeEnabled = newValue
                        engine.updateRules(r)
                    }
                ),
                target: Binding(
                    get: { engine.rules.doubleThreeTarget },
                    set: { newValue in
                        var r = engine.rules; r.doubleThreeTarget = newValue
                        engine.updateRules(r)
                    }
                )
            )

            // 四四禁手
            forbiddenRuleRow(
                title: "四四禁手",
                description: "同時形成兩個四",
                isEnabled: Binding(
                    get: { engine.rules.doubleFourEnabled },
                    set: { newValue in
                        var r = engine.rules; r.doubleFourEnabled = newValue
                        engine.updateRules(r)
                    }
                ),
                target: Binding(
                    get: { engine.rules.doubleFourTarget },
                    set: { newValue in
                        var r = engine.rules; r.doubleFourTarget = newValue
                        engine.updateRules(r)
                    }
                )
            )

            // 長連禁手
            forbiddenRuleRow(
                title: "長連禁手",
                description: "六子以上連線",
                isEnabled: Binding(
                    get: { engine.rules.overlineEnabled },
                    set: { newValue in
                        var r = engine.rules; r.overlineEnabled = newValue
                        engine.updateRules(r)
                    }
                ),
                target: Binding(
                    get: { engine.rules.overlineTarget },
                    set: { newValue in
                        var r = engine.rules; r.overlineTarget = newValue
                        engine.updateRules(r)
                    }
                )
            )
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Forbidden Rule Row

    private func forbiddenRuleRow(
        title: String,
        description: String,
        isEnabled: Binding<Bool>,
        target: Binding<ForbiddenTarget>
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: isEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.bold())
                    Text(description)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(.blue)

            if isEnabled.wrappedValue {
                Picker("適用對象", selection: target) {
                    ForEach(ForbiddenTarget.allCases, id: \.self) { t in
                        Text(t.rawValue).tag(t)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.leading, 20)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: Radius.s)
                .fill(isEnabled.wrappedValue
                      ? Color.blue.opacity(0.05) : Color.clear)
        )
    }
}

#Preview {
    GomokuSettingsView(engine: GomokuEngine())
}
