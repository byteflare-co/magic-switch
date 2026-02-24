# Magic Switch - テスト結果レポート

## 1. テスト概要

| 項目 | 内容 |
|------|------|
| 実施日 | 2026-02-23 |
| テスト担当者 | tester-exec |
| 対象バージョン | 1.0.0 |
| テスト環境 | macOS 26.3 (Darwin 25.3.0), Apple Silicon (arm64) |
| Swift バージョン | Swift 6.2.3 (swiftlang-6.2.3.3.21) |
| ビルドツール | Swift Package Manager (Command Line Tools) |
| プロジェクト規模 | 32 ファイル, 3,884 行 (Swift) |

---

## 2. ビルドテスト結果

### 2.1 デバッグビルド (`swift build`)

| 項目 | 結果 |
|------|------|
| **判定** | **PASS** |
| ビルド時間 | 1.37 秒 |
| エラー | 0 |
| 警告 | 0 |

```
Building for debugging...
Build complete! (1.37s)
```

### 2.2 ビルド成果物

| 項目 | 確認結果 |
|------|---------|
| 実行バイナリ生成 | `.build/debug/MagicSwitch` - 生成確認 |
| Package.resolved | 依存関係ロック済み |
| 依存ライブラリ解決 | swift-log, KeyboardShortcuts, LaunchAtLogin-Modern - 全て解決 |

### 2.3 ビルドスクリプト (`scripts/build.sh`)

| 項目 | 結果 |
|------|------|
| スクリプト存在 | PASS |
| 実行権限 | PASS (chmod +x 済み) |
| Info.plist | PASS (Resources/Info.plist 存在) |
| エンタイトルメント生成 | PASS (スクリプト内で生成) |

---

## 3. ユニットテスト結果

### 3.1 テスト実行

| 項目 | 結果 |
|------|------|
| **判定** | **FAIL (環境制約)** |
| 原因 | Xcode 未インストール (Command Line Tools のみ) |
| エラー | `error: no such module 'XCTest'` |

**詳細**: テスト環境に Xcode がインストールされておらず、Command Line Tools のみが利用可能。XCTest フレームワークは Xcode に同梱されているため、`swift test` コマンドが失敗する。Swift Testing フレームワークも同様に利用不可。

### 3.2 テストファイル確認

| テストファイル | 存在 | 内容 |
|-------------|------|------|
| `Tests/MagicSwitchCoreTests/ConfigStoreTests.swift` | PASS | AppConfig, MagicDevice, HostMac のモデルテスト 3件 |
| `Tests/MagicSwitchTests/MagicSwitchAppTests.swift` | PASS | プレースホルダーテスト 1件 |

### 3.3 テストコード品質

| 観点 | 評価 |
|------|------|
| テストカバレッジ | 不十分 - モデル層のみ。Service/ViewModel/Core のテストなし |
| モック戦略 | 設計書では protocol ベースのモック設計が示されているが、モックファイル未作成 |
| テスト対象 | 3件のみ (AppConfig, MagicDevice, HostMac の初期値テスト) |

### 3.4 Package.swift の問題 (修正済み)

**BUG-001**: `MagicSwitchTests` テストターゲットが executable ターゲット `MagicSwitch` に依存していたため、テストコンパイル不可。`MagicSwitchCore` への依存に修正済み。

---

## 4. コード品質チェック結果

### 4.1 プロジェクト構造

#### 設計書のディレクトリ構成との比較

