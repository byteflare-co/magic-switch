# Magic Switch - ソフトウェア設計書

## 改訂履歴

| 日付 | バージョン | 変更内容 |
|------|-----------|---------|
| 2026-02-23 | 1.0 | 初版作成 |

---

## 1. 技術選定

### 1.1 プログラミング言語: Swift 5.9+

| 項目 | 詳細 |
|------|------|
| 言語 | Swift 5.9 以降 |
| 選定理由 | macOS ネイティブアプリ開発の第一選択肢。IOBluetooth / Network.framework 等の Apple フレームワークとシームレスに統合でき、型安全性・パフォーマンス・メモリ安全性に優れる。Swift Concurrency（async/await, Actor）により非同期処理を安全かつ簡潔に記述できる |

### 1.2 UI フレームワーク: AppKit + SwiftUI（ハイブリッド）

#### 比較検討

| 観点 | SwiftUI | AppKit | 選定方針 |
|------|---------|--------|---------|
| メニューバーアプリ | `MenuBarExtra`（macOS 13+）で実現可能 | `NSStatusItem` で実績豊富 | **AppKit**（`NSStatusItem`） |
| 設定画面 | 宣言的UIで高速開発 | 手続き的UIだが柔軟 | **SwiftUI**（`Settings` シーン） |
| セットアップウィザード | ナビゲーション管理が容易 | `NSTabView` 等で実装 | **SwiftUI** |
| macOS 13 サポート | `MenuBarExtra` は macOS 13+ だが制約あり | 全バージョン安定 | AppKit でメニューバー制御 |

**結論**: メニューバー制御は `NSStatusItem`（AppKit）を使用し、設定画面・ウィザード等のウィンドウUIは SwiftUI で構築するハイブリッド構成とする。AppKit の安定したメニューバー制御と SwiftUI の宣言的UI開発の利点を両取りする。

### 1.3 Bluetooth 制御: IOBluetooth + blueutil

| コンポーネント | 役割 |
|--------------|------|
| `IOBluetooth.framework` | デバイス検出、接続状態の監視、バッテリー残量取得、デバイス情報（MACアドレス、名前等）の取得 |
| `blueutil` CLI | ペアリング（pair）、アンペアリング（unpair）、接続（connect）、切断（disconnect）の実行。IOBluetooth の公開 API ではペアリング/アンペアリングの信頼性が低いため、実績のある blueutil を併用する |

**blueutil の管理方針**:
- アプリケーションバンドル内に blueutil バイナリを同梱する（`MagicSwitch.app/Contents/Resources/blueutil`）
- Homebrew の `blueutil` に依存せず、自己完結型とする
- blueutil のバージョンを固定し、macOS アップデートへの追従をコントロール可能にする

### 1.4 ネットワーク通信: Network.framework + Bonjour

| コンポーネント | 役割 |
|--------------|------|
| `Network.framework` (`NWListener` / `NWConnection`) | Mac 間の TCP 通信。TLS 1.3 による暗号化を標準サポート |
| `NWBrowser` / `NWListener` (Bonjour) | ローカルネットワーク上の Magic Switch インスタンスの自動検出 |

**選定理由**: `Network.framework` は Apple が提供する最新のネットワーキングフレームワークであり、TLS 1.3 暗号化をネイティブサポートする。`MultipeerConnectivity` は高レベルすぎて細かい制御が困難であり、通信プロトコルのカスタマイズ性に欠けるため不採用。

### 1.5 ビルドシステム: Swift Package Manager (SPM)

| 項目 | 詳細 |
|------|------|
| ビルドツール | Swift Package Manager |
| 選定理由 | Xcode に依存せずコマンドラインからビルド可能。CI/CD との親和性が高い。依存関係管理も SPM で統一 |
| Xcode との互換 | `Package.swift` を Xcode で直接開くことも可能。開発時は Xcode IDE を使用し、CI/CD では `swift build` を使用 |

### 1.6 依存ライブラリ

| ライブラリ | 用途 | バージョン | 備考 |
|-----------|------|-----------|------|
| `swift-log` | ロギング | 1.5+ | Apple 公式のロギング API。`os.Logger` のバックエンドとしても機能 |
| `swift-argument-parser` | CLI ヘルパー（将来） | 1.3+ | デバッグ用 CLI インターフェース |
| `KeyboardShortcuts` | グローバルショートカット | 2.0+ | sindresorhus/KeyboardShortcuts。macOS でのグローバルホットキー登録を簡潔に実現 |
| `LaunchAtLogin-Modern` | ログイン時自動起動 | — | sindresorhus/LaunchAtLogin-Modern。`SMAppService` のラッパー |

**注意**: 依存は最小限に抑え、Apple 標準フレームワークを最大限活用する方針とする。

---

## 2. アーキテクチャ設計

### 2.1 全体アーキテクチャ

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Magic Switch App                             │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │                    Presentation Layer                         │  │
│  │  ┌─────────────┐ ┌──────────────┐ ┌───────────────────────┐  │  │
│  │  │ MenuBarUI   │ │ SettingsView │ │ SetupWizardView       │  │  │
│  │  │ (AppKit)    │ │ (SwiftUI)    │ │ (SwiftUI)             │  │  │
│  │  └──────┬──────┘ └──────┬───────┘ └───────────┬───────────┘  │  │
│  └─────────┼───────────────┼─────────────────────┼──────────────┘  │
│            │               │                     │                  │
│  ┌─────────▼───────────────▼─────────────────────▼──────────────┐  │
│  │                    ViewModel Layer                            │  │
│  │  ┌──────────────┐ ┌───────────────┐ ┌─────────────────────┐  │  │
│  │  │ MenuBarVM    │ │ SettingsVM    │ │ SetupWizardVM       │  │  │
│  │  └──────┬───────┘ └───────┬───────┘ └──────────┬──────────┘  │  │
│  └─────────┼─────────────────┼────────────────────┼─────────────┘  │
│            │                 │                    │                  │
│  ┌─────────▼─────────────────▼────────────────────▼─────────────┐  │
│  │                     Service Layer                            │  │
│  │  ┌───────────────────┐  ┌───────────────────┐                │  │
│  │  │ SwitchService     │  │ DeviceDiscovery   │                │  │
│  │  │ (切り替えオーケ   │  │ Service           │                │  │
│  │  │  ストレーション)  │  │                   │                │  │
│  │  └────┬─────┬────────┘  └────────┬──────────┘                │  │
│  └───────┼─────┼────────────────────┼───────────────────────────┘  │
│          │     │                    │                                │
│  ┌───────▼─────▼────────────────────▼───────────────────────────┐  │
│  │                      Core Layer                              │  │
│  │  ┌──────────────────┐  ┌──────────────────┐                  │  │
│  │  │ BluetoothManager │  │ NetworkManager   │                  │  │
│  │  │                  │  │                  │                  │  │
│  │  │ ┌──────────────┐ │  │ ┌──────────────┐ │                  │  │
│  │  │ │IOBluetooth   │ │  │ │NWListener    │ │                  │  │
│  │  │ │Adapter       │ │  │ │(Server)      │ │                  │  │
│  │  │ └──────────────┘ │  │ └──────────────┘ │                  │  │
│  │  │ ┌──────────────┐ │  │ ┌──────────────┐ │                  │  │
│  │  │ │BlueUtil      │ │  │ │NWConnection  │ │                  │  │
│  │  │ │Wrapper       │ │  │ │(Client)      │ │                  │  │
│  │  │ └──────────────┘ │  │ └──────────────┘ │                  │  │
│  │  │ ┌──────────────┐ │  │ ┌──────────────┐ │                  │  │
│  │  │ │BatteryMonitor│ │  │ │NWBrowser     │ │                  │  │
│  │  │ └──────────────┘ │  │ │(Discovery)   │ │                  │  │
│  │  └──────────────────┘  │ └──────────────┘ │                  │  │
│  │                        └──────────────────┘                  │  │
│  │  ┌──────────────────┐  ┌──────────────────┐                  │  │
│  │  │ ConfigStore      │  │ Logger           │                  │  │
│  │  │ (設定永続化)      │  │ (ロギング)       │                  │  │
│  │  └──────────────────┘  └──────────────────┘                  │  │
│  └──────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

