# Blue Switch 仕様書

> ソース: https://github.com/HoshimuraYuto/blue-switch
> 最新リリース: v1.0.0 (2024-12-01)
> ライセンス: GPL-3.0

---

## 1. プロジェクト概要

### アプリの目的
Blue Switch は macOS 向けのメニューバーアプリケーションで、**Magic Keyboard / Magic Trackpad / Magic Mouse** などの Bluetooth デバイスを **2台の Mac 間でワンクリックで切り替える** ことを目的としている。KVM スイッチやケーブル接続は不要で、完全ワイヤレス環境を実現する。

### ターゲットユーザー
- 2台の Mac（例: 業務用と個人用）を1セットのキーボード/トラックパッドで使いたいユーザー

### 主な特徴
- ハードウェア不要（KVM スイッチ/ケーブル不要）
- 完全ワイヤレスでデバイスを即座に切り替え
- メニューバーアイコンのクリックだけで操作可能
- 2台の Mac 間で双方向に切り替え可能

---

## 2. 技術スタック

| 項目 | 詳細 |
|------|------|
| **言語** | Swift 5.0 (Swift 6.0.2 以降での開発推奨) |
| **UI フレームワーク** | SwiftUI + AppKit (NSStatusItem, NSMenu, NSWindow 等のハイブリッド) |
| **ビルドシステム** | Xcode 16.1 以降 / `.xcodeproj` ベース (SPM 未使用) |
| **最小対応 macOS** | macOS 11.5 (Big Sur) |
| **バンドル ID** | `com.star-village.blue-switch` |
| **依存ライブラリ** | なし（外部ライブラリ依存ゼロ） |

### 使用フレームワーク (Apple SDK)
- `IOBluetooth` — Bluetooth デバイスのペアリング/接続/切断/デバイス情報取得
- `CoreBluetooth` — Bluetooth 状態監視 (`CBCentralManager`)
- `Network` (`NWConnection`, `NWListener`) — Mac 間の TCP 通信
- `Foundation` (`NetService`, `NetServiceBrowser`) — Bonjour によるサービス発見
- `UserNotifications` — macOS 通知
- `SwiftUI` / `AppKit` — UI

---

## 3. アーキテクチャ

### ディレクトリ構成

```
Blue Switch/
├── AppDelegate/
│   ├── AppDelegate.swift          # アプリのライフサイクル管理、メニューバー、左クリック切替ロジック
│   └── Blue_SwitchApp.swift       # @main エントリポイント
├── Assets.xcassets/               # アイコン、ステータスバーアイコン
├── Blue_Switch.entitlements       # サンドボックス & Bluetooth/ネットワーク権限
├── ContentView.swift              # 未使用のプレースホルダ
├── Extensions/
│   ├── IOBluetoothDevice+Extension.swift  # IOBluetoothDevice → BluetoothPeripheral 変換
│   └── NetworkDevice+HealthCheck.swift    # ヘルスチェック機能
├── Manager/
│   ├── BluetoothManager.swift     # CoreBluetooth による状態監視
│   ├── ConnectionManager.swift    # TCP 通信管理 (メッセージ送受信、コマンドハンドリング)
│   ├── NotificationManager.swift  # macOS 通知管理
│   ├── ServiceBrowser.swift       # Bonjour サービス発見 (他の Mac を探す)
│   └── ServicePublisher.swift     # Bonjour サービス公開 (自分を公開する)
├── Model/
│   ├── Entity/
│   │   ├── BluetoothPeripheral.swift  # Bluetooth デバイスモデル
│   │   └── NetworkDevice.swift        # ネットワーク上の Mac モデル
│   └── Store/
│       ├── BluetoothPeripheralStore.swift  # Bluetooth デバイスの状態管理・操作
│       └── NetworkDeviceStore.swift        # ネットワークデバイスの状態管理・操作
├── Preview Content/
└── View/
    ├── MenuBar/
    │   └── MenuBarView.swift              # 右クリックメニュー構成
    └── Settings/
        ├── SettingsView.swift             # 設定画面のタブ管理
        ├── BluetoothPeripheralSettingsView.swift  # Peripheral タブ
        ├── GeneralSettingsView.swift      # General タブ (実際にはタブに含まれていない)
        ├── NetworkDeviceManagementView.swift       # Device タブ
        └── OtherSettingsView.swift        # Other タブ (ライセンス情報)
```