| 設計書の構成 | 実装状況 | 備考 |
|-------------|---------|------|
| `Sources/MagicSwitch/` | PASS | App, Presentation, ViewModel の3サブディレクトリ |
| `Sources/MagicSwitchCore/` | PASS | Bluetooth, Network, Service, Storage, Models, Common の6サブディレクトリ |
| `Sources/MagicSwitchUI/` (設計書) | **不一致** | 設計書では別ターゲットだが、実装では MagicSwitch に統合 |
| `Tests/MagicSwitchCoreTests/` | PASS | 存在するがテスト不十分 |
| `Tests/MagicSwitchUITests/` (設計書) | **欠如** | 設計書にあるが実装なし |
| `Resources/` | PASS | Info.plist 存在。blueutil バイナリは未同梱 |
| `scripts/` | 部分的 | build.sh のみ。sign-and-notarize.sh, create-dmg.sh, update-cask.sh なし |
| `homebrew/` | PASS | magic-switch.rb 存在 |
| `docs/` | PASS | requirements.md, architecture.md, test-scenarios.md 存在 |

#### ソースファイル一覧 (全 32 ファイル)

**MagicSwitch (11 ファイル)**:
| ファイル | 役割 | 評価 |
|---------|------|------|
| App/MagicSwitchApp.swift | @main エントリポイント | OK |
| App/AppDelegate.swift | NSApplicationDelegate | OK |
| App/DependencyContainer.swift | DI コンテナ | OK |
| Presentation/MenuBarController.swift | メニューバー UI (AppKit) | OK |
| Presentation/SettingsView.swift | 設定画面 (SwiftUI) | OK |
| Presentation/SetupWizardView.swift | セットアップウィザード (SwiftUI) | 問題あり |
| Presentation/DeviceRowView.swift | デバイス行表示 | OK |
| Presentation/HostRowView.swift | ホスト行表示 | OK |
| ViewModel/MenuBarViewModel.swift | メニューバー ViewModel | OK |
| ViewModel/SettingsViewModel.swift | 設定 ViewModel | OK |
| ViewModel/SetupWizardViewModel.swift | ウィザード ViewModel | 問題あり |

**MagicSwitchCore (21 ファイル)**:
| ファイル | 役割 | 評価 |
|---------|------|------|
| Bluetooth/BluetoothManager.swift | BT 統合管理 (Actor) | OK |
| Bluetooth/BluetoothProtocols.swift | BT プロトコル定義 | OK |
| Bluetooth/BlueUtilWrapper.swift | blueutil CLI ラッパー (Actor) | OK |
| Bluetooth/IOBluetoothAdapter.swift | IOBluetooth アダプタ | 注意 |
| Bluetooth/BatteryMonitor.swift | バッテリー監視 (Actor) | OK |
| Network/NetworkManager.swift | ネットワーク管理 (Actor) | OK |
| Network/NetworkProtocols.swift | ネットワークプロトコル定義 | OK |
| Network/MessageProtocol.swift | メッセージフレーミング | OK |
| Network/PeerBrowser.swift | Bonjour ピア検出 (Actor) | OK |
| Network/PeerConnection.swift | ピア接続管理 (Actor) | セキュリティ問題 |
| Network/PeerListener.swift | ピアリスナー (Actor) | セキュリティ問題 |
| Service/SwitchService.swift | 切り替えオーケストレーション (Actor) | 問題あり |
| Service/DeviceDiscoveryService.swift | デバイス検出 (Actor) | OK |
| Storage/ConfigStore.swift | 設定永続化 (Actor) | OK |
| Models/MagicDevice.swift | デバイスモデル | OK |
| Models/HostMac.swift | ホストモデル | OK |
| Models/AppConfig.swift | 設定モデル | OK |
| Models/SwitchCommand.swift | 通信メッセージモデル | OK |
| Common/ErrorTypes.swift | エラー型定義 | OK |
| Common/MagicSwitchLogger.swift | ロギング | OK |
| Common/NotificationManager.swift | 通知管理 (Actor) | OK |

### 4.2 アーキテクチャ準拠性