### 2.2 アーキテクチャパターン: MVVM + Service Layer

**選定理由**:
- **MVVM**: SwiftUI のデータバインディングと自然に統合される。`@Observable` / `@ObservableObject` により ViewModel の変更が自動的にViewに反映される
- **Service Layer**: ビジネスロジック（切り替えオーケストレーション）を ViewModel から分離し、テスタビリティと再利用性を確保する
- Clean Architecture ほど厳格なレイヤー分離は必要ない（小〜中規模アプリケーション）が、依存の方向を上位→下位に統一する

**依存関係の原則**:
```
Presentation → ViewModel → Service → Core
                                   → Storage
```
- 上位レイヤーは下位レイヤーに依存してよいが、逆は禁止
- Core / Storage レイヤーは protocol で抽象化し、テスト時にモックに差し替え可能にする

### 2.3 モジュール構成

| モジュール | 責務 | 主要な型 |
|-----------|------|---------|
| **App** | アプリケーションエントリポイント、DI コンテナ | `MagicSwitchApp`, `AppDelegate`, `DependencyContainer` |
| **Presentation** | UI コンポーネント（View） | `MenuBarController`, `SettingsView`, `SetupWizardView` |
| **ViewModel** | UIロジック、状態管理 | `MenuBarViewModel`, `SettingsViewModel`, `SetupWizardViewModel` |
| **Service** | ビジネスロジック | `SwitchService`, `DeviceDiscoveryService` |
| **Core/Bluetooth** | Bluetooth デバイス制御 | `BluetoothManager`, `IOBluetoothAdapter`, `BlueUtilWrapper`, `BatteryMonitor` |
| **Core/Network** | Mac 間ネットワーク通信 | `NetworkManager`, `PeerBrowser`, `PeerConnection`, `MessageProtocol` |
| **Storage** | 設定・データ永続化 | `ConfigStore`, `DeviceStore`, `HostStore` |
| **Common** | 共通ユーティリティ | `Logger`, `NotificationManager`, `ErrorTypes` |

### 2.4 Concurrency モデル

Swift Concurrency（Structured Concurrency + Actor）を全面採用する。

```swift
// BluetoothManager は Actor として実装し、スレッドセーフを保証
actor BluetoothManager {
    func discoverDevices() async throws -> [MagicDevice]
    func connect(device: MagicDevice) async throws
    func disconnect(device: MagicDevice) async throws
}

// NetworkManager も Actor
actor NetworkManager {
    func startListening() async throws
    func sendCommand(_ command: SwitchCommand, to peer: Peer) async throws
}
```

**理由**: IOBluetooth がスレッドセーフでない（TC-002）ため、Actor で直列化し安全性を確保する。ネットワーク通信も同様に Actor で保護する。

---

## 3. Bluetooth デバイス管理設計

### 3.1 デバイス検出フロー

```
┌──────────────┐     ┌───────────────────┐     ┌──────────────────┐
│ BluetoothMgr │────▶│ IOBluetoothAdapter│────▶│ IOBluetooth.fwk  │
│              │     │                   │     │                  │
│ discoverDev  │     │ queryPairedDevices│     │ IOBluetoothDevice│
│  ices()      │     │ filterMagicDevices│     │ .pairedDevices() │
└──────────────┘     └───────────────────┘     └──────────────────┘
```

#### IOBluetoothAdapter

```swift
protocol BluetoothAdapterProtocol: Sendable {
    func pairedDevices() async -> [IOBluetoothDevice]
    func deviceInfo(for address: BluetoothAddress) async -> DeviceInfo?
    func batteryLevel(for address: BluetoothAddress) async -> Int?
    func isConnected(_ address: BluetoothAddress) async -> Bool
}

final class IOBluetoothAdapter: BluetoothAdapterProtocol {
    /// ペアリング済みデバイスを取得
    func pairedDevices() async -> [IOBluetoothDevice] {
        // IOBluetoothDevice.pairedDevices() は同期 API
        // Actor 内で呼び出し、スレッド安全性を確保
        return IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] ?? []
    }
}
```

#### Magic デバイスの識別方法

Magic Keyboard / Trackpad の識別は以下の条件を組み合わせて判定する:

```swift
struct MagicDeviceIdentifier {
    /// Apple の Bluetooth Vendor ID
    static let appleVendorID: UInt16 = 0x004C  // 76

    /// Magic デバイスの Product ID 範囲（世代ごとに異なる）
    /// 注: 新世代リリース時に更新が必要
    static let knownProductIDs: Set<UInt16> = [
        // Magic Keyboard
        0x0267, // Magic Keyboard (A1644)
        0x029C, // Magic Keyboard with Touch ID (A2449)
        0x029D, // Magic Keyboard with Touch ID and Numeric (A2450)
        0x0314, // Magic Keyboard USB-C (A2980)
        0x0315, // Magic Keyboard with Touch ID USB-C (A2981)
        0x0316, // Magic Keyboard with Touch ID and Numeric USB-C (A2982)
        // Magic Trackpad
        0x0265, // Magic Trackpad 2 (A1535)
        0x0324, // Magic Trackpad USB-C (A2842)
    ]

    /// デバイス名のプレフィックスでフォールバック判定
    static let namePatterns = [
        "Magic Keyboard",
        "Magic Trackpad",
    ]

    static func isMagicDevice(_ device: IOBluetoothDevice) -> Bool {
        // 1. Vendor ID チェック（Apple 製か）
        guard device.vendorID == appleVendorID else { return false }

        // 2. Product ID チェック（既知の Magic デバイスか）
        if knownProductIDs.contains(device.productID) {
            return true
        }

        // 3. デバイス名によるフォールバック（未知の新世代対応）
        let name = device.name ?? ""
        return namePatterns.contains(where: { name.hasPrefix($0) })
    }

    static func deviceType(_ device: IOBluetoothDevice) -> MagicDeviceType? {
        let name = device.name ?? ""
        if name.contains("Keyboard") { return .keyboard }
        if name.contains("Trackpad") { return .trackpad }
        return nil
    }
}
```

### 3.2 BlueUtil ラッパー設計

```swift
protocol BlueUtilExecutorProtocol: Sendable {
    func pair(address: String) async throws
    func unpair(address: String) async throws
    func connect(address: String) async throws
    func disconnect(address: String) async throws
    func isPaired(address: String) async throws -> Bool
    func isConnected(address: String) async throws -> Bool
}

actor BlueUtilWrapper: BlueUtilExecutorProtocol {
    /// バンドル内の blueutil バイナリパス
    private let binaryPath: String

    init() {
        self.binaryPath = Bundle.main.path(
            forResource: "blueutil",
            ofType: nil,
            inDirectory: nil
        ) ?? "/usr/local/bin/blueutil"
    }

    func pair(address: String) async throws {
        try await execute(["--pair", address])
    }

    func unpair(address: String) async throws {
        try await execute(["--unpair", address])
    }

    func connect(address: String) async throws {
        try await execute(["--connect", address])
    }

    func disconnect(address: String) async throws {
        try await execute(["--disconnect", address])
    }

    func isPaired(address: String) async throws -> Bool {
        let output = try await execute(["--is-paired", address])
        return output.trimmingCharacters(in: .whitespacesAndNewlines) == "1"
    }

    func isConnected(address: String) async throws -> Bool {
        let output = try await execute(["--is-connected", address])
        return output.trimmingCharacters(in: .whitespacesAndNewlines) == "1"
    }

    // MARK: - Private

    @discardableResult
    private func execute(_ arguments: [String]) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.arguments = arguments

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { proc in
                let output = String(
                    data: stdout.fileHandleForReading.readDataToEndOfFile(),
                    encoding: .utf8
                ) ?? ""
                let errorOutput = String(
                    data: stderr.fileHandleForReading.readDataToEndOfFile(),
                    encoding: .utf8
                ) ?? ""

                if proc.terminationStatus == 0 {
                    continuation.resume(returning: output)
                } else {
                    continuation.resume(throwing: BlueUtilError.executionFailed(
                        code: proc.terminationStatus,
                        message: errorOutput
                    ))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: BlueUtilError.launchFailed(error))
            }
        }
    }
}
```

