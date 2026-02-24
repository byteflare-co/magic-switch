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

## Protocol

Text-based newline-delimited commands over TCP: `CONNECT_ALL`, `UNREGISTER_ALL`, `HEALTH_CHECK`, `OP_SUCCESS`, `OP_FAILED`, `NOTIFICATION`, `SYNC_PERIPHERALS`, `PERIPHERAL_DATA`. See `docs/blue-switch-spec.md` for full spec.