| 設計項目 | 準拠状況 | 備考 |
|---------|---------|------|
| MVVM パターン | **PASS** | Presentation → ViewModel → Service → Core の依存方向が正しい |
| Actor パターン | **PASS** | BluetoothManager, NetworkManager, SwitchService 等すべて Actor |
| Service Layer | **PASS** | SwitchService, DeviceDiscoveryService が適切に分離 |
| Protocol 抽象化 | **PASS** | BluetoothDeviceDiscovering, BluetoothDeviceConnecting 等 |
| DI パターン | **PASS** | DependencyContainer によるサービス注入 |
| Swift Concurrency | **PASS** | async/await, Actor, Task を全面採用 |

### 4.3 コーディング品質

| 項目 | 評価 | 備考 |
|------|------|------|
| ハードコードされた秘密情報 | **PASS** | password, secret, token 等なし |
| TODO/FIXME コメント | **PASS** | 残存なし |
| 命名規則 | **PASS** | Swift の命名規則に準拠 |
| エラーハンドリング | **部分的** | 一部で `try?` による無視あり |
| ログ出力 | **PASS** | swift-log による適切なログ出力 |
| コマンドインジェクション | **PASS** | BlueUtilWrapper は引数配列方式で安全 |

---

## 5. 要件適合性チェック結果

### 5.1 機能要件 (FR) 実装状況

| 要件ID | 要件名 | 実装状況 | 評価 | 備考 |
|--------|--------|---------|------|------|
| FR-001 | デバイス検出・一覧表示 | 実装済み | **PASS** | IOBluetoothAdapter + MagicDeviceIdentifier で検出。DeviceRowView で表示 |
| FR-002 | 接続先Mac登録・管理 | 実装済み | **PASS** | HostMac モデル + ConfigStore。最大3台制限あり |
| FR-003 | デバイスと接続先の紐付け | 部分実装 | **WARN** | SwitchProfile モデル定義あるが、UI での紐付け機能は未実装 |
| FR-004 | ワンクリック切り替え | 実装済み | **PASS** | MenuBarController から SwitchService 経由で切り替え |
| FR-005 | キーボードショートカット | 部分実装 | **WARN** | KeyboardShortcuts 依存あるが、ショートカット設定 UI は未接続 |
| FR-006 | 切り替え時のフィードバック | 実装済み | **PASS** | NotificationManager で成功/失敗通知。メニューバーアイコン変化 |
| FR-007 | 接続状態表示 | 実装済み | **PASS** | MenuBarController でアイコン状態変化 |
| FR-008 | バッテリー残量表示 | 実装済み | **PASS** | BatteryMonitor + DeviceRowView で表示 |
| FR-009 | メニューバー常駐 | 実装済み | **PASS** | NSStatusItem + LSUIElement=true |
| FR-010 | 設定画面 | 実装済み | **PASS** | SettingsView (SwiftUI TabView) |
| FR-011 | セットアップウィザード | 実装済み | **FAIL** | View/ViewModel 実装あるが、初回起動時に表示されない (未接続) |
| FR-012 | Mac間通信 | 実装済み | **PASS** | Network.framework + Bonjour + カスタムプロトコル |
| FR-013 | Mac自動検出 | 実装済み | **PASS** | PeerBrowser (Bonjour NWBrowser) |

### 5.2 機能要件の詳細所見

**FR-003 (デバイスと接続先の紐付け)**: `SwitchProfile` モデルは AppConfig.swift に定義されているが、UI での利用やデバイスごとの優先順位設定機能は未実装。現状はホスト単位の一括切り替えのみ。

**FR-005 (キーボードショートカット)**: `KeyboardShortcuts` ライブラリが依存に含まれており、`ShortcutDefinition` モデルも定義されているが、設定画面でのショートカット設定 UI とグローバルショートカットの登録処理が未接続。

**FR-011 (セットアップウィザード)**: `SetupWizardView` と `SetupWizardViewModel` は完全に実装されているが、`MagicSwitchApp.swift` の `showSetupWizard` プロパティが未使用のまま。初回起動判定ロジックが欠如しており、ウィザードは表示されない。

---

## 6. 非機能要件チェック結果

