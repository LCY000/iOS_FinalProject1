# 設計文件：遊戲說明系統

**日期：** 2026-05-12
**狀態：** 已核准，待實作

---

## 概覽

為每款遊戲提供靜態說明頁，讓玩家隨時查閱規則。說明內容與遊戲資料綁定，新增遊戲時一併填寫，不需要額外設定。

---

## 資料結構

在 `Core/GameRegistry.swift` 新增兩個型別：

```swift
struct TutorialSection {
    let heading: String
    let body: String
}

struct TutorialContent {
    let overview: String             // 一句話遊戲簡介
    let sections: [TutorialSection]  // 各規則段落（目標、移動、特殊規則、勝負）
}
```

`GameInfo` 新增欄位：

```swift
struct GameInfo {
    let title: String
    let icon: String
    let gameType: GameType
    let createEngine: () -> any GameEngine
    let tutorial: TutorialContent   // 新增
}
```

---

## UI 進入點

`RoomView` 的遊戲卡片右上角新增 `ⓘ` 按鈕（`info.circle` SF Symbol），點擊後以 `.sheet` 彈出 `TutorialView`。不影響選遊戲的主要流程，按鈕層級低於選擇卡片本身。

---

## TutorialView

`ScrollView` + `VStack`，結構如下：

```
遊戲名稱（.appTitle）
概覽文字（.appBody，foregroundStyle .secondary）
---
[段落標題]（.appSubtitle）
[段落內文]（.appBody）
...重複...
```

全部使用現有 `Spacing`、`Typography` token，`.card` modifier 包每個段落，風格與 app 一致。

---

## 現有遊戲內容

需補寫 `TutorialContent`：
- **黑白棋（Reversi）**：目標占多數棋子、夾子翻面規則、跳過回合、勝負判定
- **五子棋（Gomoku）**：目標五連、移動規則、禁手說明（三三／四四／長連）

未來新增 Quoridor 和 Checkers 時，各自的 `GameInfo` 也帶入對應 `TutorialContent`。

---

## 範圍限制

- 純文字，不包含互動教學或動態示範
- 不儲存「是否已讀」狀態，不做初次進入提示
- 圖示僅用 SF Symbol，無自訂圖片

---

## 檔案異動

| 檔案 | 異動類型 |
|------|--------|
| `Core/GameRegistry.swift` | 新增 `TutorialSection`、`TutorialContent`、`GameInfo.tutorial` |
| `Core/TutorialView.swift` | 新增 |
| `Core/RoomView.swift` | 遊戲卡片加 ⓘ 按鈕 |