### 3.3 BluetoothManager（統合管理）

```swift
actor BluetoothManager {
    private let adapter: BluetoothAdapterProtocol
    private let blueutil: BlueUtilExecutorProtocol
    private let batteryMonitor: BatteryMonitorProtocol

    /// Magic デバイスの検出
    func discoverMagicDevices() async -> [MagicDevice] {
        let allDevices = await adapter.pairedDevices()
        return allDevices
            .filter { MagicDeviceIdentifier.isMagicDevice($0) }
            .compactMap { device -> MagicDevice? in
                guard let type = MagicDeviceIdentifier.deviceType(device) else { return nil }
                return MagicDevice(
                    address: device.addressString,
                    name: device.name ?? "Unknown",
                    type: type,
                    isConnected: device.isConnected(),
                    batteryLevel: nil  // 別途 BatteryMonitor で取得
                )
            }
    }

    /// デバイスのペアリング解除 → 切り替え先への通知
    func releaseDevice(_ device: MagicDevice) async throws {
        try await blueutil.unpair(address: device.address)
        // unpair 後、デバイスが BT スキャン可能状態になるのを待機
        try await Task.sleep(for: .seconds(1))
    }

    /// デバイスのペアリング＋接続
    func acquireDevice(_ device: MagicDevice) async throws {
        try await blueutil.pair(address: device.address)
        try await Task.sleep(for: .milliseconds(500))
        try await blueutil.connect(address: device.address)
    }
}
```

### 3.4 切り替えシーケンス図

```
Mac A (現在の接続先)         Network          Mac B (切り替え先)
   │                          │                   │
   │  ユーザーが「Mac B に切り替え」を選択            │
   │                          │                   │
   ├─── SwitchRequest ───────▶├──────────────────▶│
   │    {devices, targetMac}  │                   │
   │                          │                   │
   │                          │  ◀── Ack ─────────┤
   │                          │                   │
   │  1. unpair(device)       │                   │
   │  (blueutil --unpair)     │                   │
   │  ──────────────────      │                   │
   │                          │                   │
   ├─── DeviceReleased ──────▶├──────────────────▶│
   │    {device.address}      │                   │
   │                          │                   │  2. pair(device)
   │                          │                   │  (blueutil --pair)
   │                          │                   │  ──────────────────
   │                          │                   │
   │                          │                   │  3. connect(device)
   │                          │                   │  (blueutil --connect)
   │                          │                   │  ──────────────────
   │                          │                   │
   │                          │  ◀── SwitchResult─┤
   │  ◀──────────────────────┤    {success/fail}  │
   │                          │                   │
   │  通知: 切り替え完了       │                   │
   │                          │                   │
```

### 3.5 バッテリー監視

```swift
protocol BatteryMonitorProtocol: Sendable {
    func batteryLevel(for address: String) async -> Int?
    func startMonitoring(interval: Duration) async
    func stopMonitoring() async
}

actor BatteryMonitor: BatteryMonitorProtocol {
    private var monitoringTask: Task<Void, Never>?
    private let lowBatteryThreshold: Int  // デフォルト: 20%

    /// IOBluetooth の HID レポートからバッテリー残量を取得
    func batteryLevel(for address: String) async -> Int? {
        guard let device = IOBluetoothDevice(addressString: address),
              device.isConnected() else {
            return nil
        }
        // IOBluetooth の kIOPSCurrentCapacityKey を参照
        // IORegistry からバッテリー情報を取得
        return queryBatteryFromIORegistry(device: device)
    }

    func startMonitoring(interval: Duration = .seconds(60)) async {
        monitoringTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: interval)
                await checkBatteryLevels()
            }
        }
    }

    private func checkBatteryLevels() async {
        // 接続中デバイスのバッテリーを確認し、
        // 閾値以下なら NotificationManager 経由で通知
    }
}
```

---

## 4. ネットワーク通信設計

### 4.1 サービス検出（Bonjour）

#### サービスタイプ定義

```
Service Type: _magicswitch._tcp
Service Name: MagicSwitch-{hostname}
TXT Record:
  - version: "1.0"
  - hostId: "{UUID}"
  - hostName: "{ユーザー設定名}"
```

#### PeerBrowser（検出側）

```swift
actor PeerBrowser {
    private var browser: NWBrowser?

    func startBrowsing() async -> AsyncStream<PeerEvent> {
        AsyncStream { continuation in
            let params = NWParameters()
            params.includePeerToPeer = true
            let browser = NWBrowser(
                for: .bonjour(type: "_magicswitch._tcp", domain: nil),
                using: params
            )
            browser.browseResultsChangedHandler = { results, changes in
                for change in changes {
                    switch change {
                    case .added(let result):
                        continuation.yield(.found(PeerInfo(from: result)))
                    case .removed(let result):
                        continuation.yield(.lost(PeerInfo(from: result)))
                    default:
                        break
                    }
                }
            }
            browser.start(queue: .main)
            self.browser = browser
        }
    }
}
```

#### PeerAdvertiser（公開側）

```swift
actor PeerAdvertiser {
    private var listener: NWListener?

    func startAdvertising(hostInfo: HostInfo) async throws {
        let params = NWParameters.tcp
        // TLS を有効化
        let tlsOptions = NWProtocolTLS.Options()
        configureTLS(tlsOptions, identity: hostInfo.tlsIdentity)
        params.defaultProtocolStack.applicationProtocols.insert(
            NWProtocolTLS.Options(), at: 0
        )

        let listener = try NWListener(using: params)
        listener.service = NWListener.Service(
            name: "MagicSwitch-\(hostInfo.hostName)",
            type: "_magicswitch._tcp",
            txtRecord: hostInfo.txtRecord
        )
        // ...
    }
}
```

### 4.2 通信プロトコル設計

#### メッセージフォーマット

JSON ベースの軽量プロトコルを採用する。メッセージは Length-Prefixed Frame で送受信する。

```
┌──────────────────────────────────────────┐
│ Frame Format                             │
├──────────┬───────────────────────────────┤
│ 4 bytes  │ Variable length               │
│ Length   │ JSON Payload                  │
│ (UInt32  │ (UTF-8 encoded)              │
│  Big-E)  │                              │
└──────────┴───────────────────────────────┘
```

#### メッセージ型定義

```swift
/// 全メッセージの基底
struct Message: Codable {
    let id: UUID
    let type: MessageType
    let timestamp: Date
    let payload: Payload
}

enum MessageType: String, Codable {
    // 切り替え関連
    case switchRequest       // Mac A → Mac B: 切り替え要求
    case switchAck           // Mac B → Mac A: 受領確認
    case deviceReleased      // Mac A → Mac B: デバイス解放完了
    case switchResult        // Mac B → Mac A: 切り替え結果

    // ペアリング関連
    case pairRequest         // 相互認証要求
    case pairChallenge       // チャレンジ送信
    case pairResponse        // チャレンジ応答
    case pairConfirm         // ペアリング完了

    // ステータス関連
    case heartbeat           // 定期的な生存確認
    case statusQuery         // 状態問い合わせ
    case statusResponse      // 状態応答
}

enum Payload: Codable {
    case switchRequest(SwitchRequestPayload)
    case switchResult(SwitchResultPayload)
    case deviceReleased(DeviceReleasedPayload)
    case pairRequest(PairRequestPayload)
    case heartbeat(HeartbeatPayload)
    // ...
}

struct SwitchRequestPayload: Codable {
    let devices: [DeviceAddress]      // 切り替え対象デバイスの MAC アドレス
    let sourceHostId: UUID            // 送信元 Mac の ID
    let targetHostId: UUID            // 切り替え先 Mac の ID
}

struct SwitchResultPayload: Codable {
    let requestId: UUID
    let results: [DeviceSwitchResult] // デバイスごとの結果
}

struct DeviceSwitchResult: Codable {
    let address: String
    let success: Bool
    let error: String?
}
```

