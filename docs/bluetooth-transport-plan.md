# 雙傳輸模式計劃：WiFi (MPC) ＋ 藍牙 (CoreBluetooth) 並存

## Context

現有 `MultipeerManager` 只用 MultipeerConnectivity（MPC），運作前提是兩台設備在同一 WiFi 路由器下。P2P AWDL 模式雖然文件說支援，但實測不穩定（Apple 給第三方 app 的 AWDL 優先級低），飛航模式下完全不可用。

目標：加入 CoreBluetooth (BLE) 傳輸通道，讓使用者在 LobbyView 選擇「WiFi」或「藍牙」模式，飛航模式 + 藍牙打開即可對戰，不需要任何網路。

---

## 架構決策：Strategy Pattern（外部介面完全不變）

**關鍵限制**：`RoomView` 使用 `@Bindable var multipeerManager: MultipeerManager`，`GameSessionCoordinator` 使用 `let multipeerManager: MultipeerManager`——具體型別在 3 個地方寫死。

**結論**：不抽 protocol，改用 Strategy Pattern——`MultipeerManager` 對外 API 完全不變，內部根據 `connectionMode` 分派給 MPC 或 BLE 實作。

**影響範圍**：
- `RoomView.swift` — 零修改
- `GameSessionCoordinator.swift` — 零修改
- 所有 GameView / GameEngine — 零修改

---

## 新增檔案

### `Final Project/Core/BluetoothTransport.swift`

CoreBluetooth 全部邏輯集中在此，以 delegate callback 更新 `MultipeerManager` 的 state。

```
BluetoothTransport (NSObject)
  ├── role: .none | .host | .guest
  │
  ├── Host 端 (CBPeripheralManager)
  │   ├── peripheralManager: CBPeripheralManager
  │   ├── hostToGuestChar: CBMutableCharacteristic  [notify]
  │   └── guestToHostChar: CBMutableCharacteristic  [write]
  │
  ├── Guest 端 (CBCentralManager)
  │   ├── centralManager: CBCentralManager
  │   ├── connectedPeripheral: CBPeripheral?
  │   ├── hostToGuestCharRef: CBCharacteristic?     (subscribe)
  │   └── guestToHostCharRef: CBCharacteristic?     (write target)
  │
  ├── peripheralByID: [ObjectIdentifier: CBPeripheral]  (invitePeer lookup)
  └── receiveBuffer: Data / expectedLength: Int          (reassembly)
```