### 設計パターン
- **Singleton + ObservableObject**: `BluetoothPeripheralStore.shared`, `NetworkDeviceStore.shared`, `BluetoothManager.shared` がシングルトンとして状態を管理
- **Protocol-oriented**: 各マネージャーにプロトコルインターフェースを定義 (`BluetoothManaging`, `NetworkConnectionManaging`, `NotificationManaging`, `ServiceBrowsing`, `NetworkNetworkServicePublishable`, `BluetoothPeripheralManageable`, `NetworkDeviceManageable`)
- **Entity-Store**: Model 層を Entity (データモデル) と Store (状態管理+操作) に分離
- **AppDelegate ベース**: SwiftUI App ライフサイクルを使いつつ、`NSApplicationDelegateAdaptor` で AppKit の AppDelegate に委譲

---

## 4. 機能一覧

### 4.1 Bluetooth デバイス管理

| 機能 | 実装方法 |
|------|----------|
| **ペアリング済みデバイスの検出** | `IOBluetoothDevice.pairedDevices()` で全ペアリング済みデバイスを列挙 |
| **デバイスの接続** | `IOBluetoothDevicePair.start()` + `IOBluetoothDevice.openConnection()` |
| **デバイスの切断 (remove)** | `IOBluetoothDevice.perform(Selector(("remove")))` — private API を使用してデバイス情報を削除（unpair相当） |
| **デバイスの切断 (disconnect)** | `IOBluetoothDevice.closeConnection()` |
| **接続状態の確認** | `IOBluetoothDevice.isConnected()` |
| **RSSI (電波強度) チェック** | `IOBluetoothDevice.rssi()` — 値が 127 なら範囲外と判定 |
| **デバイスの識別** | MAC アドレス (`addressString`) をユニーク ID として使用 |

### 4.2 デバイス切り替えロジック（左クリック時）

切り替えはメニューバーアイコンの **左クリック** で実行される。以下のフロー:

1. **接続先 Mac のヘルスチェック** (`NWConnection` で TCP 接続テスト、5秒タイムアウト)
2. **現在の接続状態を判定** (`checkActualConnectionStatus()`)
   - **全デバイス接続中 (allConnected)**:
     1. ローカルで全デバイスを `remove`（ペアリング解除相当）
     2. 切断完了を最大5回 × 0.5秒間隔でポーリング確認
     3. 相手 Mac に `CONNECT_ALL` コマンドを TCP 送信 → 相手側でペアリング+接続
   - **全デバイス切断中 (allDisconnected)**:
     1. 相手 Mac に `UNREGISTER_ALL` コマンドを TCP 送信 → 相手側でデバイスを remove
     2. ローカルで全デバイスをペアリング+接続
   - **一部接続中 (partial)**: 警告通知を表示

### 4.3 Mac 間通信

| 機能 | 詳細 |
|------|------|
| **プロトコル** | TCP (NWConnection / NWListener) |
| **サービス発見** | Bonjour (`NetService` / `NetServiceBrowser`) |
| **サービスタイプ** | `_blueswitch._tcp.` (ドメイン: `local.`) |
| **サービス名** | `Host.current().localizedName` (Mac のコンピュータ名) |
| **ポート** | 動的割り当て (`NWListener` が自動的にポートを選択) |
| **コマンド体系** | テキストベースの文字列コマンド |

#### コマンド一覧 (`DeviceCommand` enum)

| コマンド | 値 | 用途 |
|----------|----|------|
| `healthCheck` | `HEALTH_CHECK` | ヘルスチェック |
| `unregisterAll` | `UNREGISTER_ALL` | 全デバイスの remove 要求 |
| `connectAll` | `CONNECT_ALL` | 全デバイスの接続要求 |
| `operationSuccess` | `OP_SUCCESS` | 操作成功応答 |
| `operationFailed` | `OP_FAILED` | 操作失敗応答 |
| `notification` | `NOTIFICATION` | 通知送信 |
| `syncPeripherals` | `SYNC_PERIPHERALS` | デバイス情報同期 |
| `peripheralData` | `PERIPHERAL_DATA` | デバイスデータ送信 |