| 要件ID | 要件名 | 実装状況 | 評価 | 備考 |
|--------|--------|---------|------|------|
| NFR-001 | macOS 13+ 対応 | 実装済み | **PASS** | Package.swift: `.macOS(.v13)`, Info.plist: LSMinimumSystemVersion "13.0" |
| NFR-002 | 対応デバイス | 実装済み | **PASS** | MagicDeviceIdentifier で全世代の Product ID 定義 |
| NFR-003 | 切り替え時間 | 実装済み | **PASS** | タイムアウト 15秒設定。リトライ最大3回 |
| NFR-004 | リソース使用量 | コード上の配慮 | **PASS** | Actor による軽量な並行処理。ポーリング間隔 60秒 |
| NFR-005 | 通信セキュリティ (TLS) | 部分実装 | **FAIL** | TLS 1.3 コード存在するが、証明書検証が無効化 (後述) |
| NFR-006 | データ保護 | 実装済み | **PASS** | ローカル JSON ファイル保存。外部送信なし |
| NFR-007 | エラーハンドリング | 実装済み | **PASS** | MagicSwitchError で包括的なエラー定義。リトライポリシー実装 |
| NFR-008 | ログ出力 | 実装済み | **PASS** | swift-log でカテゴリ別ログ。ただしファイル出力は未実装 |

### 6.1 NFR-005 通信セキュリティの重大な問題

**PeerConnection.swift (Line 257)** および **PeerListener.swift (Line 134)** で TLS 証明書検証が完全に無効化されている:

```swift
sec_protocol_options_set_verify_block(
    tlsOptions.securityProtocolOptions,
    { _, trust, completionHandler in
        completionHandler(true)  // すべての証明書を無条件に受け入れ
    },
    .main
)
```

この実装では、中間者攻撃 (MITM) に対して脆弱であり、NFR-005 の「Mac 間の通信は暗号化する（TLS またはそれに準ずる方式）」および「認証されていない Mac からの切り替えリクエストを拒否する」の要件を満たしていない。

### 6.2 NFR-008 ログ出力の制限事項

- ファイル出力が未実装 (設計書では `~/Library/Logs/MagicSwitch/` への出力を要件としている)
- StreamLogHandler (stdout) のみ使用
- ログローテーション未実装

---

## 7. セキュリティチェック結果

| チェック項目 | 結果 | 重大度 | 備考 |
|------------|------|--------|------|
| ハードコードされた秘密情報 | **PASS** | - | password, secret, token, apikey 等なし |
| コマンドインジェクション | **PASS** | - | BlueUtilWrapper は引数配列方式で安全 |
| TLS 証明書検証 | **FAIL** | **Critical** | `completionHandler(true)` で全証明書受け入れ |
| 入力バリデーション | **WARN** | Medium | ホスト名、Bluetooth アドレスの検証なし |
| 権限チェック | **FAIL** | High | SetupWizard の権限チェックがダミー実装 |
| データ暗号化 | **WARN** | Low | 設定ファイルが平文 JSON (Keychain 未使用) |
| エラーメッセージ情報漏洩 | **PASS** | - | MAC アドレス等の機密情報は漏洩していない |

### 7.1 セキュリティ問題の詳細

#### SEC-001: TLS 証明書検証の無効化 [Critical]
- **場所**: `PeerConnection.swift:257`, `PeerListener.swift:134`
- **影響**: 中間者攻撃により、切り替えコマンドの傍受・改ざんが可能
- **修正提案**: 初回ペアリング時に交換した証明書をピン留め (Certificate Pinning) し、以降の接続で検証する

#### SEC-002: 権限チェックのダミー実装 [High]
- **場所**: `SetupWizardViewModel.swift` の `checkPermissions()`
- **影響**: Bluetooth, Accessibility, Local Network の権限が実際に確認されない
- **修正提案**: macOS の TCC API を使用して実際の権限状態を確認する

