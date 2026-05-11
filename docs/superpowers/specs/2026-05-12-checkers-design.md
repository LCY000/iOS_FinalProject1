# 設計文件：西洋跳棋（Checkers）

**日期：** 2026-05-12
**狀態：** 已核准，待實作

---

## 概覽

支援兩個規則集（遊戲開始前設定選擇）：美式（8×8）與國際（10×10）。核心機制：斜向移動、強制吃子、連跳、升王。王升格後外觀加星芒裝飾，走棋與吃棋皆有動畫。

---

## 規則對照

| 規則 | 美式（American） | 國際（International） |
|------|-----------------|----------------------|
| 棋盤 | 8×8 | 10×10 |
| 普通棋移動 | 斜前一格 | 斜前一格 |
| 王移動 | 斜前後一格 | 斜前後任意距離（飛王） |
| 強制吃子 | 有路就必須吃 | 必須走吃最多顆的路線 |
| 連跳 | 能繼續跳就必須繼續 | 同上（最多路線） |
| 連跳途中升王 | 升王後停止，下回合繼續 | 升王後停止，下回合繼續 |

---

## 資料結構（CheckersModel）

```swift
enum CheckersPiece {
    case empty
    case black, white           // 普通棋
    case blackKing, whiteKing   // 王
}

enum CheckersVariant { case american, international }

struct CheckersModel {
    var board: [[CheckersPiece]]    // 8×8 或 10×10
    var currentPlayer: Player
    var winner: Player?
    var variant: CheckersVariant
}
```

---

## 合法走步計算

### 強制吃子

每回合開始時先掃描全盤，若當前玩家有任何可吃子的走法，普通移動步全部不合法，只顯示吃子步。

**國際版額外規則：** 枚舉所有吃子路線（DFS 遞迴），只保留吃子數最多的路線；若有多條同樣數量，玩家可選。

### 連跳

吃子後若同一棋子仍有繼續吃的路線，必須繼續跳。連跳途中棋子不先從棋盤移除（待整條路線走完後統一移除），但視覺上被吃棋子立即標記為「待移除」（半透明）。

### 升王

棋子抵達對岸最後一行即升王，連跳中途到達不升王，需等到該回合結束。

---

## 引擎層（CheckersEngine）

實作 `GameEngine` 協議。

`MoveMessage` payload：
```swift
struct CheckersMovePayload: Codable {
    let path: [CheckersPosition]   // 完整路線（含連跳中間點）
    let captures: [CheckersPosition]  // 被吃格座標
    let promoted: Bool
}
```

連跳作為單一 move 傳送，對手收到後依序執行動畫，最終狀態一致。

---

## 視角系統（多人模式）

同 Quoridor，本地玩家永遠在畫面下方。

正規座標以 host（black）為準，row=0 在頂部。Guest（white）視角鏡射：`row → (size-1) - row`。Canvas 渲染與點擊輸入皆套用此變換。

---

## UI 層

### 棋盤配色

交錯雙色，色差小、質感接近木紋棋盤：
- 淺色格：`Color.checkersLight`（暖米色，例如 `#C8A97E`）
- 深色格：`Color.checkersDark`（暖棕色，例如 `#9B7553`）

棋子放在深色格，淺色格純作裝飾。

### 棋子外觀

- **普通棋：** 實心圓，黑色（`Color.pieceBlack`）或白色（`Color.pieceWhite`）
- **王：** 同上，外加一圈星芒

**星芒渲染（Canvas Path）：**
```
8 或 12 個三角形點，均勻分布於圓外，
每個點 = 從圓心延伸方向，外頂點半徑 = 棋子半徑 × 1.45，
內凹點半徑 = 棋子半徑 × 1.15
顏色：金色（`Color.kingCrown`，約 `#FFD700`）或棋子本身對比色（黑棋白星芒、白棋黑星芒）
```

升王動畫：星芒 scale 從 0 → 1，`.spring(duration: 0.4, bounce: 0.3)`。

### 動畫

| 動作 | 動畫 |
|------|------|
| 走棋（普通移動） | 棋子從起點滑到終點，`.easeInOut(duration: 0.25)` |
| 吃棋 | 被吃棋子縮小 + 淡出（0.2s），攻擊方棋子滑過（0.25s） |
| 連跳 | 依路線各段依序播放，前一段完成後接下一段 |
| 升王 | 星芒 spring 彈入 |

動畫實作：`@State var animationQueue: [CheckersAnimationStep]`，逐步 `async` 播放，完成後更新 `displayedBoard`。Canvas 讀 `displayedBoard` 渲染，Model 在動畫完成後才更新為最終狀態。

---

## 遊戲說明（TutorialContent）

段落：目標、棋子移動、吃子規則、強制吃子、連跳、升王、王的移動、美式 vs 國際差異、勝負判定（吃光或對手無法移動）。

---

## 檔案清單

| 檔案 | 說明 |
|------|------|
| `Games/Checkers/CheckersModel.swift` | 純邏輯，無 UI |
| `Games/Checkers/CheckersEngine.swift` | GameEngine 協議實作 |
| `Games/Checkers/CheckersGameView.swift` | 主畫面，含視角切換與動畫佇列 |
| `Games/Checkers/CheckersBoardCanvas.swift` | Canvas 渲染（棋盤、棋子、星芒王、高亮） |
| `Assets.xcassets/Colors/` | 新增 `checkersLight`、`checkersDark`、`kingCrown` |
| `Core/GameRegistry.swift` | 新增 Checkers GameInfo 一行 |
