# Tutorial System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `TutorialContent` type to `GameInfo` and a `TutorialView` sheet reachable from game cards in `RoomView`, covering all four games (Reversi, Gomoku, Quoridor, Checkers).

**Architecture:** `TutorialContent` is pure data attached to each `GameInfo` entry. `TutorialView` is a stateless scroll view. An ⓘ button on each game card in `RoomView` presents the sheet. No persistence, no state.

**Tech Stack:** SwiftUI, existing Spacing/Typography design tokens, SF Symbols.

---

## File Map

| File | Change |
|------|--------|
| `Final Project/Core/GameRegistry.swift` | Add `TutorialSection`, `TutorialContent`, `GameInfo.tutorial`; fill content for Reversi and Gomoku |
| `Final Project/Core/TutorialView.swift` | New — scrollable sheet |
| `Final Project/Core/RoomView.swift` | Add `@State var tutorialGame: GameInfo?` + ⓘ button + `.sheet` |

---

### Task 1: Add TutorialContent to GameRegistry

**Files:**
- Modify: `Final Project/Core/GameRegistry.swift`

- [ ] **Step 1: Replace `GameInfo` struct and add supporting types**

Replace the existing `GameInfo` struct and add the two new types above it:

```swift
struct TutorialSection {
    let heading: String
    let body: String
}

struct TutorialContent {
    let overview: String
    let sections: [TutorialSection]
}

struct GameInfo: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let gameType: String
    let createEngine: () -> any GameEngine
    let tutorial: TutorialContent
}
```

- [ ] **Step 2: Update ReversiEngine entry with tutorial content**

Replace the existing Reversi `GameInfo(...)` block:

```swift
GameInfo(
    title: ReversiEngine.gameTitle,
    icon: ReversiEngine.gameIcon,
    gameType: ReversiEngine.gameType,
    createEngine: { ReversiEngine() },
    tutorial: TutorialContent(
        overview: "在 8×8（或自選 6–12 路）棋盤上翻轉對手棋子，遊戲結束時占多數者獲勝。",
        sections: [
            TutorialSection(heading: "目標",
                body: "讓棋盤上你的顏色棋子比對手多。當雙方都無法落子時遊戲結束。"),
            TutorialSection(heading: "落子規則",
                body: "落子必須「夾住」對手至少一顆棋子——被夾住的對手棋子（在同一直線上、兩端都是你的棋子）全部翻為你的顏色。"),
            TutorialSection(heading: "跳過回合",
                body: "若本回合無合法落子位置，回合自動跳過並提示。雙方都無法落子時遊戲結束。"),
            TutorialSection(heading: "勝負判定",
                body: "棋盤填滿或雙方都無法落子時計分，棋子多者獲勝；相同則平手。"),
            TutorialSection(heading: "棋盤大小",
                body: "支援 6×6、8×8、10×10、12×12，由房主在開局前設定，設定會同步給對手。")
        ]
    )
),
```

- [ ] **Step 3: Update GomokuEngine entry with tutorial content**

Replace the existing Gomoku `GameInfo(...)` block:

```swift
GameInfo(
    title: GomokuEngine.gameTitle,
    icon: GomokuEngine.gameIcon,
    gameType: GomokuEngine.gameType,
    createEngine: { GomokuEngine() },
    tutorial: TutorialContent(
        overview: "在棋盤上搶先連成五顆同色棋子（橫、直、斜任一方向）即獲勝。",
        sections: [
            TutorialSection(heading: "目標",
                body: "率先在任意方向連成五顆棋子（不多不少恰好五顆，或超過亦可，視禁手設定而定）。"),
            TutorialSection(heading: "落子規則",
                body: "點擊棋盤交叉點落子；長按可精準選格。先出現預覽棋，確認按鈕才正式落下，防止誤觸。"),
            TutorialSection(heading: "三三禁手",
                body: "黑方一步棋同時形成兩條「活三」（兩端皆空的連三）則禁止落子。"),
            TutorialSection(heading: "四四禁手",
                body: "黑方一步棋同時形成兩條「活四」（兩端皆空的連四）則禁止落子。"),
            TutorialSection(heading: "長連禁手",
                body: "黑方形成超過五顆連子則禁止落子（六連以上）。"),
            TutorialSection(heading: "禁手設定",
                body: "三三、四四、長連可分別開關，並指定套用於黑方、白方或雙方。由房主設定後同步。"),
            TutorialSection(heading: "棋盤大小與縮放",
                body: "支援 15–25 路棋盤。可用雙指縮放或底部按鈕調整棋盤大小。")
        ]
    )
),
```