#### SEC-003: 入力バリデーション不足 [Medium]
- **場所**: `SettingsView.swift` (ホスト追加), `HostMac.swift`
- **影響**: 不正なホスト名やラベルが保存される可能性
- **修正提案**: ホスト名の形式検証、ラベルの長さ制限を追加

---

## 8. Homebrew 配布チェック結果

### 8.1 Cask 定義

| 項目 | 結果 | 備考 |
|------|------|------|
| Cask ファイル存在 | **PASS** | `homebrew/magic-switch.rb` |
| バージョン定義 | **PASS** | `version "1.0.0"` |
| SHA256 | **WARN** | `sha256 :no_check` - リリース時に要更新 |
| ダウンロード URL | **PASS** | GitHub Releases 形式 |
| depends_on | **PASS** | `macos: ">= :ventura"` |
| app 定義 | **PASS** | `app "MagicSwitch.app"` |
| postflight | **PASS** | blueutil 実行権限付与 |
| uninstall | **PASS** | quit で停止 |
| zap | **PASS** | Application Support, Logs, Preferences 削除 |

### 8.2 ビルドスクリプト

| 項目 | 結果 | 備考 |
|------|------|------|
| `scripts/build.sh` | **PASS** | .app バンドル作成、Info.plist 配置 |
| `scripts/sign-and-notarize.sh` | **欠如** | 設計書にあるが未作成 |
| `scripts/create-dmg.sh` | **欠如** | 設計書にあるが未作成 |
| `scripts/update-cask.sh` | **欠如** | 設計書にあるが未作成 |

---

## 9. 発見されたバグ・問題点

### 9.1 重大度: Critical

| ID | 問題 | 場所 | 影響 |
|----|------|------|------|
| BUG-C01 | TLS 証明書検証が無効化 | PeerConnection.swift:257, PeerListener.swift:134 | MITM 攻撃に脆弱。セキュリティ要件 NFR-005 違反 |

### 9.2 重大度: High

| ID | 問題 | 場所 | 影響 |
|----|------|------|------|
| BUG-H01 | セットアップウィザードが表示されない | MagicSwitchApp.swift | FR-011 未達成。初回ユーザーが設定不可 |
| BUG-H02 | 権限チェックがダミー実装 | SetupWizardViewModel.swift:95-96 | 権限未付与でも正常動作と誤認 |
| BUG-H03 | SwitchService の切り替え検証不足 | SwitchService.swift:182 | タイムアウト待機のみで実際の成功確認なし |
| BUG-H04 | テストターゲット依存関係エラー | Package.swift (修正済み) | MagicSwitchTests が executable に依存 |

### 9.3 重大度: Medium

| ID | 問題 | 場所 | 影響 |
|----|------|------|------|
| BUG-M01 | キーボードショートカット UI 未接続 | SettingsView.swift, AppDelegate.swift | FR-005 部分未達成 |
| BUG-M02 | ホスト追加時の入力バリデーションなし | SettingsView.swift:194 | 空文字列やホスト名形式不正を許容 |
| BUG-M03 | ログファイル出力未実装 | MagicSwitchLogger.swift | NFR-008 部分未達成 |
| BUG-M04 | エラーメッセージがクリアされない | MenuBarViewModel.swift | 前回のエラーが残り続ける |
| BUG-M05 | 設定保存の競合状態 | SettingsViewModel.swift | 複数同時保存で最終書き込みが上書き |
| BUG-M06 | ホスト削除に確認ダイアログなし | HostRowView.swift:49 | 誤操作で即削除 |
| BUG-M07 | IOBluetoothAdapter の @unchecked Sendable | IOBluetoothAdapter.swift:52 | スレッド安全性が保証されない |
| BUG-M08 | SwitchProfile モデル未活用 | AppConfig.swift | デバイス個別の切り替えプロファイルが機能しない |
| BUG-M09 | SwitchService で一時 MagicDevice 生成 | SwitchService.swift:213 | デバイス名が "Device-{address}" になる |