### 4.4 通知機能
- `UserNotifications` フレームワークを使用
- 切り替え失敗時にエラー通知を表示
- Mac 間でリモート通知を送信可能（TCP 経由でコマンド送信→受信側で `UNUserNotificationCenter` で表示）

### 4.5 メニューバー

| 操作 | 動作 |
|------|------|
| **左クリック** | デバイス切り替えを実行 |
| **右クリック** | コンテキストメニューを表示 |

#### 右クリックメニュー構成
1. 接続済みネットワークデバイス（Mac）名一覧
2. セパレータ
3. 登録済み Bluetooth ペリフェラル名一覧
4. セパレータ
5. "Settings..." (Cmd+,)
6. "Quit" (Cmd+Q)

### 4.6 設定画面

タブ構成:

| タブ | 内容 |
|------|------|
| **Peripheral** | 登録済み Bluetooth デバイス一覧、利用可能デバイス一覧、接続/切断/追加/削除操作 |
| **Device** | 接続済みネットワーク Mac 一覧、利用可能 Mac 一覧、通知送信、同期ボタン、接続/削除 |
| **Other** | ライセンス情報リンク（GitHub の LICENSE ファイルを開く） |

> 注意: `GeneralSettingsView.swift` は存在するが、`SettingsView` のタブには含まれていない（未使用）。

#### GeneralSettingsView（未使用）の設定項目
- `autoLaunch` — 起動時自動起動 (AppStorage)
- `notificationsEnabled` — 通知有効化 (AppStorage)
- `autoUpdate` — 自動更新 (AppStorage)

### 4.7 キーボードショートカット
- メニュー内のみ: Settings (Cmd+,), Quit (Cmd+Q)
- グローバルショートカット: なし

### 4.8 バッテリー表示
- なし

---

## 5. Bluetooth 制御方式の詳細

### 使用フレームワーク

| フレームワーク | 用途 |
|----------------|------|
| **IOBluetooth** | メインの Bluetooth 操作 (ペアリング、接続、切断、デバイス列挙) |
| **CoreBluetooth** | Bluetooth の電源状態監視のみ (`CBCentralManager`) |
| **blueutil** | 不使用 |

### デバイス操作の実装詳細

#### ペアリング + 接続 (`connectPeripheral`)
```
1. IOBluetoothDevice(addressString:) でデバイスオブジェクト取得
2. Bluetooth 電源状態チェック (IOBluetoothHostController.default().powerState)
3. RSSI 値チェック (127 = 範囲外)
4. IOBluetoothDevicePair(device:).start() でペアリング開始
5. IOBluetoothDevice.openConnection() で接続
```

#### デバイス登録解除 (`unregisterFromPC`) — 切り替え時に使用
```
1. btDevice.isConnected() で接続確認
2. btDevice.perform(Selector(("remove"))) で private API を使用してデバイス情報を削除
   → これにより相手 Mac がペアリング+接続可能になる
```

#### 通常切断 (`disconnectPeripheral`)
```
1. IOBluetoothDevice.closeConnection() で切断
```

### Magic Keyboard / Trackpad の識別方法
- 特別な識別はしていない
- ユーザーがペアリング済みデバイスの一覧から手動で選択・登録する方式
- `IOBluetoothDevice.pairedDevices()` で全ペアリング済みデバイスを列挙し、ユーザーが設定画面で選択

---

## 6. データ管理

### 保存方法
- **`@AppStorage`** (UserDefaults ラッパー) を使用

### 保存データ

| キー | 型 | 内容 |
|------|----|----|
| `peripherals` | `Data` (JSON) | 登録済み Bluetooth デバイスの配列 (`[BluetoothPeripheral]`) |
| `networkDevices` | `Data` (JSON) | 登録済みネットワーク Mac の配列 (`[NetworkDevice]`) |
| `autoLaunch` | `Bool` | 起動時自動起動（未使用設定） |
| `notificationsEnabled` | `Bool` | 通知有効化（未使用設定） |
| `autoUpdate` | `Bool` | 自動更新（未使用設定） |

