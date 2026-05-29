# Final Project — 離線多人棋盤對戰平台

👉 **版本**：0.5.0  
👉 **系統需求**：iOS 26.2+  
👉 **開發框架**：Swift 6 / SwiftUI  

這是一個以**高擴充性**為目標的 iOS 原生雙人對戰平台。玩家可在無網際網路的狀況下，透過 Wi-Fi 直連或藍牙（Bluetooth LE）尋找附近玩家，建立房間並進行多款棋盤遊戲。

---

## 🌟 核心特色

- **雙模式離線對戰**：支援 `MultipeerConnectivity`（Wi-Fi Direct）及 `CoreBluetooth`（BLE）兩種傳輸，連飛航模式也能對戰。
- **模組化遊戲架構**：獨創 `GameEngine` 協議，加入新遊戲只需實作一個協議 + 一行 `GameRegistry` 登記，大廳、房間、聊天、音效、投票系統全部自動接入。
- **可靠的 BLE 傳輸**：4-byte 大端長度前置 + 逐包重組緩衝 + 2 秒超時自動重置，確保大訊息跨 MTU 分包也不遺失。
- **持久化暱稱系統**：大廳畫面常駐暱稱欄，首次進入自動展開輸入框，之後可隨時修改，廣播名稱以此為準，不洩漏裝置真實名稱。
- **房主規則同步**：由房主統籌選擇遊戲與詳細規則（棋盤大小、禁手等），設定自動序列化並同步給對手。
- **再來一場投票**：遊戲結束後雙方可發起投票重賽，對方接受則直接重開，拒絕則回房間。
- **房間遊戲預覽**：等待房主的一方可瀏覽全部遊戲介紹與規則教學，不再是空白等待畫面。
- **全局聊天系統**：房間及遊戲中皆可使用浮動聊天，收到訊息彈出獨特樣式快顯（藍點 + 磨砂白底），不與聊天按鈕混淆。
- **防誤觸落子系統**：所有遊戲皆採「點擊預覽 → 確認」兩步操作，固定底列確保版面穩定。
- **音效系統**：以 AudioToolbox 系統音效區分普通移動、吃子/翻轉、升王、勝負、連線/斷線等事件。
- **開發者測試模式**：`ContentView.swift` 設 `DEBUG_TEST_MODE = true` 可在單機模擬雙方連線與聊天。

---

## 🎮 支援遊戲

### 黑白棋 Reversi
- 自動標示可落子位置（`plus.circle`），落子後自動翻轉棋子，紅環標示上一步位置。
- 無步可走時自動跳過並提示（區分本地 / 對手視角文案）。
- 支援棋盤大小：6×6、8×8、10×10、12×12，由房主設定並同步。

### 五子棋 Gomoku
- 單一 `Canvas` 渲染整張棋盤（最高 25×25），效能大幅優於 ZStack 逐格版本。
- 星位交叉線棋盤，支援雙指縮放與拖拉平移。
- 可獨立開關的禁手：**三三**、**四四**（僅計活四）、**長連**，可分別指定適用對象（黑方 / 白方 / 雙方）。

### 步步為營 Quoridor
- 9×9 棋盤，每回合可移動棋子或放置牆壁（最多 10 道）。
- 系統自動驗證「每方至少有一條通道」，非法牆壁無法放置。
- 連線對戰時雙方各自在畫面下方出發，視角與桌遊一致。
- 飛王跳棋規則：相鄰格有對手時可跳越，後方被擋時可改走側面。

### 西洋跳棋 Checkers
- 支援**美式（8×8）**與**國際（10×10，飛王）**兩種規則。
- **強制吃子提示**：有必吃步時，可吃的棋子顯示橘色圓環；若只有一顆可吃，自動選取並展示目的地，避免誤觸無效棋子。
- **多段連跳**動畫：每一跳依序彈簧動畫移動，被吃棋子縮小消失。
- **升王動畫**：抵達底線後金色冠環彈跳閃爍，並播放升王音效。
- 吃子移動與普通移動使用不同音效作區分。

---

## 🎨 設計系統

所有 UI 尺寸、顏色、陰影、字體均來自 `Core/DesignSystem/`：