### 9.4 重大度: Low

| ID | 問題 | 場所 | 影響 |
|----|------|------|------|
| BUG-L01 | 通知エラーの無視 | NotificationManager.swift:31,47,62 | `try?` で通知失敗を無視 |
| BUG-L02 | バッテリー値の範囲検証なし | MagicDevice.swift | 0-100 外の値を許容 |
| BUG-L03 | ローカライズ未対応 | 全 UI ファイル | 日本語ハードコード |
| BUG-L04 | blueutil バイナリ未同梱 | Resources/ | blueutil バイナリが未配置 |
| BUG-L05 | 署名・公証スクリプト未作成 | scripts/ | 配布に必要なスクリプトが欠如 |

---

## 10. 改善提案

### 10.1 最優先 (リリースブロッカー)

1. **TLS 証明書検証を実装する**: Certificate Pinning を導入し、初回ペアリング時に交換した証明書を Keychain に保存して以降の接続で検証する
2. **セットアップウィザードを初回起動時に表示する**: `AppDelegate.applicationDidFinishLaunching` で初回起動判定を行い、ウィザードを表示する
3. **権限チェックを実装する**: macOS の TCC API または各フレームワークの権限確認メソッドを使用して実際の権限状態を確認する
4. **SwitchService に切り替え完了の確認応答を実装する**: ターゲット Mac からの ACK/Result メッセージを待機して成功を検証する

### 10.2 高優先度

5. **キーボードショートカット機能を接続する**: KeyboardShortcuts ライブラリを活用してグローバルショートカットの登録・実行を実装する
6. **入力バリデーションを追加する**: ホスト名、ラベル、Bluetooth アドレスの形式検証を実装する
7. **ログファイル出力を実装する**: `~/Library/Logs/MagicSwitch/` へのファイル出力とログローテーションを実装する
8. **テストカバレッジを拡充する**: Service 層、ViewModel 層のユニットテストを追加する。モック実装を作成する
9. **blueutil バイナリを Resources に同梱する**: ビルド済みバイナリをバンドルに含める

### 10.3 中優先度

10. **ホスト削除に確認ダイアログを追加する**
11. **エラーメッセージのクリア処理を追加する**
12. **ConfigStore に同時書き込み保護を追加する**
13. **署名・公証スクリプトを作成する**
14. **SwitchProfile によるデバイス個別切り替えを実装する**

---

## 11. 総合判定

### 判定: **条件付きリリース不可 (要修正)**

| 評価項目 | 判定 | 理由 |
|---------|------|------|
| ビルド | **PASS** | デバッグ/リリースビルド共に成功 |
| アーキテクチャ | **PASS** | 設計書に準拠した MVVM + Service + Actor 構成 |
| コア機能 (BT/Network) | **PASS** | デバイス検出、ネットワーク通信、切り替えロジック実装済み |
| UI | **PASS (部分)** | メニューバー、設定画面実装済み。ウィザード未接続 |
| セキュリティ | **FAIL** | TLS 証明書検証無効化、権限チェックダミー |
| テスト | **FAIL** | テストカバレッジ不十分、環境制約で実行不可 |
| 配布準備 | **WARN** | Cask 定義あるが、署名・公証スクリプト未作成 |

### リリース可否

**現時点でのリリースは推奨しない**。以下の修正が完了した後に再テストを実施し、リリース判定を行うべきである:

1. TLS 証明書検証の実装 (BUG-C01)
2. セットアップウィザードの接続 (BUG-H01)
3. 権限チェックの実装 (BUG-H02)
4. 切り替え完了確認の実装 (BUG-H03)
5. ユニットテストの拡充と実行環境の整備

上記 Critical/High バグ 5件の修正後、再テストを実施すること。

---

## 改訂履歴

| 日付 | バージョン | 変更内容 |
|------|-----------|---------|
| 2026-02-23 | 1.0 | 初版作成 |