- [ ] **Step 4: Build（⌘B）確認無編譯錯誤**

預期：編譯成功。若出現「missing argument for parameter 'tutorial'」，表示 createEngine 的 lambda 舊格式沒有更新，依上面步驟補齊。

- [ ] **Step 5: Commit**

```bash
git add "Final Project/Core/GameRegistry.swift"
git commit -m "feat(tutorial): add TutorialContent to GameInfo, fill Reversi & Gomoku content"
```

---

### Task 2: Create TutorialView

**Files:**
- Create: `Final Project/Core/TutorialView.swift`

- [ ] **Step 1: 建立檔案並寫入完整內容**

```swift
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

                    ForEach(game.tutorial.sections.indices, id: \.self) { i in
                        let section = game.tutorial.sections[i]
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text(section.heading)
                                .font(.appSubtitle)
                            Text(section.body)
                                .font(.appBody)
                                .foregroundStyle(.secondary)
                        }
                        .padding(Spacing.m)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .card(radius: Radius.m, elevation: .low, padding: 0)
                        .padding(.horizontal, Spacing.m)
                    }

                    Spacer(minLength: Spacing.xl)
                }
                .padding(.top, Spacing.m)
            }
            .navigationTitle(game.title + " — 規則說明")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    TutorialView(game: GameRegistry.availableGames[0])
}
```

- [ ] **Step 2: Build（⌘B）確認無編譯錯誤**

- [ ] **Step 3: Preview 確認排版**

在 Xcode Canvas 或模擬器查看 TutorialView preview，確認段落卡片、字型、間距正常。

- [ ] **Step 4: Commit**

```bash
git add "Final Project/Core/TutorialView.swift"
git commit -m "feat(tutorial): add TutorialView scrollable sheet"
```

---

### Task 3: Add ⓘ Button to RoomView Game Cards

**Files:**
- Modify: `Final Project/Core/RoomView.swift`

- [ ] **Step 1: 在 RoomView 加入 sheet 狀態變數**

在 `RoomView` 的 `@State` 變數區段（檔案頂部 body 之前）加入：

```swift
@State private var tutorialGame: GameInfo?
```

- [ ] **Step 2: 在遊戲卡片 overlay 加入 ⓘ 按鈕**

找到 RoomView 的遊戲卡片渲染位置（`ForEach(availableGames...)`），在每張卡片的 `.overlay` closure 內加入 ⓘ 按鈕。找到類似這樣的結構：

```swift
.overlay {
    if selected {
        RoundedRectangle(cornerRadius: Radius.m)
            .stroke(Color.accentColor, lineWidth: 2)
    }
}
```

改為：

```swift
.overlay(alignment: .topTrailing) {
    Button {
        tutorialGame = game
    } label: {
        Image(systemName: "info.circle")
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding(Spacing.xs)
    }
    .buttonStyle(.plain)
}
.overlay {
    if selected {
        RoundedRectangle(cornerRadius: Radius.m)
            .stroke(Color.accentColor, lineWidth: 2)
    }
}
```

- [ ] **Step 3: 在 RoomView 的 body 結尾加入 .sheet**

在 RoomView 最外層 View 的 modifier chain 結尾（例如 `.navigationTitle(...)` 之後）加入：

```swift
.sheet(item: $tutorialGame) { game in
    TutorialView(game: game)
        .presentationDetents([.medium, .large])
}
```

- [ ] **Step 4: Build + 手動測試**

在模擬器跑 app，進入房間，點擊遊戲卡片右上角的 ⓘ 按鈕，確認 sheet 出現且內容正確。關閉 sheet 後確認選遊戲功能正常。

- [ ] **Step 5: Commit**

```bash
git add "Final Project/Core/RoomView.swift"
git commit -m "feat(tutorial): add info button on game cards, opens TutorialView sheet"
```

---

**完成標準：** 每款遊戲卡片有 ⓘ 按鈕，點後 sheet 顯示完整規則說明，關閉後遊戲選擇流程不受影響。Quoridor 和 Checkers 的 tutorial 內容將在各自遊戲實作時填入 GameRegistry。
