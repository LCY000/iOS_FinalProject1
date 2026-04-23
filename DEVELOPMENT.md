# Final Project — 開發文件 (Developer Guide)

> **用途**：讓新的開發者或 AI 快速了解專案架構、邏輯、注意事項。

---

## 專案概述

iOS 多人棋盤遊戲平台，支援：

- **黑白棋 (Reversi)** — 6×6 / 8×8 / 10×10 / 12×12
- **五子棋 (Gomoku)** — 15×15 / 19×19 / 21×21 / 23×23 / 25×25，可選禁手

核心特色：

- **離線連線對戰**（MultipeerConnectivity，藍牙/Wi-Fi 直連）
- **模組化架構** — 新增遊戲只需實作 `GameEngine` 協議 + 註冊到 `GameRegistry`
- **聊天系統** — 浮動膠囊 + Sheet
- **落子確認** — 點擊預覽 → 確認/取消
- **可縮放棋盤** — 雙指縮放 + 滾動

---

## 技術規格

| 項目     | 值                                          |
| -------- | ------------------------------------------- |
| 語言     | Swift (SwiftUI)                             |
| 最低版本 | iOS 26.2                                    |
| 連線框架 | MultipeerConnectivity                       |
| 狀態管理 | `@Observable` (iOS 17+)                     |
| 並行設定 | `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` |
| UI 語言  | 繁體中文                                    |

---

## 檔案架構

```
Final Project/
├── Final_ProjectApp.swift          # App 入口
├── ContentView.swift               # 首頁：單機/連線/測試模式 選擇
├── Info.plist                      # 網路權限 (Bonjour + Local Network)
│
├── Core/                           # 遊戲無關的共用層
│   ├── GameEngine.swift            # ⭐ 核心協議 + 共用資料模型
│   ├── GameRegistry.swift          # 遊戲註冊表
│   ├── MultipeerManager.swift      # 連線管理（收發 MessageEnvelope）
│   ├── LobbyView.swift             # 配對大廳（Host/Browse）
│   ├── RoomView.swift              # 遊戲房間（選遊戲、設定規則、開始）
│   ├── ChatManager.swift           # 聊天邏輯
│   └── ChatOverlayView.swift       # 聊天 UI（膠囊按鈕 + Sheet）
│
└── Games/
    ├── Reversi/
    │   ├── ReversiModel.swift       # 純邏輯（棋盤、翻面、勝負）
    │   ├── ReversiEngine.swift      # GameEngine 實作 + 設定 View
    │   ├── ReversiGameView.swift    # 遊戲畫面
    │   └── ReversiCellView.swift    # 單格 View
    │
    └── Gomoku/
        ├── GomokuModel.swift        # 純邏輯（N×N、五連、禁手）
        ├── GomokuEngine.swift       # GameEngine 實作
        ├── GomokuSettingsView.swift  # 設定 UI（棋盤大小 + 禁手）
        ├── GomokuGameView.swift     # 遊戲畫面（可縮放）
        └── GomokuCellView.swift     # 單格 View（交叉線式）
```

---

## 核心架構

### GameEngine 協議（所有遊戲必須實作）

```swift
protocol GameEngine: AnyObject, Observable {
    // 身分
    static var gameTitle: String { get }
    static var gameIcon: String { get }
    static var gameType: String { get }

    // 狀態
    var currentPlayer: PlayerColor { get }
    var scores: (black: Int, white: Int) { get }
    var isGameOver: Bool { get }
    var statusMessage: String { get }
    var boardSize: Int { get }

    // 多人
    var isMultiplayer: Bool { get set }
    var localPlayer: PlayerColor { get set }

    // 落子確認
    var pendingMove: (row: Int, col: Int)? { get }
    func confirmMove()
    func cancelMove()

    // 操作
    func handleTap(row: Int, col: Int) -> Bool
    func receiveRemoteMove(data: Data)
    func reset()

    // 設定
    func makeSettingsView() -> AnyView
    func exportSettings() -> Data
    func applySettings(data: Data)

    // 網路
    var onMoveToSend: ((MessageEnvelope) -> Void)? { get set }

    // View
    func makeGameView() -> AnyView
}
```

### MessageEnvelope（通用網路封包）

所有網路通訊都透過 `MessageEnvelope`，包含：

- `type`: `.startGame` / `.playerMove` / `.setRules` / `.chat` / `.gameOver`
- `gameType`: 遊戲識別碼 (e.g. `"reversi"`, `"gomoku"`)
- `payload`: 遊戲專屬的 JSON Data

### 連線流程

```
Host                          Guest
────                          ─────
hostGame()                    joinGame()
  ↓ advertise                   ↓ browse
  ← ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ →  invitePeer()
  auto-accept invitation
  ↓                             ↓
connectionState = .connected    connectionState = .connected
  ↓                             ↓
LobbyView → onChange → RoomView
  ↓
Host 選遊戲 + 設定規則
Host 按「開始」
  ↓ send(.startGame + settings)
  ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ → Guest 收到 → applySettings → 進入遊戲
```

---

## 新增遊戲步驟（以新增「圍棋」為例）

1. 建立 `Games/Go/` 資料夾
2. 寫 `GoModel.swift`（純邏輯，不依賴 UI）
3. 寫 `GoEngine.swift`（實作 `GameEngine` 協議）
4. 寫 `GoGameView.swift` + `GoCellView.swift`
5. 在 `GameRegistry.swift` 加一行：
   ```swift
   GameInfo(title: GoEngine.gameTitle, icon: GoEngine.gameIcon,
            gameType: GoEngine.gameType, createEngine: { GoEngine() })
   ```
6. 完成 — Lobby、Room、Chat 自動可用

