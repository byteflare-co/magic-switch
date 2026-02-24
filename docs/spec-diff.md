# Blue Switch vs Magic Switch 仕様差分レポート

> 作成日: 2026-02-24
> Blue Switch: v1.0.0 (https://github.com/HoshimuraYuto/blue-switch)
> Magic Switch: 現在のソースコード (/Users/masahiro.nishikawa.001/dev/lab/magic-switch/Sources/)

---

## 1. Bluetooth 制御方式

| 項目 | Blue Switch | Magic Switch | 差分・修正必要性 |
|------|-------------|--------------|------------------|
| **メインフレームワーク** | IOBluetooth のみ | blueutil CLI ラッパー (`BlueUtilWrapper`) | **Critical**: Blue Switch は IOBluetooth API を直接使用。Magic Switch は外部 CLI ツール `blueutil` に依存。Blue Switch 仕様に合わせるなら IOBluetooth 直接使用に変更が必要 |
| **デバイス検出** | `IOBluetoothDevice.pairedDevices()` | `IOBluetoothAdapter.pairedDevices()` → `IOBluetoothDevice.pairedDevices()` | 同等。Magic Switch は IOBluetoothAdapter でラップしているが内部は同じ |
| **デバイス接続** | `IOBluetoothDevicePair.start()` + `IOBluetoothDevice.openConnection()` | `blueutil --pair` + `blueutil --connect` | **Critical**: Blue Switch は IOBluetooth API で直接ペアリング+接続。Magic Switch は blueutil CLI 経由 |
| **デバイス remove (unpair)** | `IOBluetoothDevice.perform(Selector(("remove")))` (private API) | `blueutil --unpair` | **Critical**: Blue Switch は private API `remove` セレクターを使用。Magic Switch は blueutil の `--unpair` を使用。動作は同等だが実装方式が異なる |
| **デバイス切断** | `IOBluetoothDevice.closeConnection()` | `blueutil --disconnect` | 実装方式が異なるが機能は同等 |
| **接続状態確認** | `IOBluetoothDevice.isConnected()` | `IOBluetoothAdapter.isConnected()` → `IOBluetoothDevice.isConnected()` | 同等 |
| **RSSI チェック** | `IOBluetoothDevice.rssi()` (127 = 範囲外) | なし | **Medium**: Magic Switch にはデバイスの電波範囲チェックがない |
| **Bluetooth 状態監視** | CoreBluetooth (`CBCentralManager`) | セットアップウィザードで `CBManager.authorization` を確認 | Magic Switch は常時監視ではなくウィザード時のみ確認 |
| **blueutil 依存** | **不使用** | バンドル内 or `/opt/homebrew/bin/blueutil` | **Critical**: Blue Switch は外部ツール依存ゼロ。Magic Switch は blueutil 必須 |

### 重要な技術的差分

Blue Switch の `remove` 操作:
```
btDevice.perform(Selector(("remove")))  // private API
```
→ デバイス情報を OS レベルで削除（unpair 相当）。App Store 配布不可。

Magic Switch の `unpair` 操作:
```
blueutil --unpair <address>  // CLI ツール経由
```
→ blueutil が内部的に IOBluetooth API を呼び出す。blueutil 自体がどの API を使っているかは blueutil の実装依存。

---

## 2. ネットワーク通信

| 項目 | Blue Switch | Magic Switch | 差分・修正必要性 |
|------|-------------|--------------|------------------|
| **TCP 通信** | `NWConnection` / `NWListener` | `NWConnection` / `NWListener` + `NWProtocolFramer` (カスタムプロトコル) | Magic Switch はフレーミングプロトコル付き。Blue Switch は素の TCP |
| **Bonjour 検出** | `NetService` / `NetServiceBrowser` (Foundation) | `NWBrowser` (Network.framework) | **High**: API が異なる。Blue Switch は旧 API (`NetService`)、Magic Switch は新 API (`NWBrowser`)。Magic Switch の方が新しい API で適切 |
| **サービスタイプ** | `_blueswitch._tcp.` | `_magicswitch._tcp` | **Critical**: サービスタイプが異なるため相互通信不可。Blue Switch 仕様に合わせるなら `_blueswitch._tcp.` に変更必要 |
| **サービス名** | `Host.current().localizedName` | `MagicSwitch-<hostName>` | **High**: サービス名の形式が異なる |
| **コマンド体系** | テキストベース (`HEALTH_CHECK`, `CONNECT_ALL`, `UNREGISTER_ALL` 等) | JSON エンコード + バイナリフレーミング (`SwitchCommand` 構造体) | **Critical**: コマンドプロトコルが完全に異なるため相互通信不可 |
| **コマンド一覧** | `HEALTH_CHECK`, `UNREGISTER_ALL`, `CONNECT_ALL`, `OP_SUCCESS`, `OP_FAILED`, `NOTIFICATION`, `SYNC_PERIPHERALS`, `PERIPHERAL_DATA` | `switchRequest`, `switchAck`, `deviceReleased`, `switchResult`, `pairRequest`, `pairChallenge`, `pairResponse`, `pairConfirm`, `heartbeat`, `statusQuery`, `statusResponse` | **Critical**: コマンドセットが完全に異なる |
| **ヘルスチェック** | `NWConnection` で TCP 接続テスト (5秒タイムアウト) | `isPeerOnline()` でピア接続確認 | 方式が異なるが目的は同等 |
| **TLS 暗号化** | なし | あり (TLS 1.3 + TOFU 証明書検証) | Magic Switch の方がセキュア。Blue Switch にはなし |
| **ハートビート** | なし | あり (30秒間隔) | Magic Switch 独自機能 |
| **ペアリングプロトコル** | なし (ネットワークレベルのペアリング) | あり (`pairRequest`/`pairChallenge`/`pairResponse`/`pairConfirm`) | Magic Switch 独自機能 |
| **TXT レコード** | なし | `version`, `hostId`, `hostName` | Magic Switch はメタデータ付き |

---

## 3. メニューバー UI

| 項目 | Blue Switch | Magic Switch | 差分・修正必要性 |
|------|-------------|--------------|------------------|
| **左クリック動作** | デバイス切り替えを即座に実行 | メニューを表示（メニューから切り替え先を選択） | **High**: Blue Switch は左クリックで直接切り替え。Magic Switch はメニューから選択する方式 |
| **右クリック動作** | コンテキストメニューを表示 | なし（左クリックのみ） | **High**: Blue Switch は左右クリックで動作を分離 |
| **メニュー構成** | 1. 接続済み Mac 名一覧, 2. BT ペリフェラル名一覧, 3. Settings, 4. Quit | 1. 接続済みデバイス情報, 2. 切り替え先ホスト一覧, 3. 設定, 4. 終了 | 構成は類似しているがレイアウトが異なる |
| **アイコン** | ステータスバーアイコン (xcassets) | SF Symbols (`keyboard`) | 実装方式は異なるが機能は同等 |
| **切り替え中アイコン** | 不明 | `keyboard.badge.ellipsis` に変化 | Magic Switch 独自機能 |

---

## 4. 切り替えロジック

| 項目 | Blue Switch | Magic Switch | 差分・修正必要性 |
|------|-------------|--------------|------------------|
| **トリガー** | メニューバー左クリック | メニューから切り替え先を選択 or キーボードショートカット | Magic Switch はより多くのトリガー方式 |
| **接続状態判定** | `checkActualConnectionStatus()` → allConnected / allDisconnected / partial の3状態 | 状態分岐なし。接続中デバイスをフィルタして一括切り替え | **High**: Blue Switch は接続状態で動作を分岐。Magic Switch は常に同じフロー |
| **allConnected 時** | ローカル remove → ポーリング確認(5回×0.5秒) → 相手に CONNECT_ALL | unpair → 1秒待機 → 相手に switchRequest | フローは類似だが詳細が異なる |
| **allDisconnected 時** | 相手に UNREGISTER_ALL → ローカルでペアリング+接続 | （対応する動作なし） | **High**: Blue Switch は切断中デバイスの「こちらに引き込む」操作が可能。Magic Switch にはない |
| **partial 時** | 警告通知を表示 | （状態チェックなし） | **Medium**: Blue Switch は partial 状態でエラー通知。Magic Switch は接続中デバイスのみ切り替え |
| **切断確認** | ポーリング (最大5回 × 0.5秒) | 1秒固定待機 | 実装方式が異なる |
| **リトライ** | なし（ポーリングのみ） | エクスポネンシャルバックオフリトライ (最大3回) | Magic Switch の方がロバスト |
| **タイムアウト** | ヘルスチェック: 5秒 | SwitchResult 待機: 15秒 (設定可能) | Magic Switch は設定可能 |

---

## 5. 設定画面

| 項目 | Blue Switch | Magic Switch | 差分・修正必要性 |
|------|-------------|--------------|------------------|
| **タブ構成** | Peripheral, Device, Other | 一般, デバイス, 接続先, ショートカット, 情報 | **Medium**: タブ構成が異なる |
| **Peripheral/デバイスタブ** | 登録済み BT デバイス一覧 + 利用可能デバイス一覧。接続/切断/追加/削除操作 | 検出済みデバイス一覧（自動検出、操作なし） | **High**: Blue Switch はユーザーが手動でデバイスを追加・削除。Magic Switch は自動検出のみ |
| **Device/接続先タブ** | 接続済み Mac 一覧 + 利用可能 Mac 一覧。通知送信・同期ボタン。接続/削除 | 登録済み Mac 一覧 + ネットワーク上の Mac 一覧。追加/削除 | 機能は類似 |
| **Other/情報タブ** | ライセンス情報リンク (GitHub LICENSE) | アプリ情報（バージョン、説明） | 差分小 |
| **General/一般タブ** | 存在するが SettingsView に組み込まれていない (未使用) | 自動起動、通知、バッテリー閾値、ログレベル | Magic Switch は一般設定が充実 |
| **ショートカットタブ** | なし | あり（ホスト1-3への切り替えショートカット設定） | Magic Switch 独自機能 |
| **Mac 登録上限** | 1台 | 3台 | **Medium**: Blue Switch は1台のみ |

---

## 6. データ管理

| 項目 | Blue Switch | Magic Switch | 差分・修正必要性 |
|------|-------------|--------------|------------------|
| **保存方式** | `@AppStorage` (UserDefaults) | `ConfigStore` (JSON ファイル, `~/Library/Application Support/MagicSwitch/`) | **High**: 保存方式が完全に異なる |
| **デバイス保存** | `peripherals` キー → `[BluetoothPeripheral]` JSON | 保存なし（毎回自動検出） | **High**: Blue Switch はユーザーが選択したデバイスを永続化。Magic Switch は自動検出に依存 |
| **ホスト保存** | `networkDevices` キー → `[NetworkDevice]` JSON | `hosts.json` → `[HostMac]` JSON | 方式は異なるがデータ構造は類似 |
| **設定保存** | `autoLaunch`, `notificationsEnabled`, `autoUpdate` (全て未使用) | `config.json` → `AppConfig` | Magic Switch の方が設定が充実 |

---

## 7. デバイス識別

| 項目 | Blue Switch | Magic Switch | 差分・修正必要性 |
|------|-------------|--------------|------------------|
| **識別方法** | 特別な識別なし。ユーザーがペアリング済みデバイス一覧から手動選択 | VendorID (0x004C) / ProductID + 名前パターン (`Magic Keyboard`, `Magic Trackpad`) で自動識別 | **Medium**: Magic Switch の方が自動化されている。Blue Switch は全 BT デバイスを対象にユーザー選択 |
| **デバイス ID** | MAC アドレス (`addressString`) | UUID (自動生成) + MAC アドレス (`address`) | Magic Switch は UUID と MAC アドレスの両方を保持 |
| **対応デバイスタイプ** | 全 Bluetooth デバイス (制限なし) | Magic Keyboard, Magic Trackpad のみ | **Medium**: Blue Switch は Magic Mouse 等も対象可能。Magic Switch は Keyboard/Trackpad 限定 |
| **Magic Mouse 対応** | ユーザーが追加すれば対応可能 | 未対応（MagicDeviceIdentifier に含まれない） | **Low**: 必要に応じて追加可能 |

---

## 8. 依存ライブラリ

| 項目 | Blue Switch | Magic Switch | 差分・修正必要性 |
|------|-------------|--------------|------------------|
| **外部ライブラリ** | **なし** (依存ゼロ) | swift-log (`Logging`), `KeyboardShortcuts`, `LaunchAtLogin-Modern` | **High**: Blue Switch は依存ゼロ方針。Magic Switch は3つの外部ライブラリに依存 |
| **外部ツール** | なし | `blueutil` (CLI ツール、バンドル or Homebrew) | **Critical**: blueutil への依存は配布時の大きな課題 |
| **ビルドシステム** | Xcode `.xcodeproj` (SPM 未使用) | Swift Package Manager (SPM) | ビルドシステムが異なる |

---

## 9. 配布方式

| 項目 | Blue Switch | Magic Switch | 差分・修正必要性 |
|------|-------------|--------------|------------------|
| **配布形態** | GitHub Releases (zip) | Homebrew Cask (想定) | **Medium**: 配布チャネルが異なる |
| **コード署名** | なし | 不明 | — |
| **公証 (Notarization)** | なし | 不明 | — |
| **CI/CD** | GitHub Actions (semantic-release) | 不明 | — |
| **最小 macOS** | macOS 11.5 (Big Sur) | 不明 (Swift Concurrency 使用のため macOS 12+ が必要と推定) | — |

---

## 10. その他の機能差分

| 項目 | Blue Switch | Magic Switch | 差分・修正必要性 |
|------|-------------|--------------|------------------|
| **バッテリー表示** | なし | あり (`BatteryMonitor` + IORegistry 経由) | Magic Switch 独自機能（追加価値） |
| **バッテリー低下通知** | なし | あり (閾値設定可能、デフォルト 20%) | Magic Switch 独自機能 |
| **グローバルショートカット** | なし | あり (`KeyboardShortcuts` ライブラリ、ホスト1-3) | Magic Switch 独自機能 |
| **セットアップウィザード** | なし (README で手順説明) | あり (4ステップ: 権限→デバイス選択→ホスト登録→完了) | Magic Switch 独自機能 |
| **ログインアイテム** | General 設定に UI はあるが未使用 | `AppConfig.launchAtLogin` で設定可能 | Magic Switch は実装済み |
| **通知機能** | UserNotifications + TCP 経由リモート通知 | UserNotifications (ローカル通知のみ) | **Low**: Blue Switch はリモート通知可能。Magic Switch はローカルのみ |
| **デバイス同期** | `SYNC_PERIPHERALS` / `PERIPHERAL_DATA` コマンドでデバイスリストを Mac 間で同期 | なし | **Medium**: Blue Switch はデバイスリストの Mac 間同期機能あり |
| **TLS 暗号化** | なし | あり (TLS 1.3 + TOFU) | Magic Switch の方がセキュア |
| **Accessibility 権限** | 不要 | セットアップで確認 | Magic Switch はキーボードショートカットのために必要 |
| **App Sandbox** | あり | なし（blueutil 実行のため Sandbox 不可と推定） | **High**: Blue Switch は Sandbox 対応。Magic Switch は blueutil 実行のため非 Sandbox の可能性 |

---

## 修正が必要な項目一覧

### Critical (相互通信互換性に影響)

| # | 項目 | 内容 | 影響 |
|---|------|------|------|
| C1 | **Bluetooth 制御方式の変更** | blueutil CLI → IOBluetooth 直接使用に変更。`IOBluetoothDevice.perform(Selector(("remove")))` の採用が必要 | BlueUtilWrapper の全面書き換え。blueutil 依存の排除 |
| C2 | **サービスタイプの変更** | `_magicswitch._tcp` → `_blueswitch._tcp.` に変更 | PeerBrowser, PeerListener, NetworkManager の serviceType 定数変更 |
| C3 | **通信プロトコルの変更** | JSON+バイナリフレーミング → テキストベースコマンドに変更 | MessageProtocol, SwitchCommand, MessageEncoder の全面書き換え |
| C4 | **コマンド体系の変更** | 現行 11 コマンド → Blue Switch の 8 コマンド体系に合わせる | SwitchCommand, MessageType の全面変更 |

### High (機能・UX に大きな影響)

| # | 項目 | 内容 | 影響 |
|---|------|------|------|
| H1 | **メニューバー操作方式** | 左クリック=切り替え、右クリック=メニュー方式への変更 | MenuBarController の大幅変更。NSEvent 監視の追加 |
| H2 | **接続状態による動作分岐** | allConnected/allDisconnected/partial の3状態分岐を実装 | SwitchService に状態判定ロジックの追加 |
| H3 | **allDisconnected 時の引き込み操作** | 切断中デバイスを自分に接続する操作の実装 | SwitchService に逆方向切り替えフローの追加 |
| H4 | **Bonjour API の選択** | Blue Switch は旧 `NetService` API。Magic Switch は新 `NWBrowser` API | Magic Switch の方が新しい API で適切。変更不要だが互換性に注意 |
| H5 | **データ保存方式** | Blue Switch は `@AppStorage` (UserDefaults)。Magic Switch は JSON ファイル | Blue Switch 仕様に合わせるなら UserDefaults に変更。ただし JSON の方が柔軟 |
| H6 | **デバイス手動選択** | Blue Switch はユーザーが手動でデバイスを選択・登録。Magic Switch は自動検出のみ | 設定画面にデバイス追加/削除 UI の追加が必要 |
| H7 | **外部ライブラリ依存** | Blue Switch は依存ゼロ。Magic Switch は swift-log, KeyboardShortcuts 等に依存 | 依存ゼロにするには独自ロギング+ショートカット実装が必要 |
| H8 | **App Sandbox 対応** | Blue Switch は Sandbox 対応。Magic Switch は blueutil のため非 Sandbox の可能性 | C1 (IOBluetooth 直接使用) 解決後に Sandbox 対応可能 |

### Medium (機能改善・互換性向上)

| # | 項目 | 内容 | 影響 |
|---|------|------|------|
| M1 | **RSSI チェック** | デバイス接続前に電波強度を確認する機能の追加 | IOBluetooth API で取得可能 |
| M2 | **partial 状態の処理** | 一部デバイスのみ接続中の場合の警告通知 | SwitchService に状態チェック追加 |
| M3 | **Mac 登録上限** | Blue Switch は1台、Magic Switch は3台 | 仕様確認が必要。3台対応は Magic Switch の優位点 |
| M4 | **デバイス同期機能** | Blue Switch はデバイスリストの Mac 間同期が可能 | SYNC_PERIPHERALS/PERIPHERAL_DATA コマンドの実装 |
| M5 | **設定タブ構成** | Blue Switch と Magic Switch でタブ構成が異なる | UI リファクタリング |
| M6 | **Magic Mouse 対応** | MagicDeviceIdentifier に Magic Mouse の ProductID を追加 | 小規模な変更 |

### Low (優先度低・オプション)

| # | 項目 | 内容 | 影響 |
|---|------|------|------|
| L1 | **リモート通知** | Blue Switch は TCP 経由でリモート通知を送信可能 | NOTIFICATION コマンドの実装 |
| L2 | **サービス名形式** | `MagicSwitch-<name>` → Mac のコンピュータ名に変更 | PeerListener の修正 |
| L3 | **配布方式** | Blue Switch は GitHub Releases、Magic Switch は Homebrew | 両方式の併用が理想 |

---

## まとめ

### Blue Switch との相互通信を実現するために必須な変更
1. **C2**: サービスタイプを `_blueswitch._tcp.` に変更
2. **C3/C4**: 通信プロトコルを Blue Switch のテキストベースコマンドに対応

### Blue Switch と同等の機能にするために必要な変更
3. **C1**: Bluetooth 制御を IOBluetooth 直接使用に変更（blueutil 依存排除）
4. **H1**: メニューバー操作を左クリック=切り替え方式に変更
5. **H2/H3**: 接続状態による動作分岐の実装

### Magic Switch が Blue Switch より優れている点（変更不要）
- バッテリー表示・低下通知
- キーボードショートカット対応
- セットアップウィザード
- TLS 暗号化通信
- ハートビートによる接続監視
- エクスポネンシャルバックオフリトライ
- 複数ホスト対応（最大3台）
- デバイス自動識別