**BLE UUIDs（128-bit，自訂）**
```swift
serviceUUID         = "B8A7C6D5-E4F3-1A2B-3C4D-5E6F7A8B9C0D"
hostToGuestCharUUID = "B8A7C6D5-E4F3-1A2B-3C4D-000000000001"  // notify
guestToHostCharUUID = "B8A7C6D5-E4F3-1A2B-3C4D-000000000002"  // write
```

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
private var bluetoothTransport: BluetoothTransport?
```

各 public method 加 switch dispatch：
- `hostGame()` → `connectionMode == .wifi ? hostViaMPC() : hostViaBluetooth()`
- `joinGame()` → 同上
- `invitePeer()` → MPC path 不變；BLE path 呼叫 `bluetoothTransport?.connectToPeer(peer)`
- `send(envelope:)` → MPC path 不變；BLE path 呼叫 `bluetoothTransport?.send(data:)`
- `cleanup()` → 額外加 `bluetoothTransport?.cleanup(); bluetoothTransport = nil`

現有 MPC 邏輯不動（提取成 `private func hostViaMPC()` 等）。

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

| 方向 | 機制 |
|------|------|
| Host → Guest | `peripheralManager.updateValue(_:for:onSubscribedCentrals:)` |
| Guest → Host | `peripheral.writeValue(_:for:type:.withResponse)` |
| Host 接收 | `peripheralManager(_:didReceiveWriteRequests:)` |
| Guest 接收 | `peripheral(_:didUpdateValueFor:)` |

### 封包分割（Length-prefix framing）

iPhone 間 BLE MTU 通常協商到 185–512 bytes，足夠大多數 MessageEnvelope。但為穩健性實作長度前綴：

**Send**（`frame(_ data: Data) -> [Data]`）：
1. 取得 MTU（`peripheral.maximumWriteValueLength(for: .withResponse)` 或 Peripheral 端的對應值）
2. 第一個封包 = 4-byte big-endian 總長 + 前 `MTU-4` bytes
3. 後續封包 = 純資料塊
4. 多封包按序傳送，Host 端用 `peripheralManagerIsReady(toUpdateSubscribers:)` 做流量控制

**Receive**（兩端共用 `handleIncoming(_ data: Data)`）：
1. buffer 為空 → 解析前 4 bytes 得 `expectedLength`，剩餘加入 buffer
2. buffer 非空 → append
3. `buffer.count >= expectedLength` → 截取前 N bytes 解碼 MessageEnvelope，清空 buffer

### 斷線偵測

- Guest 端：`centralManager(_:didDisconnectPeripheral:error:)` → `connectionState = .disconnected; onDisconnected?()`
- Host 端：`peripheralManager(_:central:didUnsubscribeFrom:)` 對應 `hostToGuestChar` → 同上

---

## DiscoveredPeer 相容性（無需改 struct）

現有 `DiscoveredPeer.id: MCPeerID`，BLE 用 `CBPeripheral`。

做法：BLE 為每個 peripheral 建假 `MCPeerID(displayName: 廣播名稱)`，存入 `peripheralByID[ObjectIdentifier(fakePeerID)] = peripheral`。`invitePeer` BLE path 用 `ObjectIdentifier(peer.id)` 查找對應 peripheral 連線。`DiscoveredPeer` struct 完全不改。

---

## 已知陷阱與解法

| 陷阱 | 解法 |
|------|------|
| CBPeripheralManager/CentralManager 需等 `.poweredOn` | 在 `didUpdateState(.poweredOn)` callback 才呼叫 `startAdvertising`/`scanForPeripherals` |
| `peripheral.name` 可能為 nil | Host 廣播時加 `CBAdvertisementDataLocalNameKey: UIDevice.current.name`；Guest 從 advertisementData 取名 |
| `objectIdentifier` 跨呼叫失效 | `peripheralByID` 以 `ObjectIdentifier(fakeMCPeerID)` 為 key，`peer.id` 是同一物件（struct 複製保留 class 參考）→ 查找有效 |
| iOS 模擬器無法測試 BLE | 僅用實機測試藍牙路徑；WiFi 路徑仍可用模擬器 |
| 大封包（StartGamePayload > MTU） | Length-prefix framing 處理 |
| Peripheral 發送流量控制 | `peripheralManagerIsReady(toUpdateSubscribers:)` 繼續發送排隊封包 |
| `connectionMode` 在連線中途改變 | Picker 在連線成功後（state = .connected）disableInteraction；cleanup 時重啟才能改 |
| BLE 在背景受限 | 與 MPC 相同行為：App 必須在前景，現有設計已符合 |

---

## 實作順序

1. `Info.plist` — 加 `NSBluetoothAlwaysUsageDescription`
2. `MultipeerManager.swift` — 加 `ConnectionMode`、`connectionMode`、`bluetoothTransport`；現有 MPC 邏輯提取成私有方法；各 public method 加 switch
3. `BluetoothTransport.swift`（新建）— 依序：
   a. UUIDs 常數、Role enum、屬性宣告
   b. `startHosting()` / `startBrowsing()` / `connectToPeer()` / `send()` / `cleanup()`
   c. `CBPeripheralManagerDelegate`（didUpdateState, didAdd, didSubscribeTo, didReceiveWriteRequests, peripheralManagerIsReady）
   d. `CBCentralManagerDelegate`（didUpdateState, didDiscover, didConnect, didDisconnect）
   e. `CBPeripheralDelegate`（didDiscoverServices, didDiscoverCharacteristics, didUpdateNotificationStateFor, didUpdateValueFor）
   f. `frame()` / `handleIncoming()`
4. `LobbyView.swift` — 加 `Picker` segmented control + Picker 在已連線時 disabled

---

## 關鍵檔案路徑

- `Final Project/Core/MultipeerManager.swift` — 主要修改
- `Final Project/Core/BluetoothTransport.swift` — 新建
- `Final Project/Core/LobbyView.swift` — 加 Picker
- `Final Project/Info.plist` — 加 BT 權限

不動的檔案：RoomView, GameSessionCoordinator, 所有 GameEngine/GameView

---

## 驗證計劃

> BLE 必須用實機，模擬器無 BLE 硬體

1. **WiFi 路徑不受影響**：兩台同 WiFi → 連線、落子、聊天、rematch、離開 → 全部正常
2. **BLE 基本連線**：飛航模式 + 藍牙 → 一台建立、另一台搜尋 → 看到對方 → 連上
3. **BLE 遊戲流程**：黑白棋 + 五子棋各走幾步 → 落子雙向同步正確
4. **BLE 大封包**：設定同步（StartGamePayload）正確 → 雙方規則一致
5. **BLE 聊天**：ChatMessage 傳輸正確
6. **BLE 斷線**：其中一台強制 kill app → 另一台出現「連線已中斷」
7. **切換模式**：同一個 session 中 WiFi → disconnect → 切藍牙 → 重新連線 → 正常