### 4.3 セキュリティ設計

#### TLS 通信

```swift
// Network.framework の TLS 1.3 を使用
// 自己署名証明書を生成し、初回ペアリング時に相互交換
```

#### 初回ペアリング（Mac 間認証）

```
Mac A                                     Mac B
  │                                         │
  │  1. PairRequest                         │
  │    {hostId, hostName, publicKey}         │
  │  ──────────────────────────────────────▶ │
  │                                         │
  │  2. PairChallenge                       │
  │    {displayCode: "1234"}                │
  │  ◀────────────────────────────────────── │
  │                                         │
  │  (Mac A に 4桁コード表示)               │
  │  (ユーザーが Mac B で同じコードを確認)    │
  │                                         │
  │  3. PairResponse                        │
  │    {confirmed: true, publicKey}         │
  │  ──────────────────────────────────────▶ │
  │                                         │
  │  4. PairConfirm                         │
  │    {success: true, sharedSecret}        │
  │  ◀────────────────────────────────────── │
  │                                         │
  │  (以降、sharedSecret ベースの TLS 通信)  │
```

- 初回接続時に 4桁のペアリングコードを両 Mac に表示し、ユーザーが目視確認する
- 確認後、公開鍵を交換し、以降の通信で使用する
- ペアリング情報は Keychain に安全に保存する

#### Keychain 保存項目

| 項目 | Keychain Service | 用途 |
|------|-----------------|------|
| TLS 秘密鍵 | `com.magicswitch.tls.identity` | 自己署名証明書の秘密鍵 |
| ペアリング済み Mac の公開鍵 | `com.magicswitch.peer.{hostId}` | 通信相手の認証 |
| 共有シークレット | `com.magicswitch.shared.{hostId}` | 追加認証用 |

### 4.4 NetworkManager（統合管理）

```swift
actor NetworkManager {
    private let browser: PeerBrowser
    private let advertiser: PeerAdvertiser
    private var connections: [UUID: PeerConnection] = [:]

    /// サービス開始（サーバー兼クライアント）
    func start(hostInfo: HostInfo) async throws {
        try await advertiser.startAdvertising(hostInfo: hostInfo)
        await startBrowsing()
        startHeartbeat()
    }

    /// 切り替えコマンド送信
    func sendSwitchRequest(
        to targetHostId: UUID,
        devices: [MagicDevice]
    ) async throws -> SwitchResultPayload {
        guard let connection = connections[targetHostId] else {
            throw NetworkError.peerNotFound(targetHostId)
        }
        let request = Message(
            id: UUID(),
            type: .switchRequest,
            timestamp: Date(),
            payload: .switchRequest(SwitchRequestPayload(
                devices: devices.map(\.address),
                sourceHostId: hostInfo.id,
                targetHostId: targetHostId
            ))
        )
        return try await connection.sendAndWait(request, timeout: .seconds(15))
    }

    /// 受信メッセージのハンドリング
    func handleIncoming(_ message: Message, from peer: PeerConnection) async {
        switch message.type {
        case .switchRequest:
            await handleSwitchRequest(message, from: peer)
        case .deviceReleased:
            await handleDeviceReleased(message, from: peer)
        // ...
        }
    }

    /// ハートビート（30秒間隔）
    private func startHeartbeat() {
        Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                for (_, connection) in connections {
                    try? await connection.send(Message.heartbeat())
                }
            }
        }
    }
}
```

---

## 5. データモデル設計

### 5.1 ドメインモデル

```swift
// MARK: - デバイスモデル

/// Magic デバイスの種別
enum MagicDeviceType: String, Codable {
    case keyboard
    case trackpad
}

/// Magic デバイス
struct MagicDevice: Codable, Identifiable, Hashable {
    let id: UUID                     // アプリ内部ID
    let address: String              // Bluetooth MAC アドレス (例: "aa-bb-cc-dd-ee-ff")
    var name: String                 // デバイス名 (例: "Magic Keyboard")
    let type: MagicDeviceType        // keyboard / trackpad
    var isConnected: Bool            // 現在の接続状態
    var batteryLevel: Int?           // バッテリー残量 (0-100)
    var connectedHostId: UUID?       // 現在接続中の Mac の ID
}

// MARK: - ホスト（Mac）モデル

/// 接続先 Mac の情報
struct HostInfo: Codable, Identifiable, Hashable {
    let id: UUID                     // ホスト識別子（初回起動時に生成）
    var label: String                // ユーザーが付けたラベル (例: "仕事用 MacBook Pro")
    let hostName: String             // macOS ホスト名
    var isPaired: Bool               // Magic Switch 同士のペアリング済みか
    var lastSeen: Date?              // 最後にネットワーク上で検出された日時
    var isOnline: Bool               // 現在オンラインか
}

// MARK: - 切り替えプロファイル

/// デバイスと接続先の紐付け
struct SwitchProfile: Codable, Identifiable {
    let id: UUID
    var name: String                 // プロファイル名 (例: "仕事モード")
    var targetHostId: UUID           // 切り替え先 Mac の ID
    var devices: [UUID]              // 切り替え対象デバイスの ID リスト
    var shortcut: KeyboardShortcut?  // 割り当てられたショートカット
    var sortOrder: Int               // 表示順
}

// MARK: - 設定モデル

/// アプリケーション設定
struct AppConfig: Codable {
    var launchAtLogin: Bool = false
    var showNotifications: Bool = true
    var lowBatteryThreshold: Int = 20    // バッテリー低下通知閾値 (%)
    var logLevel: LogLevel = .info
    var switchTimeoutSeconds: Int = 15
    var maxRetryCount: Int = 3
}

/// ログレベル
enum LogLevel: String, Codable, CaseIterable {
    case debug, info, warn, error
}

/// キーボードショートカット
struct KeyboardShortcut: Codable, Hashable {
    let key: String                  // キー (例: "1", "2", "3")
    let modifiers: [Modifier]        // 修飾キー

    enum Modifier: String, Codable {
        case control, option, command, shift
    }
}
```

### 5.2 永続化方式

| データ | 保存方式 | 理由 |
|--------|---------|------|
| `AppConfig` | JSON ファイル (`~/Library/Application Support/MagicSwitch/config.json`) | UserDefaults より構造化されたデータに向く。手動編集・バックアップも容易 |
| `MagicDevice` リスト | JSON ファイル (`~/Library/Application Support/MagicSwitch/devices.json`) | デバイス情報の永続化 |
| `HostInfo` リスト | JSON ファイル (`~/Library/Application Support/MagicSwitch/hosts.json`) | ホスト情報の永続化 |
| `SwitchProfile` リスト | JSON ファイル (`~/Library/Application Support/MagicSwitch/profiles.json`) | プロファイル情報の永続化 |
| TLS 証明書・秘密鍵 | macOS Keychain | セキュリティ上 Keychain が最適 |
| ペアリング情報 | macOS Keychain | セキュリティ上 Keychain が最適 |
| ログファイル | テキストファイル (`~/Library/Logs/MagicSwitch/`) | 要件 NFR-008 に準拠 |

**SQLite を不採用とした理由**: データ量が少なく（デバイス数台、Mac 最大3台）、リレーションも単純であるため、JSON ファイルで十分。SQLite はオーバーヘッドが大きい。

### 5.3 ConfigStore 設計

```swift
protocol ConfigStoreProtocol: Sendable {
    func load<T: Codable>(_ type: T.Type, from filename: String) async throws -> T
    func save<T: Codable>(_ value: T, to filename: String) async throws
}

actor ConfigStore: ConfigStoreProtocol {
    private let baseURL: URL  // ~/Library/Application Support/MagicSwitch/

    init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!
        self.baseURL = appSupport.appendingPathComponent("MagicSwitch")
    }

    func load<T: Codable>(_ type: T.Type, from filename: String) async throws -> T {
        let url = baseURL.appendingPathComponent(filename)
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(T.self, from: data)
    }

    func save<T: Codable>(_ value: T, to filename: String) async throws {
        try FileManager.default.createDirectory(
            at: baseURL, withIntermediateDirectories: true
        )
        let url = baseURL.appendingPathComponent(filename)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(value)
        try data.write(to: url, options: .atomic)
    }
}
```