### モデル構造

#### BluetoothPeripheral
```swift
struct BluetoothPeripheral: Identifiable, Codable {
    let id: String       // MAC アドレス
    var name: String     // デバイス名
    var isConnected: Bool // 計算プロパティ (IOBluetoothDevice.isConnected())
}
```

#### NetworkDevice
```swift
struct NetworkDevice: Identifiable, Codable {
    let id: String       // デバイス名 (Bonjour サービス名)
    var name: String     // 表示名
    var host: String     // ホスト名/IPアドレス
    var port: Int        // 通信ポート番号
    var lastUpdated: Date
    var isActive: Bool   // アクティブ状態
}
```

---

## 7. 配布方式

| 項目 | 詳細 |
|------|------|
| **配布形態** | GitHub Releases に zip ファイル (`app.zip`) として公開 |
| **ビルド方法** | Xcode (`xcodebuild clean archive`) |
| **パッケージ方法** | `ditto` コマンドで .app を zip 化 |
| **バージョニング** | semantic-release (Angular Commit Convention) |
| **CI/CD** | GitHub Actions (push to main でリリース) |
| **コード署名** | なし（リリースワークフローに署名ステップがない） |
| **公証 (Notarization)** | なし |
| **Homebrew 対応** | なし |
| **DMG / pkg** | なし |

---

## 8. Entitlements (権限)

```xml
com.apple.security.app-sandbox        = true   <!-- App Sandbox 有効 -->
com.apple.security.device.bluetooth   = true   <!-- Bluetooth アクセス -->
com.apple.security.network.client     = true   <!-- ネットワーク送信 -->
com.apple.security.network.server     = true   <!-- ネットワーク受信 -->
```

### Info.plist 設定
- `NSBluetoothAlwaysUsageDescription`: "Bluetooth is required to connect with nearby devices"
- `NSLocalNetworkUsageDescription`: "Local network access is needed to discover devices"

---

## 9. ソースファイル一覧

| ファイル | サイズ | 役割 |
|----------|--------|------|
| `AppDelegate/AppDelegate.swift` | 6,448 B | アプリライフサイクル、ステータスバー設定、左クリック切り替えロジック |
| `AppDelegate/Blue_SwitchApp.swift` | 338 B | @main エントリポイント |
| `ContentView.swift` | 232 B | 未使用プレースホルダ |
| `Extensions/IOBluetoothDevice+Extension.swift` | 528 B | IOBluetoothDevice → BluetoothPeripheral 変換 |
| `Extensions/NetworkDevice+HealthCheck.swift` | 1,358 B | TCP ヘルスチェック (5秒タイムアウト) |
| `Manager/BluetoothManager.swift` | 1,549 B | CoreBluetooth 状態監視 |
| `Manager/ConnectionManager.swift` | 9,279 B | TCP 通信管理、コマンドハンドリング、ペリフェラル同期 |
| `Manager/NotificationManager.swift` | 2,401 B | macOS 通知管理 |
| `Manager/ServiceBrowser.swift` | 3,180 B | Bonjour サービス発見 |
| `Manager/ServicePublisher.swift` | 3,189 B | Bonjour サービス公開 |
| `Model/Entity/BluetoothPeripheral.swift` | 564 B | Bluetooth デバイスモデル |
| `Model/Entity/NetworkDevice.swift` | 1,476 B | ネットワークデバイスモデル |
| `Model/Store/BluetoothPeripheralStore.swift` | 10,883 B | Bluetooth デバイス状態管理・操作 (接続/切断/remove/ペアリング) |
| `Model/Store/NetworkDeviceStore.swift` | 7,683 B | ネットワークデバイス管理・コマンド実行 |
| `View/MenuBar/MenuBarView.swift` | 2,263 B | 右クリックメニュー構成 |
| `View/Settings/SettingsView.swift` | 1,253 B | 設定画面タブ管理 |
| `View/Settings/BluetoothPeripheralSettingsView.swift` | 4,731 B | Peripheral 設定タブ |
| `View/Settings/GeneralSettingsView.swift` | 1,116 B | General 設定（未使用タブ） |
| `View/Settings/NetworkDeviceManagementView.swift` | 5,104 B | Device 設定タブ |
| `View/Settings/OtherSettingsView.swift` | 1,387 B | Other 設定タブ（ライセンス情報） |

