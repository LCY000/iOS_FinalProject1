# Final Project - 離線多人棋盤對戰平台

👉 **版本**: 0.3.0
👉 **系統需求**: iOS 26.2+
👉 **開發框架**: Swift / SwiftUI

這是一個以**高擴充性**為目標的 iOS 原生雙人對戰平台。玩家可在無網際網路的狀況下，透過 Wi-Fi 直連或藍牙（Bluetooth LE）尋找附近玩家，建立房間並進行多款棋盤遊戲。

## 🌟 核心特色

- **雙模式離線對戰**：支援 `MultipeerConnectivity`（Wi-Fi）及 `CoreBluetooth`（BLE）兩種傳輸，連飛航模式也能對戰。
- **模組化遊戲架構**：獨創 `GameEngine` 協議，未來加入象棋、西洋棋等新遊戲只需實作單一協議，不需要重寫大廳或房間邏輯。
- **可靠的 BLE 傳輸**：4-byte 大端長度前置 + 逐包重組緩衝 + 2 秒超時自動重置，確保大訊息跨 MTU 分包也不遺失。
- **玩家暱稱系統**：首次進入提示輸入暱稱，廣播名稱以此為準，不洩漏裝置真實名稱。
- **房主規則同步**：由房主統籌選擇遊戲與詳細規則（棋盤大小、禁手等），設定自動同步給對手並校驗版本相容性。
- **再來一場投票**：遊戲結束後雙方可發起投票重賽，對方接受則直接重開、拒絕則回房間。
- **全局聊天系統**：遊戲中右下角浮動聊天，傳訊時彈出 4 秒快顯，不干擾遊戲進行。
- **防誤觸落子系統**：所有遊戲皆採「點擊預覽 → 確認」兩步操作，固定底列確保版面穩定。
- **開發者測試模式**：首頁提供單機模擬雙方連線與聊天，方便快速開發除錯。

## 🎮 支援遊戲

### 黑白棋 (Reversi)
- 自動標示可落子位置（`plus.circle` 圖示）、自動翻轉棋子，紅環標示上一步。
- 無步可走時自動跳過並提示（區分本地/對手視角文案）。
- 支援棋盤大小：6×6、8×8、10×10、12×12。

### 五子棋 (Gomoku)
- 單一 `Canvas` 渲染整張棋盤（最高 25×25 = 625 格），效能遠優於 ZStack 逐格版本。
- 星位與交叉線棋盤，雙指縮放與拖拉平移。
- 可獨立開關的禁手規則：**三三**、**四四**（僅計活四）、**長連**，可分別指定適用對象。

## 🎨 設計系統

所有 UI 尺寸、顏色、陰影、字體均來自 `Core/DesignSystem/`：

| 檔案 | 內容 |
|------|------|
| `Spacing.swift` | xxs=4 … xl=32 |
| `Radius.swift` | s=8, m=12, l=16 |
| `Elevation.swift` | low / mid / high 陰影 |
| `Typography.swift` | appHero / appTitle / appButton 等字體 |
| `ButtonStyles.swift` | PrimaryAction / SecondaryAction / Pill |
| `CardModifier.swift` | `.card(radius:elevation:padding:)` |
| `Haptics.swift` | `.hapticFeedback(_:trigger:)` |

顏色資源（支援 Light/Dark）定義於 `Assets.xcassets/Colors/`，Xcode 16+ 自動生成 `Color.xxx` 擴充。

## ⚙️ 架構概覽

```
Final Project/
├── Core/
│   ├── DesignSystem/          # 設計 token
│   ├── GameEngine.swift       # 遊戲協議 + MessageEnvelope（含版本欄位）
│   ├── GameTransport.swift    # 傳輸協議 + MPCTransport
│   ├── BluetoothTransport.swift  # CoreBluetooth BLE 傳輸
│   ├── MultipeerManager.swift # 傳輸切換 + 狀態管理
│   ├── GameSessionCoordinator.swift  # 多人局統一 envelope 路由
│   ├── RematchVoting.swift    # 再賽投票狀態機（獨立子物件）
│   ├── PlayerNameProvider.swift     # 暱稱持久化
│   ├── SoundManager.swift     # AudioToolbox 音效
│   ├── Logger.swift           # OSLog（bluetooth/mpc/session/game）
│   ├── GameResultOverlay.swift  # 全屏結果卡 + Confetti
│   ├── ChatManager.swift
│   ├── LobbyView.swift
│   └── RoomView.swift
└── Games/
    ├── Reversi/   # ReversiModel + Engine + View + CellView
    └── Gomoku/    # GomokuModel + Engine + View + BoardCanvas + CellView
```

## 🧪 測試

測試目標：`Final ProjectTests`

| 測試檔案 | 涵蓋範圍 |
|---------|---------|
| `ReversiModelTests` | 初始盤面、合法步、翻面、勝負、MessageEnvelope 序列化 |
| `GomokuModelTests` | 五連判定（四方向）、三三／四四／長連禁手 |
| `BluetoothTransportTests` | frame 分包、round-trip 重組、邊界（空／超限 frame）、多訊息順序 |
| `GameSessionCoordinatorTests` | envelope version 欄位編解碼、未來版本阻擋、當前版本放行 |
| `BluetoothStressTests` | 高吞吐量壓力（設定 `BT_STRESS_ENABLED=1` 環境變數後啟用） |

執行：`⌘U`（需在 Xcode 建立 Unit Testing Bundle target 並加入測試檔案）