---

## 6. UI 設計

### 6.1 メニューバーアプリ構造

```
┌────────────────────────────────────┐
│  ⌨️ Magic Switch    (メニューバー)  │  ← NSStatusItem
└─────────┬──────────────────────────┘
          │
          ▼
┌────────────────────────────────────┐
│  ⌨ Magic Keyboard          🔋 85% │  ← 接続中デバイス1
│    └ 接続先: 仕事用 MacBook Pro     │
│                                    │
│  🔲 Magic Trackpad          🔋 72% │  ← 接続中デバイス2
│    └ 接続先: 仕事用 MacBook Pro     │
│                                    │
│  ──────────────────────────────── │
│                                    │
│  切り替え先:                       │
│    ● 仕事用 MacBook Pro (現在)     │  ← 現在の接続先
│    ○ 個人用 Mac mini     ⌃⌥⌘2    │  ← 切り替え候補 + ショートカット
│    ○ 検証用 Mac Studio   ⌃⌥⌘3    │  ← 切り替え候補 + ショートカット
│                                    │
│  ──────────────────────────────── │
│                                    │
│  ⚙ 設定...                        │
│  ❓ ヘルプ                         │
│  ✕ 終了                           │
└────────────────────────────────────┘
```

#### MenuBarController（AppKit）

```swift
final class MenuBarController: NSObject {
    private var statusItem: NSStatusItem!
    private let viewModel: MenuBarViewModel

    func setup() {
        statusItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.variableLength
        )
        // アイコン設定
        statusItem.button?.image = NSImage(
            systemSymbolName: "keyboard",
            accessibilityDescription: "Magic Switch"
        )
        // メニュー構築
        statusItem.menu = buildMenu()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        // デバイス情報セクション
        for device in viewModel.connectedDevices {
            let item = NSMenuItem()
            item.attributedTitle = deviceAttributedTitle(device)
            menu.addItem(item)
        }

        menu.addItem(.separator())

        // 切り替え先セクション
        let header = NSMenuItem(title: "切り替え先:", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        for profile in viewModel.switchProfiles {
            let item = NSMenuItem(
                title: profile.displayTitle,
                action: #selector(switchTo(_:)),
                keyEquivalent: ""
            )
            item.representedObject = profile
            if profile.isCurrent {
                item.state = .on
            }
            menu.addItem(item)
        }

        menu.addItem(.separator())

        // 設定・終了
        menu.addItem(NSMenuItem(
            title: "設定...",
            action: #selector(openSettings),
            keyEquivalent: ","
        ))
        menu.addItem(NSMenuItem(
            title: "終了",
            action: #selector(quit),
            keyEquivalent: "q"
        ))

        return menu
    }
}
```

#### メニューバーアイコン状態

| 状態 | アイコン | 説明 |
|------|---------|------|
| 接続中 | `keyboard.fill` | デバイスが現在の Mac に接続されている |
| 未接続 | `keyboard` (outline) | デバイスが接続されていない |
| 切り替え中 | `keyboard.fill` + パルスアニメーション | 切り替え処理中 |
| エラー | `keyboard.badge.exclamationmark` | 切り替え失敗 |

### 6.2 設定画面（SwiftUI）

```swift
struct SettingsView: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        TabView {
            // タブ1: デバイス管理
            DevicesTab(viewModel: viewModel)
                .tabItem { Label("デバイス", systemImage: "keyboard") }

            // タブ2: 接続先管理
            HostsTab(viewModel: viewModel)
                .tabItem { Label("接続先", systemImage: "desktopcomputer") }

            // タブ3: ショートカット
            ShortcutsTab(viewModel: viewModel)
                .tabItem { Label("ショートカット", systemImage: "command") }

            // タブ4: 一般設定
            GeneralTab(viewModel: viewModel)
                .tabItem { Label("一般", systemImage: "gear") }
        }
        .frame(width: 500, height: 400)
    }
}
```

#### 設定タブ構成

| タブ | 内容 |
|------|------|
| デバイス | 検出済み Magic デバイスの一覧表示、デバイス情報の確認 |
| 接続先 | 登録済み Mac の一覧、新規登録（ネットワーク上の Mac を自動検出）、編集・削除 |
| ショートカット | 切り替え先ごとのグローバルショートカット設定 |
| 一般 | ログイン時自動起動、通知設定、バッテリー閾値、ログレベル |

### 6.3 セットアップウィザード（SwiftUI）

```
┌─────────────────────────────────────────┐
│           Magic Switch セットアップ       │
│                                         │
│  Step 1/4: 権限の設定                    │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ │
│                                         │
│  Magic Switch を使用するには、以下の      │
│  権限が必要です：                        │
│                                         │
│  ✅ Bluetooth        [許可済み]          │
│  ⬜ Accessibility    [許可する]          │
│  ⬜ Local Network    [許可する]          │
│                                         │
│                    [次へ →]              │
└─────────────────────────────────────────┘

Step 2/4: デバイスの選択
  → ペアリング済み Magic デバイスを検出・選択

Step 3/4: 接続先 Mac の登録
  → ネットワーク上の Mac を自動検出して登録
  → ペアリングコード確認

Step 4/4: 完了
  → ショートカット設定（任意）
  → セットアップ完了メッセージ
```

```swift
struct SetupWizardView: View {
    @Bindable var viewModel: SetupWizardViewModel

    var body: some View {
        VStack {
            // プログレスインジケーター
            ProgressView(value: Double(viewModel.currentStep), total: 4.0)
                .padding()

            // ステップコンテンツ
            switch viewModel.currentStep {
            case 1: PermissionsStep(viewModel: viewModel)
            case 2: DeviceSelectionStep(viewModel: viewModel)
            case 3: HostRegistrationStep(viewModel: viewModel)
            case 4: CompletionStep(viewModel: viewModel)
            default: EmptyView()
            }

            // ナビゲーションボタン
            HStack {
                if viewModel.currentStep > 1 {
                    Button("← 戻る") { viewModel.previousStep() }
                }
                Spacer()
                Button(viewModel.currentStep == 4 ? "完了" : "次へ →") {
                    viewModel.nextStep()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 600, height: 450)
    }
}
```

---

## 7. エラーハンドリング設計

### 7.1 エラー型定義

```swift
/// アプリケーション全体のエラー型
enum MagicSwitchError: LocalizedError {
    // Bluetooth エラー
    case bluetoothDisabled
    case deviceNotFound(address: String)
    case pairFailed(address: String, reason: String)
    case unpairFailed(address: String, reason: String)
    case connectFailed(address: String, reason: String)
    case disconnectFailed(address: String, reason: String)

    // ネットワークエラー
    case peerNotFound(hostId: UUID)
    case peerUnreachable(hostId: UUID)
    case connectionTimeout(hostId: UUID, seconds: Int)
    case authenticationFailed(hostId: UUID)

    // 切り替えエラー
    case switchFailed(devices: [String], reason: String)
    case switchPartiallyFailed(succeeded: [String], failed: [String])
    case switchTimeout

    // BlueUtil エラー
    case blueUtilNotFound
    case blueUtilExecutionFailed(code: Int32, message: String)

    // 設定エラー
    case configLoadFailed(Error)
    case configSaveFailed(Error)
    case maxHostsReached  // 最大3台制限

    var errorDescription: String? { /* ユーザー向けメッセージ */ }
    var recoverySuggestion: String? { /* 対処方法 */ }
}

/// BlueUtil 固有のエラー
enum BlueUtilError: Error {
    case launchFailed(Error)
    case executionFailed(code: Int32, message: String)
}
```

### 7.2 リトライ戦略

