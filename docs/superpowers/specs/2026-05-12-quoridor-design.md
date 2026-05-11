# 設計文件：Quoridor（步步為營）

**日期：** 2026-05-12
**狀態：** 已核准，待實作

---

## 概覽

標準 Quoridor 規則：9×9 棋盤，兩人對戰。每回合選擇移動棋子或放置牆壁（各 10 道）。最先走到對岸者勝。放牆不能完全封死任一方的路線（BFS 驗證）。

---

## 資料結構（QuoridorModel）

```swift
struct QuoridorPosition: Equatable {
    let row: Int  // 0–8，0 = 北
    let col: Int  // 0–8
}

enum QuoridorMoveType {
    case pawn(QuoridorPosition)
    case wall(WallType, row: Int, col: Int)
}

enum WallType { case horizontal, vertical }

struct QuoridorModel {
    var positions: [Player: QuoridorPosition]  // 初始：black row=0, white row=8
    var wallCounts: [Player: Int]              // 各 10
    var hWalls: [[Bool]]  // [8][8]，hWalls[r][c] 封住 r↔r+1，c 與 c+1 欄
    var vWalls: [[Bool]]  // [8][8]，vWalls[r][c] 封住 c↔c+1，r 與 r+1 行
    var currentPlayer: Player
    var winner: Player?
}
```

---

## 合法性驗證

### 棋子移動

1. 上下左右相鄰格，且該方向無牆壁阻擋
2. 若相鄰格有對手棋子：
   - 繼續往同方向跳（若無牆且在界內） → 直跳
   - 若直跳被牆或邊界阻擋 → 允許斜向兩格（完整 Quoridor 規則）

### 牆壁放置

1. 不超出界（hWalls/vWalls index 0–7）
2. 不與已有牆重疊（含十字交叉點衝突）
3. 放置後對雙方各跑一次 BFS，確認仍有路線到達對岸
   - BFS 最大節點數 = 81，效能無虞

---

## 引擎層（QuoridorEngine）

實作 `GameEngine` 協議。

`MoveMessage` payload 擴充：
```swift
struct QuoridorMovePayload: Codable {
    let type: String   // "pawn" | "wallH" | "wallV"
    let row: Int
    let col: Int
}
```

走法透過現有 `GameSessionCoordinator` → `MessageEnvelope` 路由，網路層不需要修改。

---

## 視角系統（多人模式）

`QuoridorModel` 以正規座標儲存（以 host 為 black，row=0 在北）。

`QuoridorGameView` 在渲染與輸入時，若本地玩家是 white（guest），套用座標變換：
```swift
func flip(_ pos: QuoridorPosition) -> QuoridorPosition {
    QuoridorPosition(row: 8 - pos.row, col: 8 - pos.col)
}
```
牆壁座標同樣鏡射。點擊輸入先反向 flip 再送給引擎。本地玩家永遠在畫面下方出發。

---

## UI 層

### 棋盤渲染（Canvas）

- 9×9 格，每格 cellSize（可縮放）
- 格線交叉點之間的間隙顯示牆壁槽位（薄長條）
- 已放置牆壁：深色實心長條（2 格寬）
- 有效走法高亮：目標格淡色圓點

### 操作模式（底部切換列）

```
[移動模式] [放牆模式]   |   [取消] [確認]
```

**移動模式：**
點棋子 → 合法格高亮 → 點目標 → 確認

**放牆模式：**
在槽位滑動 → 黃色預覽牆出現 → 確認放置

### 動畫

| 動作 | 動畫 |
|------|------|
| 棋子移動 | 從起點滑動到終點，`.easeInOut(duration: 0.25)` |
| 放牆 | 牆從透明 snap 進來，`opacity + scale`, 0.15s |

動畫實作：`@State var animatingPawn: (from: QuoridorPosition, to: QuoridorPosition)?`，Canvas draw closure 內插值計算當前繪製位置，`withAnimation` 驅動。

---

## 遊戲說明（TutorialContent）

段落：目標、棋子移動規則、跳棋規則、牆壁放置、路線封死限制、勝負判定、剩餘牆數顯示說明。

---

## 檔案清單

| 檔案 | 說明 |
|------|------|
| `Games/Quoridor/QuoridorModel.swift` | 純邏輯，無 UI |
| `Games/Quoridor/QuoridorEngine.swift` | GameEngine 協議實作 |
| `Games/Quoridor/QuoridorGameView.swift` | 主畫面，含視角切換 |
| `Games/Quoridor/QuoridorBoardCanvas.swift` | Canvas 渲染，棋子 + 牆壁 + 高亮 |
| `Core/GameRegistry.swift` | 新增 Quoridor GameInfo 一行 |