**合計ソースファイル数**: 20 ファイル
**合計ソースコードサイズ**: 約 64,962 bytes

---

## 10. 主要な型・クラス一覧

### Entity
| 型 | 種別 | 説明 |
|----|------|------|
| `BluetoothPeripheral` | struct | Bluetooth デバイスモデル (id=MACアドレス, name, isConnected) |
| `NetworkDevice` | struct | ネットワーク Mac モデル (id, name, host, port, lastUpdated, isActive) |

### Store (状態管理)
| 型 | 種別 | 説明 |
|----|------|------|
| `BluetoothPeripheralStore` | class (ObservableObject, Singleton) | Bluetooth デバイスの CRUD + 接続/切断/remove |
| `NetworkDeviceStore` | class (ObservableObject, Singleton) | ネットワーク Mac の CRUD + コマンド実行 |

### Manager
| 型 | 種別 | 説明 |
|----|------|------|
| `BluetoothManager` | class (Singleton) | CoreBluetooth 状態監視 |
| `ConnectionManager` | class | TCP 接続・メッセージ送受信・コマンド処理 |
| `NotificationManager` | class | macOS 通知の送信・権限管理 |
| `ServiceBrowser` | class | Bonjour サービス発見 |
| `ServicePublisher` | class | Bonjour サービス公開 |

### Enum
| 型 | 説明 |
|----|------|
| `DeviceCommand` | TCP コマンド定義 (HEALTH_CHECK, CONNECT_ALL, UNREGISTER_ALL 等) |
| `ConnectionStatus` | 接続状態 (allConnected, allDisconnected, partial) |
| `HealthCheckResult` | ヘルスチェック結果 (success, failure, timeout) |
| `ConnectionError` | 接続エラー (sendFailed, receiveFailed, connectionFailed) |

### Protocol
| プロトコル | 実装クラス |
|------------|------------|
| `BluetoothManaging` | `BluetoothManager` |
| `NetworkConnectionManaging` | `ConnectionManager` |
| `NotificationManaging` | `NotificationManager` |
| `ServiceBrowsing` | `ServiceBrowser` |
| `NetworkNetworkServicePublishable` | `ServicePublisher` |
| `BluetoothPeripheralManageable` | `BluetoothPeripheralStore` |
| `NetworkDeviceManageable` | `NetworkDeviceStore` |
| `HealthCheckable` | `NetworkDevice` |
| `MenuBarPresentable` | `MenuBarView` |

### View
| 型 | 説明 |
|----|------|
| `Blue_SwitchApp` | @main エントリポイント |
| `ContentView` | 未使用 |
| `SettingsView` | 設定画面(タブ) |
| `BluetoothPeripheralSettingsView` | Peripheral タブ |
| `GeneralSettingsView` | General タブ(未使用) |
| `NetworkDeviceManagementView` | Device タブ |
| `OtherSettingsView` | Other タブ |
| `MenuBarView` | 右クリックメニュー (NSMenu ベース) |

---

## 11. 制約事項・注意点

1. **Private API の使用**: `IOBluetoothDevice.perform(Selector(("remove")))` は Apple の非公開 API。App Store での配布は不可能。
2. **接続台数制限**: ネットワークデバイス（Mac）は UI 上で1台のみ接続可能（2台目を登録しようとするとメッセージ表示）
3. **コード署名なし**: GitHub Releases の zip には署名がないため、初回起動時に Gatekeeper の警告が表示される
4. **セットアップウィザード**: なし（README で手順を説明）
5. **自動起動**: GeneralSettingsView に UI はあるが、SettingsView に組み込まれていない（未使用）
6. **バッテリー表示**: 非対応
7. **グローバルショートカット**: 非対応