```swift
struct RetryPolicy {
    let maxAttempts: Int           // 最大リトライ回数（デフォルト: 3）
    let baseDelay: Duration        // 初回待機時間（デフォルト: 1秒）
    let backoffMultiplier: Double  // 待機時間の倍率（デフォルト: 2.0）
    let maxDelay: Duration         // 最大待機時間（デフォルト: 10秒）

    static let `default` = RetryPolicy(
        maxAttempts: 3,
        baseDelay: .seconds(1),
        backoffMultiplier: 2.0,
        maxDelay: .seconds(10)
    )
}

func withRetry<T>(
    policy: RetryPolicy = .default,
    operation: () async throws -> T
) async throws -> T {
    var lastError: Error?
    for attempt in 0..<policy.maxAttempts {
        do {
            return try await operation()
        } catch {
            lastError = error
            if attempt < policy.maxAttempts - 1 {
                let delay = min(
                    policy.baseDelay * pow(policy.backoffMultiplier, Double(attempt)),
                    policy.maxDelay
                )
                try await Task.sleep(for: delay)
            }
        }
    }
    throw lastError!
}
```

### 7.3 リカバリフロー

```
切り替え失敗
  │
  ├── Bluetooth エラー（unpair/pair 失敗）
  │     ├── リトライ（最大3回、指数バックオフ）
  │     └── 失敗 → ユーザー通知
  │           ├── 「元の Mac に戻す」ボタン → 元の Mac で re-pair
  │           └── 「手動で接続」ボタン → システム設定 > Bluetooth を開く
  │
  ├── ネットワークエラー（切り替え先 Mac に到達不可）
  │     ├── 切り替え先がオフラインの場合: 即時エラー
  │     └── タイムアウト（15秒）後: エラー通知
  │           └── デバイスは元の Mac に接続されたまま（安全）
  │
  └── 部分的失敗（Keyboard は成功、Trackpad は失敗 等）
        ├── 成功したデバイスの状態を維持
        ├── 失敗したデバイスのみリトライ
        └── 全リトライ失敗 → 「全デバイスを元に戻す」オプション提供
```

#### 切り替え失敗時の通知

```swift
func notifySwitchFailure(error: MagicSwitchError) {
    let notification = UNMutableNotificationContent()
    notification.title = "切り替え失敗"
    notification.body = error.errorDescription ?? "不明なエラーが発生しました"
    notification.categoryIdentifier = "SWITCH_FAILURE"

    // アクションボタン
    let revertAction = UNNotificationAction(
        identifier: "REVERT",
        title: "元の Mac に戻す"
    )
    let manualAction = UNNotificationAction(
        identifier: "MANUAL",
        title: "手動で接続"
    )
    let category = UNNotificationCategory(
        identifier: "SWITCH_FAILURE",
        actions: [revertAction, manualAction],
        intentIdentifiers: []
    )
    UNUserNotificationCenter.current().setNotificationCategories([category])
}
```

---

## 8. ビルド・配布設計

### 8.1 Package.swift

```swift
// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "MagicSwitch",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "MagicSwitch", targets: ["MagicSwitch"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.0"),
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts.git", from: "2.0.0"),
        .package(url: "https://github.com/sindresorhus/LaunchAtLogin-Modern.git", from: "1.0.0"),
    ],
    targets: [
        // メインアプリケーション
        .executableTarget(
            name: "MagicSwitch",
            dependencies: [
                "MagicSwitchCore",
                "MagicSwitchUI",
                .product(name: "LaunchAtLogin", package: "LaunchAtLogin-Modern"),
            ],
            path: "Sources/MagicSwitch",
            resources: [
                .copy("Resources/blueutil"),
            ]
        ),

        // コアライブラリ（Bluetooth、ネットワーク、ストレージ）
        .target(
            name: "MagicSwitchCore",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
            ],
            path: "Sources/MagicSwitchCore",
            linkerSettings: [
                .linkedFramework("IOBluetooth"),
                .linkedFramework("Network"),
            ]
        ),

        // UI ライブラリ（SwiftUI ビュー、ViewModels）
        .target(
            name: "MagicSwitchUI",
            dependencies: [
                "MagicSwitchCore",
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
            ],
            path: "Sources/MagicSwitchUI"
        ),

        // テスト
        .testTarget(
            name: "MagicSwitchCoreTests",
            dependencies: ["MagicSwitchCore"],
            path: "Tests/MagicSwitchCoreTests"
        ),
        .testTarget(
            name: "MagicSwitchUITests",
            dependencies: ["MagicSwitchUI"],
            path: "Tests/MagicSwitchUITests"
        ),
    ]
)
```

### 8.2 ビルドスクリプト

```bash
#!/bin/bash
# scripts/build.sh - アプリケーションバンドルのビルド

set -euo pipefail

APP_NAME="MagicSwitch"
BUNDLE_ID="com.example.magicswitch"
VERSION="${1:-1.0.0}"
BUILD_DIR=".build/release"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"

echo "=== Building ${APP_NAME} v${VERSION} ==="

# 1. Swift Package Manager でリリースビルド
swift build -c release --arch arm64 --arch x86_64

# 2. .app バンドル構造の作成
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# 3. 実行ファイルの配置
cp "${BUILD_DIR}/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/"

# 4. blueutil バイナリの配置
cp "Resources/blueutil" "${APP_BUNDLE}/Contents/Resources/"

# 5. Info.plist の生成
cat > "${APP_BUNDLE}/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSBluetoothAlwaysUsageDescription</key>
    <string>Magic Switch はデバイスの検出・接続切り替えに Bluetooth を使用します。</string>
    <key>NSLocalNetworkUsageDescription</key>
    <string>Magic Switch は Mac 間でデバイス切り替えコマンドを送受信するためにローカルネットワークを使用します。</string>
    <key>NSBonjourServices</key>
    <array>
        <string>_magicswitch._tcp</string>
    </array>
</dict>
</plist>
PLIST

# 6. エンタイトルメント
cat > "${BUILD_DIR}/entitlements.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.device.bluetooth</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.network.server</key>
    <true/>
    <key>com.apple.security.automation.apple-events</key>
    <true/>
</dict>
</plist>
PLIST

echo "=== Build complete: ${APP_BUNDLE} ==="
```

### 8.3 コード署名・公証スクリプト

```bash
#!/bin/bash
# scripts/sign-and-notarize.sh

set -euo pipefail

APP_NAME="MagicSwitch"
BUILD_DIR=".build/release"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
ENTITLEMENTS="${BUILD_DIR}/entitlements.plist"

DEVELOPER_ID="${DEVELOPER_ID_APPLICATION}"  # 環境変数から取得
TEAM_ID="${APPLE_TEAM_ID}"
APPLE_ID="${APPLE_ID_EMAIL}"
NOTARIZE_PASSWORD="${NOTARIZE_APP_PASSWORD}"  # App-specific password

echo "=== Signing ${APP_NAME} ==="

# 1. Hardened Runtime でコード署名
codesign --deep --force --verify --verbose \
    --sign "${DEVELOPER_ID}" \
    --entitlements "${ENTITLEMENTS}" \
    --options runtime \
    "${APP_BUNDLE}"

# 2. 署名の検証
codesign --verify --verbose "${APP_BUNDLE}"
spctl --assess --verbose "${APP_BUNDLE}"

# 3. DMG の作成
DMG_PATH="${BUILD_DIR}/${APP_NAME}.dmg"
hdiutil create -volname "${APP_NAME}" \
    -srcfolder "${APP_BUNDLE}" \
    -ov -format UDZO \
    "${DMG_PATH}"

# 4. DMG に署名
codesign --sign "${DEVELOPER_ID}" "${DMG_PATH}"

echo "=== Notarizing ${APP_NAME} ==="

# 5. 公証の送信
xcrun notarytool submit "${DMG_PATH}" \
    --apple-id "${APPLE_ID}" \
    --team-id "${TEAM_ID}" \
    --password "${NOTARIZE_PASSWORD}" \
    --wait

# 6. Staple（公証チケットの埋め込み）
xcrun stapler staple "${DMG_PATH}"

echo "=== Done: ${DMG_PATH} ==="
```