---

## ⚠️ 開發注意事項

### 重要的踩坑紀錄

1. **MultipeerConnectivity cleanup 必須建新的 MCPeerID**
   - `cleanup()` 裡要 `myPeerID = MCPeerID(displayName: ...)` 才能重新連線
   - 否則 re-connect 會失敗（stale MCPeerID）

2. **不要用 callback 做 SwiftUI 導航**
   - 用 `.onChange(of: connectionState)` 而不是 `onPeerConnected` callback
   - Callback 會被 `cleanup()` 清掉，導致導航失敗

3. **MC delegate 方法必須標記 `nonisolated`**
   - `MCSessionDelegate` 等回調在背景執行緒
   - 用 `Task { @MainActor in ... }` 回到主執行緒更新 UI

4. **RoomView 離開時要手動 disconnect**
   - 自訂返回按鈕，呼叫 `multipeerManager.disconnect()`
   - 否則連線會殘留

5. **SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor**
   - 專案使用 Swift 6 嚴格並行模式
   - 所有函式預設在 MainActor，MC delegate 用 `nonisolated` 標記
   - 不要隨意移除此設定

6. **Info.plist 必須包含**
   ```xml
   NSLocalNetworkUsageDescription
   NSBonjourServices: ["_boardgame._tcp"]
   ```

### DEBUG_TEST_MODE

`ContentView.swift` 第 13 行的 `DEBUG_TEST_MODE` 開關：

- `true`: 首頁顯示「🛠 測試模式」按鈕，可一人操作雙方 + 聊天
- `false`: 隱藏測試按鈕（正式版）

### 確認按鈕位置

確認/取消按鈕放在底部固定高度列的**右側**，不能放在棋盤上方（會擠壓棋盤上下跳動）。

---

## v0.1.0 架構更新

### GameEngine 協議擴充（v0.1.0）

新增共用 extension helper，所有遊戲直接使用：

```swift
extension GameEngine {
    func sendMoveEnvelope(row: Int, col: Int, gameType: String)
}
```

各 engine 的 `executePlacement` 直接呼叫 `sendMoveEnvelope(...)` 取代重複的封包組裝邏輯。

### 五子棋四四禁手修正（v0.1.0）

`GomokuModel.isForbiddenMove` 現在只計算「活四」（兩端皆空）進入四四判定，封堵一端的「死四」不再誤觸禁手。

### 單元測試

測試檔案位於 `Final ProjectTests/`：
- `ReversiModelTests.swift` — 黑白棋純邏輯（初始盤面、合法步、翻面、勝負）
- `GomokuModelTests.swift` — 五子棋純邏輯（五連判定、三三/四四/長連禁手）

**啟用測試（第一次設定）**：
1. Xcode → File → New → Target → Unit Testing Bundle，命名 `Final ProjectTests`
2. 把 `Final ProjectTests/*.swift` 加到該 target（Target Membership 勾選）
3. `⌘U` 執行

---

## 目前已知問題（不知道原因

- **iPhone 實機白屏**：疑似 Xcode debugger 無法 attach 到裝置，非程式碼問題。嘗試：
  1. `Ctrl + Cmd + R`（Run Without Debugging）
  2. 刪除手機上的 app → Clean Build Folder → 重新 Build & Run
  3. 重啟 iPhone + Xcode
     目前還無法解決，手機是 iphone 15 pro，版本是ios 26.3.1(a)

## 需要立即解決的問題或是建議

還沒解決之前暫時放下的問題項目、建議，不分先後順序，可以整理看看適合解決的先後順序，會比較不容易有bug，或是一起修正

1. ~~再來一場時，要投票但不太懂為什麼通知詢問要出去棋盤才看到~~ ✅ 已修（v0.1.0）— 投票 alert 現在掛在遊戲畫面上 + RoomView 兩邊。
   ![alt text](docs/image.png)
2. ~~按下再來一場按鈕後，假如對面按拒絕，也不要卡住~~ ✅ 已修（v0.1.0）— waiting overlay 在收到回應 / 對方離開 / 連線斷時都會清掉。![alt text](docs/image-1.png)
3. ~~離開房間功能，主動離開房間的，要跳出是否離開房間、中斷連線的選擇通知~~ ✅ 已修（v0.1.0）— 加了 `.confirmationDialog`；自己主動離開時不會再跳「連線已中斷」。
4. ~~離開房間功能，對方主動離開時...會跳出兩次~~ ✅ 已修（v0.1.0）— 主動 / 被動斷線改走同一條 `handleConnectionStateChange`，不再雙路徑。
   ![alt text](docs/image-2.png)
5. ~~棋盤遊玩頁面對面離開房間也要通知~~ ✅ 已修（v0.1.0）— 新增 `.peerLeftRoom` MessageType + 遊戲畫面頂部 `PeerLeftBanner`（不阻擋操作）。
6. ~~遊戲到一半不小心手滑到前一頁~~ ✅ 右上角「繼續遊戲」按鈕已有，v0.1.0 修掉了 push/pop 抖動。![alt text](docs/image-3.png)
7. ~~聊天功能幽靈通知~~ ✅ 已修（v0.1.0）— toast 狀態集中到 `ChatManager.toastMessage`，單一真相來源。![alt text](docs/image-4.png)
8. ~~五子棋有上一步標記但黑白棋沒有~~ ✅ 已修（v0.1.0）— `ReversiModel.lastMove` + `ReversiCellView` 紅色環，翻面動畫結束後才顯示。
9. ~~進場動畫上下不一致~~ ✅ 已修（v0.1.0）— 新增 `.animatedEntrance()` view modifier，所有主畫面一致。
