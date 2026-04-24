# 雙傳輸模式計劃：WiFi (MPC) ＋ 藍牙 (CoreBluetooth) 並存

## Context

現有 `MultipeerManager` 只用 MultipeerConnectivity（MPC），運作前提是兩台設備在同一 WiFi 路由器下。P2P AWDL 模式雖然文件說支援，但實測不穩定（Apple 給第三方 app 的 AWDL 優先級低），飛航模式下完全不可用。

目標：加入 CoreBluetooth (BLE) 傳輸通道，讓使用者在 LobbyView 選擇「WiFi」或「藍牙」模式，飛航模式 + 藍牙打開即可對戰，不需要任何網路。

---

## 架構決策：Transport 抽象 + Strategy（外部介面完全不變）

**關鍵限制**：`RoomView` 使用 `@Bindable var multipeerManager: MultipeerManager`，`GameSessionCoordinator` 使用 `let multipeerManager: MultipeerManager`——具體型別在 3 個地方寫死。

**結論**：`MultipeerManager` 對外 API 完全不變；內部抽一個 `GameTransport` protocol，分別實作 `MPCTransport` 與 `BluetoothTransport`，`MultipeerManager` 只持有一個 `transport: any GameTransport` 並轉發。用 protocol 取代原本預想的散落 switch，後續加 transport 也不用再改 5 個 public method。

```swift
protocol GameTransport: AnyObject {
    // UI 狀態推送
    var onPeerDiscovered: ((DiscoveredPeer) -> Void)? { get set }
    var onPeerConnected: ((String) -> Void)? { get set }       // passes peer display name
    var onPeerDisconnected: (() -> Void)? { get set }
    var onDataReceived: ((Data) -> Void)? { get set }

    // 生命週期
    func startHosting()
    func startBrowsing()
    func invite(_ peer: DiscoveredPeer)
    func send(_ data: Data)
    func disconnect()
}
```

`MultipeerManager` 在 `hostGame()` / `joinGame()` 開頭按 `connectionMode` 建立對應 transport，接上四個 callback 後轉成自身的 `@Observable` 狀態 (`connectionState` / `discoveredPeers` / `connectedPeerName`)，並用現有的 `onEnvelopeReceived` / `onDisconnected` / `onPeerConnected` 向上層派送。

**影響範圍**：
- `RoomView.swift` — 零修改
- `GameSessionCoordinator.swift` — 零修改（但要新增一個 desync alert 狀態，見下文）
- 所有 GameView / GameEngine — 零修改

---

## 新增檔案

### `Final Project/Core/GameTransport.swift`

- 定義 `GameTransport` protocol（見上）
- 把現有 MPC 邏輯從 `MultipeerManager` 提取成 `MPCTransport: NSObject, GameTransport`，保留所有 `MCSessionDelegate` / `MCNearbyServiceAdvertiserDelegate` / `MCNearbyServiceBrowserDelegate` 行為，只是把「更新 UI state」換成「呼 callback」。

### `Final Project/Core/BluetoothTransport.swift`

CoreBluetooth 全部邏輯集中在此，也實作 `GameTransport`。

```
BluetoothTransport (NSObject)
  ├── role: .none | .host | .guest
  │
  ├── Host 端 (CBPeripheralManager)
  │   ├── peripheralManager: CBPeripheralManager
  │   ├── hostToGuestChar: CBMutableCharacteristic  [indicate]
  │   └── guestToHostChar: CBMutableCharacteristic  [write]
  │
  ├── Guest 端 (CBCentralManager)
  │   ├── centralManager: CBCentralManager
  │   ├── connectedPeripheral: CBPeripheral?
  │   ├── hostToGuestCharRef: CBCharacteristic?     (subscribe)
  │   └── guestToHostCharRef: CBCharacteristic?     (write target)
  │
  ├── peripheralByID: [ObjectIdentifier: CBPeripheral]  (invitePeer lookup)
  ├── receiveBuffer: Data / expectedLength: Int          (reassembly)
  ├── reassemblyTimeoutTask: Task?                       (2s guard against stuck reassembly)
  └── pendingWriteRetry: Data?                           (Guest→Host 單次重試用)
```

**BLE UUIDs（128-bit，自訂）**
```swift
serviceUUID         = "B8A7C6D5-E4F3-1A2B-3C4D-5E6F7A8B9C0D"
hostToGuestCharUUID = "B8A7C6D5-E4F3-1A2B-3C4D-000000000001"  // indicate（非 notify）
guestToHostCharUUID = "B8A7C6D5-E4F3-1A2B-3C4D-000000000002"  // write
```