### 8.4 CI/CD パイプライン（GitHub Actions）

```yaml
# .github/workflows/release.yml
name: Build and Release

on:
  push:
    tags:
      - 'v*'

jobs:
  build:
    runs-on: macos-14  # Apple Silicon runner
    steps:
      - uses: actions/checkout@v4

      - name: Setup Swift
        uses: swift-actions/setup-swift@v2
        with:
          swift-version: '5.9'

      - name: Build
        run: bash scripts/build.sh ${{ github.ref_name }}

      - name: Sign and Notarize
        env:
          DEVELOPER_ID_APPLICATION: ${{ secrets.DEVELOPER_ID }}
          APPLE_TEAM_ID: ${{ secrets.TEAM_ID }}
          APPLE_ID_EMAIL: ${{ secrets.APPLE_ID }}
          NOTARIZE_APP_PASSWORD: ${{ secrets.NOTARIZE_PASSWORD }}
          CERTIFICATE_P12: ${{ secrets.CERTIFICATE_P12 }}
          CERTIFICATE_PASSWORD: ${{ secrets.CERTIFICATE_PASSWORD }}
        run: |
          # 証明書のインポート
          echo "$CERTIFICATE_P12" | base64 --decode > cert.p12
          security create-keychain -p "" build.keychain
          security import cert.p12 -k build.keychain -P "$CERTIFICATE_PASSWORD" -T /usr/bin/codesign
          security set-key-partition-list -S apple-tool:,apple: -s -k "" build.keychain
          security default-keychain -s build.keychain

          bash scripts/sign-and-notarize.sh

      - name: Create GitHub Release
        uses: softprops/action-gh-release@v1
        with:
          files: .build/release/MagicSwitch.dmg
          generate_release_notes: true

  test:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - name: Run Tests
        run: swift test

  update-homebrew:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - name: Update Homebrew Cask
        run: |
          # SHA256 の計算と Cask 定義の更新
          # homebrew-cask リポジトリへの PR 作成
          echo "Homebrew Cask update would be performed here"
```

### 8.5 Homebrew Cask 定義

```ruby
# Casks/magic-switch.rb
# 独自 Tap: homebrew-magic-switch
cask "magic-switch" do
  version "1.0.0"
  sha256 "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

  url "https://github.com/example/magic-switch/releases/download/v#{version}/MagicSwitch.dmg"
  name "Magic Switch"
  desc "Switch Magic Keyboard and Trackpad between Macs with one click"
  homepage "https://github.com/example/magic-switch"

  depends_on macos: ">= :ventura"

  app "MagicSwitch.app"

  postflight do
    # blueutil に実行権限を付与
    system_command "/bin/chmod",
                   args: ["+x", "#{appdir}/MagicSwitch.app/Contents/Resources/blueutil"]
  end

  uninstall quit: "com.example.magicswitch"

  zap trash: [
    "~/Library/Application Support/MagicSwitch",
    "~/Library/Logs/MagicSwitch",
    "~/Library/Preferences/com.example.magicswitch.plist",
  ]
end
```

---

## 9. ディレクトリ構成

```
magic-switch/
├── Package.swift                          # SPM パッケージ定義
├── README.md                              # プロジェクト説明
├── LICENSE                                # ライセンスファイル
│
├── Sources/
│   ├── MagicSwitch/                       # アプリケーションエントリポイント
│   │   ├── MagicSwitchApp.swift           # @main、アプリケーションライフサイクル
│   │   ├── AppDelegate.swift              # NSApplicationDelegate（メニューバー管理）
│   │   ├── DependencyContainer.swift      # DI コンテナ（サービスの初期化・注入）
│   │   └── Resources/
│   │       ├── blueutil                   # blueutil バイナリ（同梱）
│   │       ├── Assets.xcassets/           # アプリアイコン等
│   │       └── Localizable.strings        # ローカライズ文字列
│   │
│   ├── MagicSwitchCore/                   # コアライブラリ
│   │   ├── Bluetooth/
│   │   │   ├── BluetoothManager.swift     # Bluetooth 統合管理 (Actor)
│   │   │   ├── IOBluetoothAdapter.swift   # IOBluetooth API ラッパー
│   │   │   ├── BlueUtilWrapper.swift      # blueutil CLI ラッパー (Actor)
│   │   │   ├── BatteryMonitor.swift       # バッテリー残量監視
│   │   │   └── MagicDeviceIdentifier.swift # Magic デバイス判定ロジック
│   │   │
│   │   ├── Network/
│   │   │   ├── NetworkManager.swift       # ネットワーク統合管理 (Actor)
│   │   │   ├── PeerBrowser.swift          # Bonjour によるピア検出
│   │   │   ├── PeerAdvertiser.swift       # Bonjour によるサービス公開
│   │   │   ├── PeerConnection.swift       # 個別ピア接続管理
│   │   │   ├── MessageProtocol.swift      # メッセージ型定義・シリアライズ
│   │   │   └── SecurityManager.swift      # TLS 証明書管理、Keychain 操作
│   │   │
│   │   ├── Service/
│   │   │   ├── SwitchService.swift        # 切り替えオーケストレーション
│   │   │   ├── DeviceDiscoveryService.swift # デバイス検出サービス
│   │   │   └── RetryPolicy.swift          # リトライ戦略
│   │   │
│   │   ├── Storage/
│   │   │   ├── ConfigStore.swift          # 設定ファイル読み書き (Actor)
│   │   │   ├── DeviceStore.swift          # デバイス情報永続化
│   │   │   └── HostStore.swift            # ホスト情報永続化
│   │   │
│   │   ├── Models/
│   │   │   ├── MagicDevice.swift          # Magic デバイスモデル
│   │   │   ├── HostInfo.swift             # ホスト（Mac）モデル
│   │   │   ├── SwitchProfile.swift        # 切り替えプロファイルモデル
│   │   │   ├── AppConfig.swift            # アプリケーション設定モデル
│   │   │   └── Errors.swift              # エラー型定義
│   │   │
│   │   └── Common/
│   │       ├── Logger.swift               # ロギングユーティリティ
│   │       └── NotificationManager.swift  # macOS 通知管理
│   │
│   └── MagicSwitchUI/                     # UI ライブラリ
│       ├── MenuBar/
│       │   ├── MenuBarController.swift    # メニューバー制御 (AppKit)
│       │   └── MenuBarViewModel.swift     # メニューバー ViewModel
│       │
│       ├── Settings/
│       │   ├── SettingsView.swift         # 設定画面ルート (SwiftUI)
│       │   ├── SettingsViewModel.swift    # 設定 ViewModel
│       │   ├── DevicesTab.swift           # デバイス管理タブ
│       │   ├── HostsTab.swift             # 接続先管理タブ
│       │   ├── ShortcutsTab.swift         # ショートカット設定タブ
│       │   └── GeneralTab.swift           # 一般設定タブ
│       │
│       ├── SetupWizard/
│       │   ├── SetupWizardView.swift      # セットアップウィザードルート
│       │   ├── SetupWizardViewModel.swift # ウィザード ViewModel
│       │   ├── PermissionsStep.swift      # Step 1: 権限設定
│       │   ├── DeviceSelectionStep.swift  # Step 2: デバイス選択
│       │   ├── HostRegistrationStep.swift # Step 3: Mac 登録
│       │   └── CompletionStep.swift       # Step 4: 完了
│       │
│       └── Components/
│           ├── DeviceRow.swift            # デバイス表示コンポーネント
│           ├── HostRow.swift              # ホスト表示コンポーネント
│           └── StatusIndicator.swift      # 接続状態インジケーター
│
├── Tests/
│   ├── MagicSwitchCoreTests/
│   │   ├── BluetoothManagerTests.swift    # BluetoothManager のテスト
│   │   ├── BlueUtilWrapperTests.swift     # BlueUtilWrapper のテスト
│   │   ├── NetworkManagerTests.swift      # NetworkManager のテスト
│   │   ├── SwitchServiceTests.swift       # SwitchService のテスト
│   │   ├── ConfigStoreTests.swift         # ConfigStore のテスト
│   │   ├── MessageProtocolTests.swift     # メッセージシリアライズのテスト
│   │   └── Mocks/
│   │       ├── MockBluetoothAdapter.swift # テスト用モック
│   │       ├── MockBlueUtilExecutor.swift
│   │       ├── MockNetworkManager.swift
│   │       └── MockConfigStore.swift
│   │
│   └── MagicSwitchUITests/
│       ├── MenuBarViewModelTests.swift
│       ├── SettingsViewModelTests.swift
│       └── SetupWizardViewModelTests.swift
│
├── Resources/
│   └── blueutil                           # blueutil ソースまたはビルド済みバイナリ
│
├── scripts/
│   ├── build.sh                           # ビルドスクリプト
│   ├── sign-and-notarize.sh               # コード署名・公証
│   ├── create-dmg.sh                      # DMG 作成
│   └── update-cask.sh                     # Homebrew Cask 定義更新
│
├── homebrew/
│   └── magic-switch.rb                    # Homebrew Cask 定義
│
├── docs/
│   ├── requirements.md                    # 要件定義書
│   └── architecture.md                    # 本設計書
│
└── .github/
    └── workflows/
        ├── ci.yml                         # CI（テスト・リント）
        └── release.yml                    # リリース（ビルド・署名・公証・配布）
```