| 檔案 | 內容 |
|------|------|
| `Spacing.swift` | `xxs`=4 … `xl`=32 |
| `Radius.swift` | `s`=8, `m`=12, `l`=16 |
| `Elevation.swift` | `low` / `mid` / `high` 陰影 |
| `Typography.swift` | `appHero` / `appTitle` / `appButton` 等字體 |
| `ButtonStyles.swift` | `PrimaryAction` / `SecondaryAction` / `Pill` |
| `CardModifier.swift` | `.card(radius:elevation:padding:)` |
| `Haptics.swift` | `.hapticFeedback(_:trigger:)` |

顏色資源（支援 Light / Dark）定義於 `Assets.xcassets/Colors/`，Xcode 16+ 自動生成 `Color.xxx` 擴充。

---

## ⚙️ 架構概覽

```
Final Project/
├── ContentView.swift              # 根視圖（含 DEBUG_TEST_MODE）
├── Core/
│   ├── DesignSystem/              # 設計 token（Spacing/Radius/Elevation/Typography/ButtonStyles/CardModifier/Haptics）
│   ├── GameEngine.swift           # GameEngine 協議 + MessageEnvelope
│   ├── GameRegistry.swift         # 遊戲目錄（GameInfo + TutorialContent）
│   ├── GameTransport.swift        # 傳輸協議
│   ├── BluetoothTransport.swift   # CoreBluetooth BLE 傳輸
│   ├── MultipeerManager.swift     # 傳輸切換 + 狀態管理
│   ├── GameSessionCoordinator.swift   # 多人局 envelope 統一路由
│   ├── RematchVoting.swift        # 再賽投票狀態機
│   ├── PlayerNameProvider.swift   # 暱稱持久化（UserDefaults）
│   ├── SoundManager.swift         # AudioToolbox 音效（placePiece/capture/promote/gameOver…）
│   ├── Logger.swift               # OSLog（bluetooth/mpc/session/game）
│   ├── ChatManager.swift          # 聊天狀態 + 快顯 toast 管理
│   ├── ChatOverlayView.swift      # 浮動聊天按鈕 + toast + 聊天 sheet
│   ├── TutorialView.swift         # 遊戲規則教學 sheet
│   ├── GameResultOverlay.swift    # 全屏結果覆層
│   ├── ConfettiLayer.swift        # 彩帶動畫
│   ├── PeerLeftBanner.swift       # 對手離線橫幅
│   ├── RematchWaitingOverlay.swift    # 等待再賽回應覆層
│   ├── ViewModifiers.swift        # `animatedEntrance(delay:offsetY:)` 等共用 modifier
│   ├── LobbyView.swift            # 大廳（暱稱設定 + Host / Browse）
│   └── RoomView.swift             # 房間（遊戲選擇、設定、先後手、Guest 遊戲預覽）
└── Games/
    ├── Reversi/
    │   ├── ReversiModel.swift
    │   ├── ReversiEngine.swift
    │   ├── ReversiGameView.swift
    │   └── ReversiCellView.swift
    ├── Gomoku/
    │   ├── GomokuModel.swift
    │   ├── GomokuEngine.swift
    │   ├── GomokuGameView.swift
    │   ├── GomokuBoardCanvas.swift
    │   ├── GomokuCellView.swift
    │   └── GomokuSettingsView.swift
    ├── Quoridor/
    │   ├── QuoridorModel.swift
    │   ├── QuoridorEngine.swift
    │   ├── QuoridorGameView.swift
    │   └── QuoridorBoardCanvas.swift
    └── Checkers/
        ├── CheckersModel.swift
        ├── CheckersEngine.swift
        ├── CheckersGameView.swift
        └── CheckersBoardCanvas.swift
```

---

## 🧪 測試

測試目標：`Final ProjectTests`