> **為何用 Indicate 而非 Notify**：Indicate (GATT ATT_HANDLE_VALUE_INDICATION) 要求 Central 每收到一條 Indication 就回 ATT Confirmation，Peripheral 才能發下一條，等於在 BLE 協定層拿到免費的 delivery guarantee，完全不需要 app-level ACK 邏輯。棋盤遊戲落子頻率極低，one-in-flight 限制沒有實際影響。

---

## 修改的檔案

### 1. `Core/MultipeerManager.swift`

新增到現有檔案：
```swift
enum ConnectionMode: String, CaseIterable {
    case wifi      = "WiFi"
    case bluetooth = "藍牙"
}
var connectionMode: ConnectionMode = .wifi   // @Observable
private var transport: (any GameTransport)?
```

各 public method 改為委派給 `transport`：
- `hostGame()` → 建立對應 transport（依 `connectionMode`），接 callback，呼 `transport.startHosting()`
- `joinGame()` → 同上，呼 `transport.startBrowsing()`
- `invitePeer()` → `transport?.invite(peer)`
- `send(envelope:)` → 編碼後 `transport?.send(data)`
- `cleanup()` → `transport?.disconnect(); transport = nil`

Callback 接法（在建立 transport 後馬上綁）：
```swift
transport.onPeerDiscovered  = { [weak self] peer in self?.discoveredPeers.appendIfNew(peer) }
transport.onPeerConnected   = { [weak self] name in
    self?.connectionState = .connected
    self?.connectedPeerName = name
    self?.onPeerConnected?()
}
transport.onPeerDisconnected = { [weak self] in
    self?.connectionState = .disconnected
    self?.connectedPeerName = nil
    self?.onDisconnected?()
}
transport.onDataReceived = { [weak self] data in
    guard let envelope = MessageEnvelope.decode(from: data) else {
        print("MultipeerManager: envelope decode failed — possible desync")
        return
    }
    self?.onEnvelopeReceived?(envelope)
}
```

現有的 MPC 邏輯不留在 `MultipeerManager`，全搬去 `MPCTransport`。

### 2. `Core/LobbyView.swift`

在「建立房間」/「尋找房間」按鈕上方加 Picker：
```swift
Picker("連線方式", selection: $multipeerManager.connectionMode) {
    ForEach(ConnectionMode.allCases, id: \.self) { mode in
        Label(mode.rawValue,
              systemImage: mode == .wifi ? "wifi" : "airplane")
            .tag(mode)
    }
}
.pickerStyle(.segmented)
.padding(.horizontal, 32)
```

### 3. `Info.plist`

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>藍牙模式用於近距離無路由器對戰（飛航模式可用）</string>
```

---

## CoreBluetooth 連線流程

```
Host (Peripheral)                         Guest (Central)
─────────────────                         ───────────────
startAdvertising(serviceUUID + 裝置名)

                                          scanForPeripherals([serviceUUID])
                                          didDiscover peripheral
                                          → discoveredPeers 加入假 DiscoveredPeer

                                          [User 點選 peer]
                                          centralManager.connect(peripheral)
                                          didConnect
                                          → discoverServices
                                          → discoverCharacteristics
                                          → setNotifyValue(true, hostToGuestChar)

