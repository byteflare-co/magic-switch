# CLAUDE.md

## Commands

```bash
make build / release / run / test / bundle / bundle-run / clean
```

Single test: `swift test --filter MagicSwitchCoreTests.ConfigStoreTests`

## Architecture

macOS menu bar app (Swift, macOS 13+, SPM). Two targets:
- **MagicSwitch** — UI (SwiftUI/AppKit), ViewModels (`@MainActor`)
- **MagicSwitchCore** — Business logic: Bluetooth, Network, Storage (all Swift Actors)

```
Views/MenuBarController → ViewModels → Services → Core (BluetoothManager, NetworkManager, ConfigStore)
```

DI via `DependencyContainer`. Protocol: text commands over TCP (`_magicswitch._tcp.`). See `docs/blue-switch-spec.md`.

## Deploy

「デプロイ」指示で以下を一連実行:

1. 未コミット変更をコミット & `git push`
2. `Resources/Info.plist` のバージョンをインクリメント（デフォルト: パッチ）、コミット & push
3. `git tag v{VERSION}` & `git push --tags`
4. `make bundle` でビルド
5. `gh release create v{VERSION}` で zip アップロード（リリースノート付き）
6. Homebrew tap 更新 — `byteflare-co/homebrew-tap` の `Casks/magic-switch.rb` を GitHub API で更新（version と sha256）
7. 既存プロセス終了 → `open .build/release/MagicSwitch.app`

リリースノート形式:
```
## v{VERSION}
### Changes
- 箇条書き
### Install / Update
brew tap byteflare-co/tap && brew install --cask magic-switch
```
