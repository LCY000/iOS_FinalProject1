# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test

- **Build/Run**: Open `Final Project.xcodeproj` in Xcode 16+, then `⌘R`
- **Tests**: `⌘U` (targets `Final ProjectTests`)
- **Run without debugger** (fixes iPhone white-screen issue): `Ctrl+Cmd+R`
- **Stress tests**: Set environment variable `BT_STRESS_ENABLED=1` in the scheme to enable `BluetoothStressTests`
- **Debug test mode**: `ContentView.swift` line 13 — set `DEBUG_TEST_MODE = true` to enable single-device multiplayer simulation

No SPM, no Makefile — pure `.xcodeproj`.

## Architecture

### Plugin-based Game System

All games implement the `GameEngine` protocol (`Core/GameEngine.swift`). Adding a new game requires:
1. `Games/<Name>/` with `<Name>Model.swift` (pure logic, no UI), `<Name>Engine.swift` (GameEngine conformance), and view files
2. One line in `GameRegistry.swift`: `GameInfo(title:, icon:, gameType:, createEngine:)`

The Lobby, Room, Chat, sound, and voting systems require **no changes** when adding a game.

### Networking Layer

Two transport implementations behind the `GameTransport` protocol (`Core/GameTransport.swift`):
- **MPCTransport** — MultipeerConnectivity (Wi-Fi Direct), service type `_game-platform._tcp`
- **BluetoothTransport** — CoreBluetooth BLE; Host = Peripheral, Guest = Central; 4-byte big-endian length prefix + reassembly with 2s timeout

`MultipeerManager` wraps both and allows switching transport without touching game logic.

### Session & Message Routing

`GameSessionCoordinator` is the **single source of truth** for all multiplayer message routing. All network messages are `MessageEnvelope` structs (type + gameType + payload + version). Never bypass the coordinator to send/receive directly.

### Concurrency Model

The project runs under `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` (Swift 6 strict mode). All code is MainActor by default. MC/BLE delegate callbacks arrive on background threads — always bridge back with `Task { @MainActor in ... }` and mark delegates `nonisolated`.

## Key Pitfalls

1. **MCPeerID must be recreated on cleanup** — `cleanup()` must `myPeerID = MCPeerID(displayName: ...)`, otherwise reconnect fails with a stale peer ID.
2. **Navigation via `.onChange`, not callbacks** — `onPeerConnected` callback gets cleared by `cleanup()`; use `.onChange(of: connectionState)` for navigation triggers.
3. **Manual disconnect on RoomView exit** — the custom back button must call `multipeerManager.disconnect()` or the connection lingers.
4. **Confirm/cancel buttons in bottom toolbar** — placing them above the board causes layout jumping; they belong in the fixed-height bottom bar at the right side.
5. **Four-four forbidden rule (Gomoku)** — counts only open-ended fours (both ends empty); blocked fours must not trigger the rule.

## Design System

All UI tokens live in `Core/DesignSystem/`:
- Spacing: `Spacing.xxs`(4) … `Spacing.xl`(32)
- Corners: `Radius.s/m/l`
- Shadows: `Elevation.low/mid/high`
- Typography: `.appHero`, `.appTitle`, `.appButton`, etc. (font extensions)
- Colors: `Assets.xcassets/Colors/` with Light/Dark variants — referenced as `Color.xxx`

Use `.card(radius:elevation:padding:)` modifier and `PrimaryAction`/`SecondaryAction`/`Pill` button styles for consistency.

## OSLog Categories

`Core/Logger.swift` defines four OSLog subsystems: `bluetooth`, `mpc`, `session`, `game`. Use these (not `print`) for all diagnostic output.

## iOS Version & Permissions

- Minimum deployment: **iOS 26.2**
- Required `Info.plist` entries: `NSLocalNetworkUsageDescription`, `NSBonjourServices` (`["_boardgame._tcp"]`), `NSBluetoothAlwaysUsageDescription`
