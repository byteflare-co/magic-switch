# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run Commands

```bash
make build          # Debug build (swift build)
make release        # Release build (swift build -c release)
make run            # Debug build + run
make test           # Run all tests (swift test)
make bundle         # Create .app bundle (release + code sign)
make bundle-run     # Create .app bundle and open it
make clean          # Clean build artifacts
```

Run a single test: `swift test --filter MagicSwitchCoreTests.ConfigStoreTests`

No linter is configured. Follow Swift API Design Guidelines.

## Architecture

macOS menu bar app (Swift 5.9+, macOS 13+) built with SPM. Switches Magic Keyboard/Trackpad between two Macs using Bluetooth and a peer-to-peer network protocol compatible with [Blue Switch](https://github.com/nicola02nb/Blue-Switch).

### Two-target structure

- **MagicSwitch** (executable) — App entry point, SwiftUI/AppKit UI, ViewModels
- **MagicSwitchCore** (library) — All business logic: Bluetooth, networking, storage, models

### Layered design

```
Presentation (Views, MenuBarController)
    → ViewModels (@MainActor, @Published)
    → Services (SwitchService, DeviceDiscoveryService)
    → Core (BluetoothManager, NetworkManager, ConfigStore)
```

### Concurrency model

- Core managers and services are **Swift Actors** for thread safety
- All UI components and ViewModels are `@MainActor`
- Public types conform to `Sendable`
- Uses async/await throughout (no completion handlers)

### Key subsystems

- **Bluetooth** (`BluetoothManager` actor): Wraps IOBluetooth.framework via `IOBluetoothAdapter`. Handles device discovery, pairing, connect/disconnect. `BatteryMonitor` tracks battery levels.
- **Network** (`NetworkManager` actor): Mac-to-Mac communication over TCP using Bonjour discovery (`_magicswitch._tcp.`). Uses `PeerBrowser`, `PeerListener`, `PeerConnection`. Heartbeat via HEALTH_CHECK every 30s.
- **Switching** (`SwitchService` actor): Orchestrates device switching. Two modes: "push" (all connected → release locally, send CONNECT_ALL to peer) and "pull" (all disconnected → send UNREGISTER_ALL to peer, acquire locally). Retry with exponential backoff.
- **Storage** (`ConfigStore` actor): JSON persistence in `~/Library/Application Support/MagicSwitch/`
- **DI** (`DependencyContainer`): Creates and wires all service instances

### Dependencies

- `swift-log` — Structured logging (categories: bluetooth, network, switch, ui, storage)
- `KeyboardShortcuts` (2.0.0) — Global keyboard shortcuts for switching
- `LaunchAtLogin-Modern` — Login item registration
- System frameworks: IOBluetooth, Network, AppKit, SwiftUI

## Deploy Procedure

ユーザーから「デプロイ」「push してデプロイ」等の指示があった場合、以下を一連で実行する:

1. **コミット & プッシュ** — 未コミットの変更があればコミットして `git push`
2. **バージョンアップ** — `Resources/Info.plist` の `CFBundleVersion` と `CFBundleShortVersionString` をインクリメント（パッチ: x.y.Z、マイナー: x.Y.0、メジャー: X.0.0）。指定がなければパッチを上げる。バージョンアップのコミット & プッシュも行う
3. **タグ** — `git tag v{VERSION}` でタグを打ち `git push --tags`
4. **ビルド** — `make bundle` でリリースビルド & .app バンドル作成
5. **GitHub Release** — `gh release create v{VERSION}` で zip をアップロード。リリースノートは直前のタグからの変更を要約する。フォーマット:
   ```
   ## v{VERSION}

   ### Changes
   - 変更点を箇条書き

   ### Install / Update
   \```bash
   brew tap byteflare-co/tap
   brew install --cask magic-switch
   \```
   ```
6. **再インストール & 起動** — 既存プロセスを終了し、`open .build/release/MagicSwitch.app` で起動

## Protocol

Text-based newline-delimited commands over TCP: `CONNECT_ALL`, `UNREGISTER_ALL`, `HEALTH_CHECK`, `OP_SUCCESS`, `OP_FAILED`, `NOTIFICATION`, `SYNC_PERIPHERALS`, `PERIPHERAL_DATA`. See `docs/blue-switch-spec.md` for full spec.