| 測試檔案 | 涵蓋範圍 |
|---------|---------|
| `ReversiModelTests` | 初始盤面、合法步、翻面、勝負、MessageEnvelope 序列化 |
| `GomokuModelTests` | 五連判定（四方向）、三三／四四／長連禁手 |
| `QuoridorModelTests` | 棋子移動、牆壁放置、通道驗證 |
| `CheckersModelTests` | 普通移動、吃子、連跳、升王、國際規則 |
| `BluetoothTransportTests` | frame 分包、round-trip 重組、邊界（空／超限 frame）、多訊息順序 |
| `GameSessionCoordinatorTests` | envelope version 編解碼、未來版本阻擋、當前版本放行 |
| `BluetoothStressTests` | 高吞吐量壓力（設定 `BT_STRESS_ENABLED=1` 環境變數後啟用） |

執行：`⌘U`

---

## 🛠 開發說明

- **Build/Run**：Xcode 16+ 開啟 `Final Project.xcodeproj`，`⌘R` 執行；`Ctrl+Cmd+R` 不附 debugger（修正 iPhone 白畫面問題）
- **測試**：`⌘U`；壓力測試需設 Scheme 環境變數 `BT_STRESS_ENABLED=1`
- **測試模式**：`ContentView.swift` 第 13 行設 `DEBUG_TEST_MODE = true` 啟用單機雙人模擬
- **加入新遊戲**：在 `Games/<Name>/` 建立 Model / Engine / View，然後在 `GameRegistry.swift` 加一行 `GameInfo(...)` 即完成

---

## 📋 版本紀錄

### v0.5.0 — 跳棋完善、介面優化

**西洋跳棋 UX**
- 強制吃子視覺提示：可吃棋子顯示橘色圓環；只有一種吃法時自動選取，直接展示目的地
- 音效語意分離：普通移動（`.placePiece`）vs 吃子（`.capture`）vs 升王（`.promote`，由 Canvas 動畫結束後播放，消除重複）

**大廳**
- 暱稱輸入改為大廳畫面常駐 inline 欄位，首次進入自動展開輸入框，不再依賴易遺失的彈窗

**房間**
- 遊戲設定改用 ScrollView，開始按鈕固定於底部，設定再多也不會被擠出螢幕
- ChatOverlayView 限制在 ScrollView 範圍，聊天按鈕不再蓋住開始按鈕
- Guest 等待畫面改為可瀏覽的遊戲介紹卡片，每張卡片附規則 / 教學按鈕

**聊天 Toast**
- Toast 重新設計：藍色小圓點 + regularMaterial 磨砂背景，與聊天按鈕（bubble icon + ultraThinMaterial）明顯區分

**安全性**
- `CheckersMoveInfo.from` / `.to` 強制解包改為 nil-coalescing 安全預設值
- `.claude/` 及 `docs/superpowers/` 加入 `.gitignore`

---

### v0.4.0 — 全面體檢
- **安全性**：替換全部 `try!`；所有 `print()` 改為 `Logger.session.debug()`；消除 view body 內的 `Binding(get:set:)`
- **棄用 API**：`overlay(_:)` → `overlay { }`；`.fill().stroke()` 鏈式；`ForEach(enumerated())`
- **設計一致性**：全面套用 Spacing / Radius token；PrimaryActionButtonStyle / PillButtonStyle
- **彩帶修復**：GeometryReader 初始尺寸為 0、body 內計算隨機值、`rotationEffect` 順序問題
- **拆檔**：`ConfettiLayer`、`PeerLeftBanner`、`RematchWaitingOverlay` 各自獨立

### v0.3.0 — 設計系統、BLE 強化、音效、Canvas、步步為營、西洋跳棋
- 建立完整設計 token 系統
- BLE 傳輸強化：4-byte 大端長度前置 + 逐包重組 + 2 秒超時重置
- 新增 AudioToolbox 音效系統
- 五子棋棋盤改用單一 `Canvas` 渲染
- 加入步步為營（Quoridor）與西洋跳棋（Checkers）

### v0.2.0 — 藍牙傳輸模式
- 新增 `BluetoothTransport`（CoreBluetooth BLE）雙模式傳輸
- 應用層 desync 偵測與重連

### v0.1.0 — 大廳體驗與引擎架構
- 強化 `GameEngine` 協議架構
- 新增單元測試

### v0.0.3 — 初始版本
- 黑白棋（6–12 路）、五子棋（15–25 路）
- `MultipeerConnectivity` 離線大廳與房間
- 防誤觸落子確認、棋盤縮放、浮動聊天室