didSubscribeTo hostToGuestChar            didUpdateNotificationStateFor (isNotifying=true)
→ stopAdvertising()                       → connectionState = .connected
→ connectionState = .connected            → stopScan()
→ onPeerConnected?()                      → onPeerConnected?()
```

### 資料傳輸方向

| 方向 | 機制 | 可靠性保證 |
|------|------|-----------|
| Host → Guest | `peripheralManager.updateValue(_:for:onSubscribedCentrals:)` | ATT Indication — Central 回 Confirmation 才算送達 |
| Guest → Host | `peripheral.writeValue(_:for:type:.withResponse)` | ATT Write Response — `didWriteValueFor` 回報成功/失敗 |
| Host 接收 | `peripheralManager(_:didReceiveWriteRequests:)` | — |
| Guest 接收 | `peripheral(_:didUpdateValueFor:)` | — |

### 封包分割（Length-prefix framing）

iPhone 間 BLE MTU 通常協商到 185–512 bytes，足夠大多數 MessageEnvelope。但為穩健性實作長度前綴：

**Send**（`frame(_ data: Data) -> [Data]`）：
1. 取得 MTU（`peripheral.maximumWriteValueLength(for: .withResponse)` 或 Peripheral 端的對應值）
2. 第一個封包 = 4-byte big-endian 總長 + 前 `MTU-4` bytes
3. 後續封包 = 純資料塊
4. 多封包按序傳送，Host 端用 `peripheralManagerIsReady(toUpdateSubscribers:)` 做流量控制

**Receive**（兩端共用 `handleIncoming(_ data: Data)`）：
1. buffer 為空 → 解析前 4 bytes 得 `expectedLength`，剩餘加入 buffer；同時啟動 2 秒 reassembly timeout
2. buffer 非空 → append
3. `buffer.count >= expectedLength` → 截取前 N bytes 解碼 MessageEnvelope，清空 buffer、取消 timeout
4. 若 `expectedLength > 64 * 1024` → 視為垃圾資料，清空 buffer、log warning
5. Reassembly timeout 觸發（2s 內未收齊）→ 清空 buffer、log warning、不斷線（下一個封包會被當新的 frame header 重新開始）

**Buffer reset 時機**（重要）：
- Host 端：`didSubscribeTo` / `didUnsubscribeFrom`
- Guest 端：`didConnect` / `didDisconnectPeripheral`
- Transport `disconnect()` 呼叫時

### 斷線偵測

- Guest 端：`centralManager(_:didDisconnectPeripheral:error:)` → `onPeerDisconnected?()`
- Host 端：`peripheralManager(_:central:didUnsubscribeFrom:)` 對應 `hostToGuestChar` → 同上

### Guest → Host 寫入失敗處理（單次重試）

`peripheral(_:didWriteValueFor:error:)` 是 Guest 端 `writeValue(_:type: .withResponse)` 的完成回呼。

流程：
1. 每次 `writeValue` 前，把 `Data` 暫存到 `pendingWriteRetry`
2. `didWriteValueFor` 成功（`error == nil`）→ 清掉 `pendingWriteRetry`
3. `didWriteValueFor` 失敗且 `pendingWriteRetry != nil` → 重試 1 次（再 `writeValue` 一次同一份 data），並將 `pendingWriteRetry` 設為 nil 避免無限重試
4. 重試後仍失敗（再次進來 `didWriteValueFor` with error, 此時 `pendingWriteRetry == nil`）→ 呼叫 `onPeerDisconnected?()` 走斷線流程

> 為何需要 app-level retry：CoreBluetooth 底層已有 ATT 重傳，走到 `error != nil` 通常是 transient timing 問題（link layer 切 channel、ATT timeout 等）再試常常就過。連續兩次失敗才合理判定真的斷了。Host → Guest（Indicate）方向不需要此邏輯：CoreBluetooth 會無限重送到 Central disconnect 為止，應用層只需要做流量控制即可。

---

## DiscoveredPeer 相容性（無需改 struct）

現有 `DiscoveredPeer.id: MCPeerID`，BLE 用 `CBPeripheral`。

做法：BLE 為每個 peripheral 建假 `MCPeerID(displayName: 廣播名稱)`，存入 `peripheralByID[ObjectIdentifier(fakePeerID)] = peripheral`。`invitePeer` BLE path 用 `ObjectIdentifier(peer.id)` 查找對應 peripheral 連線。`DiscoveredPeer` struct 完全不改。

**廣播名衝突**：兩台裝置都叫 `iPhone` 會導致 `MCPeerID` equality 衝突（現有 `DiscoveredPeer.==` 比對 `id`）。Host 廣播時用：
```swift
let broadcastName = "\(UIDevice.current.name)｜\(UUID().uuidString.prefix(6))"
```
Guest 端收到後仍以 peripheral 自己的 `identifier.uuidString` 為真正唯一 key，`displayName` 僅拿來顯示。

---

## 應用層一致性：序號 + desync 偵測

傳輸層（MPC `.reliable` / BLE Indicate + Write Response）已保證「連線活著時不掉封包」，但以下情況仍可能讓兩邊棋盤不一致：
- Envelope decode 失敗（buffer 錯位、schema mismatch、硬體翻譯錯誤）→ `MultipeerManager` 內的 `guard let envelope = ... else { return }` 會靜默吃掉
- `receiveRemoteMove` 的 `guard currentPlayer != localPlayer` 因前面漏步已經狀態不同步，這次也被擋掉，錯誤雪球滾大

**解法**：每個落子封包帶遞增序號，不一致就彈 alert、結束遊戲。

### `MoveMessage` 擴充

```swift
struct MoveMessage: Codable {
    let row: Int
    let col: Int
    let seq: UInt32   // sender 每步 +1，從 1 開始
}
```

### Engine 層狀態

`GameEngine` protocol 新增：
```swift
var nextSendSeq: UInt32 { get set }       // 初始 1，每次成功送出 +1
var expectedRecvSeq: UInt32 { get set }   // 初始 1，收到正確後 +1
var onDesyncDetected: (() -> Void)? { get set }
```

- `executePlacement` / `confirmMove` 成功落子後：組 `MoveMessage(..., seq: nextSendSeq)` 送出，送完 `nextSendSeq += 1`
- `receiveRemoteMove`：
  ```swift
  guard let move = MoveMessage.fromData(data) else { onDesyncDetected?(); return }
  guard move.seq == expectedRecvSeq else { onDesyncDetected?(); return }
  // 正常 apply
  expectedRecvSeq += 1
  ```
- `reset()` 同時歸零兩個 seq（rematch 場景）

`sendMoveEnvelope` helper 同步更新：
```swift
func sendMoveEnvelope(row: Int, col: Int, gameType: String) {
    guard isMultiplayer else { return }
    let move = MoveMessage(row: row, col: col, seq: nextSendSeq)
    nextSendSeq &+= 1
    let envelope = MessageEnvelope(type: .playerMove, gameType: gameType, payload: move.toData())
    onMoveToSend?(envelope)
}
```

### Coordinator / UI

`GameSessionCoordinator` 新增：
```swift
var showDesyncAlert: Bool = false
```

`wireEngineCallbacks` 加：
```swift
engine.onDesyncDetected = { [weak self] in
    self?.showDesyncAlert = true
    self?.multipeerManager.disconnect()
}
```

RoomView / GameView 加一個 `.alert("同步錯誤", isPresented: $coordinator.showDesyncAlert) { ... }`，內容提示玩家連線異常、請重新開始。按鈕：「返回大廳」→ pop 到 LobbyView。

### 單元測試

`GomokuModelTests` / `ReversiModelTests` 加 desync 場景：手動餵一個 `seq` 錯的 `MoveMessage.toData()` 給 `receiveRemoteMove`，驗證 `onDesyncDetected` 有被觸發且盤面沒被 apply。

---

## 已知陷阱與解法

| 陷阱 | 解法 |
|------|------|
| CBPeripheralManager/CentralManager 需等 `.poweredOn` | 在 `didUpdateState(.poweredOn)` callback 才呼叫 `startAdvertising`/`scanForPeripherals` |
| `peripheral.name` 可能為 nil | Host 廣播時加 `CBAdvertisementDataLocalNameKey: broadcastName`（見 DiscoveredPeer 段）；Guest 從 advertisementData 取名 |
| `objectIdentifier` 跨呼叫失效 | `peripheralByID` 以 `ObjectIdentifier(fakeMCPeerID)` 為 key，`peer.id` 是同一物件（struct 複製保留 class 參考）→ 查找有效 |
| iOS 模擬器無法測試 BLE | 僅用實機測試藍牙路徑；WiFi 路徑仍可用模擬器 |
| 大封包（StartGamePayload > MTU） | Length-prefix framing 處理 |
| Peripheral 發送流量控制 | `peripheralManagerIsReady(toUpdateSubscribers:)` 繼續發送排隊封包 |
| Host → Guest 封包遺失（reassembly 錯位） | Indicate + reassembly timeout + buffer reset on (dis)connect |
| Guest → Host 寫入 transient 失敗 | `didWriteValueFor` error 時單次重試，再失敗走 disconnect |
| 連線活著但應用層漏步 | `MoveMessage.seq` 序號檢查；不符即觸發 desync alert 並斷線 |
| `connectionMode` 在連線中途改變 | Picker **只有 `.notConnected` 時可互動**；`.hosting` / `.browsing` / `.connecting` / `.connected` / `.disconnected` 都 disabled |
| BLE 在背景受限 | 與 MPC 相同行為：App 必須在前景，現有設計已符合 |
| `DEBUG_TEST_MODE` 走 transport 會卡住 | 測試模式維持現有「不經 `MultipeerManager.send`」的路徑，不觸到 transport 層 |

---

## 實作順序

1. `Info.plist` — 加 `NSBluetoothAlwaysUsageDescription`
2. `GameEngine.swift` — `MoveMessage` 加 `seq`；`GameEngine` protocol 加 `nextSendSeq` / `expectedRecvSeq` / `onDesyncDetected`；`sendMoveEnvelope` helper 套用新 seq
3. 各 Engine（`ReversiEngine` / `GomokuEngine`）— 宣告新屬性、預設值、`reset()` 歸零、`receiveRemoteMove` 加 seq 檢查
4. `GameSessionCoordinator.swift` — 新增 `showDesyncAlert`，`wireEngineCallbacks` 接 `onDesyncDetected`
5. RoomView / GameView — 掛 `.alert("同步錯誤", isPresented: $showDesyncAlert)`
6. `GameTransport.swift`（新建）— protocol 定義 + `MPCTransport` 從現有 `MultipeerManager` 提取
7. `MultipeerManager.swift` — 加 `ConnectionMode` / `connectionMode`；內部改持 `transport: any GameTransport`；public method 全部委派到 transport
8. `BluetoothTransport.swift`（新建）— 依序：
   a. UUIDs 常數、Role enum、屬性宣告（含 `reassemblyTimeoutTask` / `pendingWriteRetry`）
   b. `startHosting()` / `startBrowsing()` / `invite()` / `send()` / `disconnect()`
   c. `CBPeripheralManagerDelegate`（didUpdateState, didAdd, didSubscribeTo, didUnsubscribeFrom, didReceiveWriteRequests, peripheralManagerIsReady）
   d. `CBCentralManagerDelegate`（didUpdateState, didDiscover, didConnect, didDisconnect）
   e. `CBPeripheralDelegate`（didDiscoverServices, didDiscoverCharacteristics, didUpdateNotificationStateFor, didUpdateValueFor, didWriteValueFor — 含單次重試邏輯）
   f. `frame()` / `handleIncoming()`（含 timeout + size sanity check + buffer reset 時機）
9. `LobbyView.swift` — 加 `Picker` segmented control，**只有 `.notConnected` 時 enabled**
10. RoomView — 頂部加一個小徽章顯示當前 `connectionMode`（WiFi / 藍牙 icon）

---

## 關鍵檔案路徑

- `Final Project/Core/GameTransport.swift` — 新建（protocol + MPCTransport）
- `Final Project/Core/BluetoothTransport.swift` — 新建（BLE 實作）
- `Final Project/Core/MultipeerManager.swift` — 重構為 transport 轉發層
- `Final Project/Core/GameEngine.swift` — `MoveMessage.seq` / protocol 新屬性
- `Final Project/Core/GameSessionCoordinator.swift` — `showDesyncAlert` + desync 導流
- `Final Project/Core/LobbyView.swift` — 加 Picker
- `Final Project/Core/RoomView.swift` — 頂部 mode 徽章 + desync alert
- `Final Project/Games/Reversi/ReversiEngine.swift` — seq 檢查
- `Final Project/Games/Gomoku/GomokuEngine.swift` — seq 檢查
- `Final Project/Info.plist` — 加 BT 權限
- `Final ProjectTests/ReversiModelTests.swift` / `GomokuModelTests.swift` — desync 測試

---

## 驗證計劃

> BLE 必須用實機，模擬器無 BLE 硬體

1. **WiFi 路徑不受影響**：兩台同 WiFi → 連線、落子、聊天、rematch、離開 → 全部正常
2. **BLE 基本連線**：飛航模式 + 藍牙 → 一台建立、另一台搜尋 → 看到對方 → 連上
3. **BLE 遊戲流程**：黑白棋 + 五子棋各走幾步 → 落子雙向同步正確
4. **BLE 大封包**：25×25 五子棋 + 所有禁手開啟的 `StartGamePayload` 必定分片 → 雙方規則一致；驗證 reassembly
5. **BLE 聊天**：ChatMessage 傳輸正確
6. **BLE 斷線**：其中一台強制 kill app → 另一台出現「連線已中斷」
7. **切換模式**：同一個 session 中 WiFi → disconnect → 切藍牙 → 重新連線 → 正常
8. **BLE 中途關藍牙**：連線中把其中一台藍牙關掉 → 另一台在 ~10 秒內看到「連線已中斷」
9. **權限拒絕**：首次彈權限點「不允許」→ UI 有明確提示（不能卡在 browsing loading）
10. **Desync alert 觸發**：單元測試手動餵錯 seq 的 `MoveMessage` → `onDesyncDetected` 觸發，盤面未變
11. **裝置同名**：兩台都叫 `iPhone` → `DiscoveredPeer` 不會互相覆蓋，廣播名帶 UUID 後綴區別
12. **Mode Picker 鎖定**：進入 `.browsing` / `.hosting` / `.connecting` / `.connected` 任一狀態 → Picker 不可互動