---

## 10. SwitchService（切り替えオーケストレーション）詳細設計

切り替え処理の中核となるサービスの詳細設計を記載する。

```swift
actor SwitchService {
    private let bluetooth: BluetoothManager
    private let network: NetworkManager
    private let config: ConfigStore
    private let notificationManager: NotificationManager
    private let retryPolicy: RetryPolicy

    enum SwitchState {
        case idle
        case switching(progress: SwitchProgress)
        case failed(error: MagicSwitchError)
    }

    struct SwitchProgress {
        let totalDevices: Int
        var completedDevices: Int
        var currentPhase: Phase

        enum Phase {
            case releasing    // 現在の Mac からデバイスを解放中
            case acquiring    // 切り替え先の Mac でデバイスを取得中
            case verifying    // 接続確認中
        }
    }

    /// メインの切り替えメソッド
    func switchDevices(
        _ devices: [MagicDevice],
        to targetHost: HostInfo
    ) async throws {
        // 1. 前提条件チェック
        guard await network.isPeerOnline(targetHost.id) else {
            throw MagicSwitchError.peerUnreachable(hostId: targetHost.id)
        }

        // 2. 切り替え先に SwitchRequest を送信
        let ack = try await network.sendSwitchRequest(
            to: targetHost.id,
            devices: devices
        )

        // 3. 現在の Mac でデバイスを解放（unpair）
        for device in devices {
            try await withRetry(policy: retryPolicy) {
                try await bluetooth.releaseDevice(device)
            }
            // デバイスごとに解放完了を通知
            try await network.sendDeviceReleased(
                device: device,
                to: targetHost.id
            )
        }

        // 4. 切り替え先からの結果を待機（タイムアウト付き）
        let result = try await withTimeout(.seconds(config.switchTimeoutSeconds)) {
            try await network.waitForSwitchResult(requestId: ack.requestId)
        }

        // 5. 結果の評価
        if result.results.allSatisfy(\.success) {
            await notificationManager.notifySwitchSuccess(
                devices: devices,
                target: targetHost
            )
        } else {
            let failed = result.results.filter { !$0.success }
            throw MagicSwitchError.switchPartiallyFailed(
                succeeded: result.results.filter(\.success).map(\.address),
                failed: failed.map(\.address)
            )
        }
    }

    /// 切り替え先 Mac 側で実行される受信ハンドラ
    func handleIncomingSwitchRequest(
        _ request: SwitchRequestPayload,
        from sourcePeer: PeerConnection
    ) async {
        // 1. ACK 送信
        try? await sourcePeer.send(Message.switchAck(requestId: request.id))

        // 2. DeviceReleased を待機してから pair + connect
        var results: [DeviceSwitchResult] = []
        for address in request.devices {
            // 解放通知を待つ
            await waitForDeviceReleased(address: address)

            // pair + connect
            do {
                try await withRetry(policy: retryPolicy) {
                    try await bluetooth.acquireDevice(
                        MagicDevice(address: address, ...)
                    )
                }
                results.append(DeviceSwitchResult(
                    address: address, success: true, error: nil
                ))
            } catch {
                results.append(DeviceSwitchResult(
                    address: address, success: false, error: error.localizedDescription
                ))
            }
        }

        // 3. 結果を返送
        try? await sourcePeer.send(Message.switchResult(
            requestId: request.id,
            results: results
        ))
    }
}
```

---

## 11. ロギング設計

### 11.1 ログ設計

```swift
import Logging
import OSLog

struct MagicSwitchLogger {
    /// 各モジュール用のロガー
    static let bluetooth = Logger(label: "com.magicswitch.bluetooth")
    static let network = Logger(label: "com.magicswitch.network")
    static let switching = Logger(label: "com.magicswitch.switch")
    static let ui = Logger(label: "com.magicswitch.ui")
    static let storage = Logger(label: "com.magicswitch.storage")
}

/// ファイル出力ロギングハンドラ
/// ~/Library/Logs/MagicSwitch/magicswitch-YYYY-MM-DD.log
struct FileLogHandler: LogHandler {
    let logDirectory: URL  // ~/Library/Logs/MagicSwitch/

    // ログローテーション: 日付ごとにファイル分割
    // 保持期間: 30日（古いログは自動削除）
}
```

### 11.2 ログ出力例

```
[2026-02-23 10:30:15.123] [INFO] [switch] Switch initiated: devices=[aa:bb:cc:dd:ee:ff, 11:22:33:44:55:66] target=Mac-B (uuid)
[2026-02-23 10:30:15.456] [DEBUG] [bluetooth] Unpairing device aa:bb:cc:dd:ee:ff
[2026-02-23 10:30:16.789] [DEBUG] [bluetooth] Unpair complete: aa:bb:cc:dd:ee:ff
[2026-02-23 10:30:17.012] [INFO] [network] DeviceReleased sent to Mac-B
[2026-02-23 10:30:20.345] [INFO] [switch] Switch complete: all devices connected to Mac-B
```

---

## 12. テスト戦略

### 12.1 テスト方針

| テスト種別 | 対象 | ツール |
|-----------|------|--------|
| ユニットテスト | Models, Services, ViewModels | XCTest + Swift Testing |
| インテグレーションテスト | Bluetooth + Network 連携 | XCTest（実機テスト） |
| UI テスト | メニューバー操作、設定画面 | XCUITest |
| 手動テスト | 実機でのデバイス切り替え | テスト手順書 |

### 12.2 モック戦略

Core レイヤーの主要コンポーネントは protocol で抽象化し、テスト時にモックに差し替える:

- `BluetoothAdapterProtocol` → `MockBluetoothAdapter`
- `BlueUtilExecutorProtocol` → `MockBlueUtilExecutor`
- `ConfigStoreProtocol` → `MockConfigStore`

これにより、Bluetooth ハードウェアやネットワーク環境がなくてもロジックのテストが可能。

---

## 13. 今後の拡張ポイント

| 項目 | 対応バージョン | 設計上の考慮 |
|------|--------------|-------------|
| Magic Mouse サポート | v2 | `MagicDeviceType` に `.mouse` を追加。`MagicDeviceIdentifier` に Product ID を追加するのみで対応可能 |
| iPad / iPhone 対応 | v3+ | ネットワーク通信レイヤーの抽象化により、プラットフォーム拡張が可能な設計とした |
| プラグインシステム | 将来 | Service レイヤーの protocol 設計により、カスタムロジックの注入が可能 |

---

*本設計書は要件定義書 v1.0 に基づいて作成されました。実装時に発見された技術的制約により設計の修正が必要になった場合は、本書を改訂してください。*
