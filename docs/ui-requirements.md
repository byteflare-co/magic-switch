# Magic Switch UI/UX モダン化 要件定義書

## 概要

Magic Switch のUI/UXを、モダンなmacOSメニューバーアプリ（Bartender, Hand Mirror, Ice, One Switch, Raycast 等）の水準に引き上げるための改善要件を定義する。

**対象バージョン**: macOS 13 (Ventura) 以降
**UIフレームワーク**: SwiftUI + AppKit (NSPopover, NSStatusItem)
**既存依存**: KeyboardShortcuts 2.0.0, LaunchAtLogin-Modern 1.0.0+

---

## 現状分析

### 現在のアーキテクチャ

| コンポーネント | 現在の実装 | 問題点 |
|---|---|---|
| メニューバー | `NSMenu` ベースの `MenuBarController` | テキストのみ、ビジュアル情報なし |
| デバイス表示 | `NSMenuItem` に絵文字テキスト (`⌨`, `🔲`) | リッチなUI不可、バッテリー表示が貧弱 |
| ホスト切り替え | 左クリック=即切り替え（フィードバックなし） | 操作確認なし、進捗不明、結果不明 |
| 右クリックメニュー | `NSMenu` でデバイス情報+ホスト一覧+設定+終了 | 情報と操作が混在、視認性が低い |
| 設定画面 | SwiftUI `TabView` (500x400) | 基本的だが古いスタイル |
| セットアップ | SwiftUI `ProgressView` + ステップ切り替え | アニメーションなし、視覚的に地味 |

### 現在のファイル構成

```
Sources/MagicSwitch/
├── Presentation/
│   ├── MenuBarController.swift    # NSMenu ベース → 全面書き換え
│   ├── DeviceRowView.swift        # SwiftUI → 拡張・改善
│   ├── HostRowView.swift          # SwiftUI → 拡張・改善
│   ├── SettingsView.swift         # SwiftUI TabView → Settings風に改善
│   └── SetupWizardView.swift      # SwiftUI → アニメーション追加
└── ViewModel/
    ├── MenuBarViewModel.swift     # ポップオーバー対応に拡張
    ├── SettingsViewModel.swift    # 変更なし
    └── SetupWizardViewModel.swift # 変更なし
```

---

## 改善要件

### 1. メニューバーポップオーバー化

**優先度**: 最高 (P0)
**影響ファイル**: `MenuBarController.swift` (全面書き換え), 新規 `PopoverContentView.swift`

#### 現状
- `NSMenu` でテキストベースのメニューを構築
- 左クリック: `switchToFirstOnlineHost()` を即実行（UIフィードバックなし）
- 右クリック: `buildMenu()` でコンテキストメニューを表示

#### 改善内容

**UXフローの変更**:
- **左クリック**: SwiftUI ベースのリッチなポップオーバーを表示
- **右クリック**: シンプルなコンテキストメニュー（設定、終了のみ）

**実装方針**:

```swift
// MenuBarController.swift - NSPopover ベースに書き換え
@MainActor
final class MenuBarController: NSObject {
    private var statusItem: NSStatusItem!
    private let popover: NSPopover
    private let viewModel: MenuBarViewModel

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        // ポップオーバーの設定
        popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 420)
        popover.behavior = .transient  // 外クリックで自動クローズ
        popover.animates = true
        popover.contentViewController = NSHostingController(
            rootView: PopoverContentView(viewModel: viewModel)
        )

        // 左クリック: ポップオーバー表示
        button.action = #selector(togglePopover)
        button.sendAction(on: [.leftMouseUp])

        // 右クリック: コンテキストメニュー（設定・終了のみ）
        // 既存のイベントモニター方式を維持
    }

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            if let button = statusItem.button {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                // ポップオーバー表示時にデータをリフレッシュ
                viewModel.refresh()
            }
        }
    }
}
```

**右クリックメニューの簡素化**:
```swift
private func buildContextMenu() -> NSMenu {
    let menu = NSMenu()
    menu.addItem(NSMenuItem(title: "設定...", action: #selector(openSettings), keyEquivalent: ","))
    menu.addItem(.separator())
    menu.addItem(NSMenuItem(title: "終了", action: #selector(quit), keyEquivalent: "q"))
    return menu
}
```

---

### 2. ポップオーバーコンテンツ（新規作成）

**優先度**: 最高 (P0)
**新規ファイル**: `PopoverContentView.swift`

#### 実装方針

```swift
// PopoverContentView.swift
struct PopoverContentView: View {
    @ObservedObject var viewModel: MenuBarViewModel

    var body: some View {
        VStack(spacing: 0) {
            // ヘッダー
            PopoverHeaderView()

            Divider()

            ScrollView {
                VStack(spacing: 12) {
                    // デバイスセクション
                    DeviceSectionView(devices: viewModel.connectedDevices)

                    Divider().padding(.horizontal)

                    // ホスト切り替えセクション
                    HostSwitchSectionView(
                        hosts: viewModel.hosts,
                        currentHostId: viewModel.currentHostId,
                        isSwitching: viewModel.isSwitching,
                        switchResult: viewModel.switchResult,
                        onSwitch: { host in viewModel.switchTo(host: host) }
                    )
                }
                .padding()
            }

            // エラー/成功バナー
            if let result = viewModel.switchResult {
                SwitchResultBanner(result: result)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(width: 320)
        .background(.ultraThinMaterial)  // vibrancy 効果
    }
}
```

**ポップオーバーのデザイン仕様**:
- 幅: 320pt
- 最大高: 420pt（コンテンツに応じて可変）
- 背景: `.ultraThinMaterial`（macOS の vibrancy 効果）
- 角丸: NSPopover 標準（自動適用）
- フォント: SF Pro（システム標準）

---

### 3. デバイスカードUI

**優先度**: 高 (P1)
**影響ファイル**: `DeviceRowView.swift` (改善)

#### 現状
- SF Symbols アイコン、接続状態カラードット、バッテリーインジケーターは既に実装済み
- ただしポップオーバーではなく設定画面内でのみ使用

#### 改善内容

**ポップオーバー用のカードスタイルに拡張**:

```swift
// DeviceCardView.swift（ポップオーバー内で使用するカード版）
struct DeviceCardView: View {
    let device: MagicDevice

    var body: some View {
        HStack(spacing: 12) {
            // デバイスアイコン（SF Symbols）
            Image(systemName: device.type == .keyboard ? "keyboard.fill" : "trackpad.fill")
                .font(.title2)
                .foregroundStyle(device.isConnected ? .primary : .secondary)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.quaternary)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(.system(.body, weight: .medium))

                HStack(spacing: 4) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 6, height: 6)
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // バッテリーインジケーター（改善版）
            if let battery = device.batteryLevel {
                BatteryGauge(level: battery)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.background.opacity(0.6))
        )
    }
}

// バッテリーゲージ（プログレスバー版）
struct BatteryGauge: View {
    let level: Int

    var body: some View {
        HStack(spacing: 4) {
            // ミニプログレスバー
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.quaternary)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(batteryColor)
                        .frame(width: geo.size.width * CGFloat(level) / 100)
                }
            }
            .frame(width: 24, height: 8)

            Text("\(level)%")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}
```

**変更点**:
- `.fill` アイコン（`keyboard.fill`, `trackpad.fill`）で視認性向上
- カード背景に `RoundedRectangle` + 半透明背景
- バッテリーにミニプログレスバーを追加
- フォントウェイトの調整（名前を `.medium` に）
- 既存の `DeviceRowView` は設定画面で引き続き使用（互換性維持）

---

### 4. ホスト切り替えUI

**優先度**: 最高 (P0)
**新規ファイル**: `HostSwitchSectionView.swift`
**影響ファイル**: `MenuBarViewModel.swift` (拡張)

#### 現状
- 左クリックで `switchToFirstOnlineHost()` が即実行される
- ユーザーに切り替え先の選択肢や進捗・結果のフィードバックがない
- `isSwitching` で `keyboard.badge.ellipsis` アイコンに変えるのみ

#### 改善内容

**ViewModel の拡張**:
```swift
// MenuBarViewModel.swift に追加
public enum SwitchResult: Equatable {
    case success(hostLabel: String)
    case failure(message: String)
}

@Published public var switchResult: SwitchResult?

public func switchTo(host: HostMac) {
    guard !isSwitching else { return }
    isSwitching = true
    switchResult = nil

    Task {
        do {
            try await switchService.switchAllDevices(to: host)
            self.currentHostId = host.id
            self.switchResult = .success(hostLabel: host.label)
            self.refresh()
        } catch {
            self.switchResult = .failure(message: error.localizedDescription)
        }
        self.isSwitching = false

        // 3秒後に結果バナーを自動非表示
        try? await Task.sleep(for: .seconds(3))
        self.switchResult = nil
    }
}
```

**ホスト切り替えセクション**:
```swift
struct HostSwitchSectionView: View {
    let hosts: [HostMac]
    let currentHostId: UUID?
    let isSwitching: Bool
    let switchResult: MenuBarViewModel.SwitchResult?
    let onSwitch: (HostMac) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("切り替え先")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            ForEach(hosts) { host in
                HostSwitchCard(
                    host: host,
                    isCurrent: host.id == currentHostId,
                    isSwitching: isSwitching,
                    onSwitch: { onSwitch(host) }
                )
            }
        }
    }
}

struct HostSwitchCard: View {
    let host: HostMac
    let isCurrent: Bool
    let isSwitching: Bool
    let onSwitch: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "desktopcomputer")
                .font(.title3)
                .foregroundStyle(host.isOnline ? .primary : .secondary)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(host.label)
                        .font(.system(.body, weight: .medium))
                    if isCurrent {
                        Text("(現在)")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }
                HStack(spacing: 4) {
                    Circle()
                        .fill(host.isOnline ? Color.green : Color.gray)
                        .frame(width: 6, height: 6)
                    Text(host.isOnline ? "オンライン" : "オフライン")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // 切り替えボタン
            if isSwitching {
                ProgressView()
                    .controlSize(.small)
            } else if host.isOnline && !isCurrent {
                Button(action: onSwitch) {
                    Text("切替")
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(.blue)
                        )
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isCurrent ? Color.accentColor.opacity(0.08) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isCurrent ? Color.accentColor.opacity(0.2) : Color.clear, lineWidth: 1)
        )
    }
}
```

**切り替え結果バナー**:
```swift
struct SwitchResultBanner: View {
    let result: MenuBarViewModel.SwitchResult

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
            Text(message)
                .font(.caption)
        }
        .foregroundStyle(isSuccess ? .green : .red)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(
            (isSuccess ? Color.green : Color.red).opacity(0.1)
        )
        .animation(.easeInOut(duration: 0.3), value: result)
    }

    private var isSuccess: Bool {
        if case .success = result { return true }
        return false
    }

    private var message: String {
        switch result {
        case .success(let label): return "\(label) に切り替えました"
        case .failure(let msg): return "切り替え失敗: \(msg)"
        }
    }
}
```

---

### 5. セットアップウィザード改善

**優先度**: 中 (P2)
**影響ファイル**: `SetupWizardView.swift`

#### 現状
- 基本的な `ProgressView` と手動 `switch` 文でのステップ切り替え
- アニメーションなし、遷移が瞬時

#### 改善内容

**ステップインジケーターの改善**:
```swift
// カスタムステップインジケーター
struct StepIndicator: View {
    let currentStep: Int
    let totalSteps: Int
    let stepLabels: [String]  // ["権限", "デバイス", "接続先", "完了"]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<totalSteps, id: \.self) { index in
                HStack(spacing: 0) {
                    // ドット
                    ZStack {
                        Circle()
                            .fill(index < currentStep ? Color.accentColor : Color.secondary.opacity(0.3))
                            .frame(width: 24, height: 24)

                        if index < currentStep {
                            Image(systemName: "checkmark")
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                        } else {
                            Text("\(index + 1)")
                                .font(.caption2)
                                .foregroundStyle(index == currentStep ? .primary : .secondary)
                        }
                    }

                    // ラベル
                    Text(stepLabels[index])
                        .font(.caption2)
                        .foregroundStyle(index <= currentStep ? .primary : .secondary)
                        .padding(.leading, 4)

                    // コネクター線（最後以外）
                    if index < totalSteps - 1 {
                        Rectangle()
                            .fill(index < currentStep ? Color.accentColor : Color.secondary.opacity(0.3))
                            .frame(height: 1)
                            .padding(.horizontal, 8)
                    }
                }
            }
        }
        .padding()
    }
}
```

**アニメーションのあるトランジション**:
```swift
// SetupWizardView のステップ切り替え部分
Group {
    switch viewModel.currentStep {
    case .permissions:
        PermissionsStepView(viewModel: viewModel)
    case .deviceSelection:
        DeviceSelectionStepView(viewModel: viewModel)
    case .hostRegistration:
        HostRegistrationStepView(viewModel: viewModel)
    case .completion:
        CompletionStepView()
    }
}
.transition(.asymmetric(
    insertion: .move(edge: .trailing).combined(with: .opacity),
    removal: .move(edge: .leading).combined(with: .opacity)
))
.animation(.spring(response: 0.4, dampingFraction: 0.85), value: viewModel.currentStep)
```

**各ステップのアイコン大型化**:
- 権限画面: 各権限行のアイコンを `.font(.title2)` に
- デバイス選択: ヘッダーに大きなデバイスイラスト
- 完了画面: チェックマークアニメーション追加

**完了画面のアニメーション**:
```swift
struct CompletionStepView: View {
    @State private var showCheck = false
    @State private var showText = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.green)
                .scaleEffect(showCheck ? 1.0 : 0.3)
                .opacity(showCheck ? 1.0 : 0.0)
                .animation(.spring(response: 0.5, dampingFraction: 0.6), value: showCheck)

            VStack(spacing: 8) {
                Text("セットアップ完了")
                    .font(.title)
                    .bold()
                Text("Magic Switch の準備ができました。\nメニューバーからデバイスの切り替えが行えます。")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .opacity(showText ? 1.0 : 0.0)
            .offset(y: showText ? 0 : 10)
            .animation(.easeOut(duration: 0.4).delay(0.3), value: showText)

            Spacer()
        }
        .padding()
        .onAppear {
            showCheck = true
            showText = true
        }
    }
}
```

---

### 6. 設定画面の改善

**優先度**: 中 (P2)
**影響ファイル**: `SettingsView.swift`

#### 現状
- 標準の `TabView` + `Form`
- セクション分けは基本的だが macOS Settings 風ではない

#### 改善内容

**macOS Ventura Settings 風レイアウト**:
```swift
struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        TabView {
            GeneralTab(viewModel: viewModel)
                .tabItem { Label("一般", systemImage: "gear") }

            DevicesTab(viewModel: viewModel)
                .tabItem { Label("デバイス", systemImage: "keyboard") }

            HostsTab(viewModel: viewModel)
                .tabItem { Label("接続先", systemImage: "desktopcomputer") }

            ShortcutsTab()
                .tabItem { Label("ショートカット", systemImage: "command") }

            AboutTab()
                .tabItem { Label("情報", systemImage: "info.circle") }
        }
        .frame(width: 520, height: 440)
        .onAppear { viewModel.loadAll() }
    }
}
```

**GeneralTab の改善（Form + LabeledContent）**:
```swift
struct GeneralTab: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section("起動") {
                Toggle("ログイン時に自動起動", isOn: $viewModel.config.launchAtLogin)
            }

            Section("通知") {
                Toggle("通知を表示", isOn: $viewModel.config.showNotifications)

                LabeledContent("バッテリー低下通知") {
                    Picker("", selection: $viewModel.config.lowBatteryThreshold) {
                        Text("10%").tag(10)
                        Text("15%").tag(15)
                        Text("20%").tag(20)
                        Text("25%").tag(25)
                        Text("30%").tag(30)
                    }
                    .frame(width: 100)
                }
            }

            Section("詳細") {
                LabeledContent("ログレベル") {
                    Picker("", selection: $viewModel.config.logLevel) {
                        ForEach(LogLevel.allCases, id: \.self) { level in
                            Text(level.rawValue.uppercased()).tag(level)
                        }
                    }
                    .frame(width: 120)
                }
            }
        }
        .formStyle(.grouped)
        .onChange(of: viewModel.config) { _ in
            viewModel.saveConfig()
        }
    }
}
```

**改善点の詳細**:
- `Form` に `.formStyle(.grouped)` を適用して macOS Settings 風に
- `LabeledContent` を使用して統一されたラベル＋コントロール配置
- 明示的な「保存」ボタンを廃止 → `onChange` による自動保存
- セクションに見出し文字列を追加（`Section("起動")`）
- ウィンドウサイズを微調整（520x440）

---

### 7. ビジュアル・アニメーション統一

**優先度**: 中 (P2)
**新規ファイル**: `Theme.swift`（カラーパレット等の定数定義）

#### 改善内容

**カラーパレット定義**:
```swift
// Theme.swift
enum MagicSwitchTheme {
    // ステータスカラー
    static let online = Color.green
    static let offline = Color.gray
    static let connecting = Color.orange
    static let error = Color.red
    static let success = Color.green

    // バッテリーカラー
    static func batteryColor(for level: Int) -> Color {
        switch level {
        case ...20: return .red
        case 21...40: return .orange
        default: return .green
        }
    }

    // カード背景
    static let cardBackground = Color(.controlBackgroundColor).opacity(0.6)

    // アニメーション
    static let springAnimation = Animation.spring(response: 0.4, dampingFraction: 0.8)
    static let easeAnimation = Animation.easeInOut(duration: 0.25)
}
```

**メニューバーアイコンの状態変化**:
```swift
// MenuBarController.swift - アイコンの状態遷移
private func updateIcon(isSwitching: Bool) {
    let symbolName: String
    if isSwitching {
        symbolName = "keyboard.badge.ellipsis"
    } else if viewModel.connectedDevices.isEmpty {
        symbolName = "keyboard"  // 通常状態
    } else {
        symbolName = "keyboard.fill"  // デバイス接続中
    }

    statusItem.button?.image = NSImage(
        systemSymbolName: symbolName,
        accessibilityDescription: "Magic Switch"
    )
}
```

**ダークモード対応**:
- `.background(.ultraThinMaterial)` 等のシステムマテリアルを使用（自動対応）
- `Color(.controlBackgroundColor)` 等のセマンティックカラーを使用
- `.foregroundStyle(.primary)`, `.secondary`, `.tertiary` を活用
- ハードコードされた色を避け、全てシステムカラーまたはテーマ定数を使用

---

### 8. UXフロー変更まとめ

**優先度**: 最高 (P0)

| 操作 | 現在 | 改善後 |
|---|---|---|
| 左クリック | 最初のオンラインホストに即切り替え | ポップオーバーを表示 |
| 右クリック | NSMenu（デバイス情報+ホスト+設定+終了） | シンプルなコンテキストメニュー（設定、終了のみ） |
| ポップオーバー外クリック | N/A | 自動クローズ（`.transient`） |
| デバイス確認 | 右クリックメニュー内（テキスト） | ポップオーバー内（カードUI） |
| ホスト切り替え | 左クリック即実行 / 右クリックメニューから選択 | ポップオーバー内のボタンクリック |
| 切り替え中 | アイコンのみ変化 | ポップオーバー内にプログレス表示 + アイコン変化 |
| 切り替え結果 | なし | 成功/失敗バナー（3秒で自動非表示） |

---

## 新規ファイル一覧

| ファイル | 配置先 | 説明 |
|---|---|---|
| `PopoverContentView.swift` | Presentation/ | ポップオーバーのメインコンテンツ |
| `DeviceCardView.swift` | Presentation/ | ポップオーバー用デバイスカード |
| `DeviceSectionView.swift` | Presentation/ | デバイスセクション（ヘッダー+カード一覧） |
| `HostSwitchSectionView.swift` | Presentation/ | ホスト切り替えセクション |
| `HostSwitchCard.swift` | Presentation/ | 切り替え先ホストカード |
| `SwitchResultBanner.swift` | Presentation/ | 切り替え結果バナー |
| `StepIndicator.swift` | Presentation/ | セットアップウィザードのステップインジケーター |
| `Theme.swift` | Presentation/ | テーマ定数（カラー、アニメーション） |

## 変更ファイル一覧

| ファイル | 変更内容 |
|---|---|
| `MenuBarController.swift` | NSMenu → NSPopover ベースに全面書き換え |
| `MenuBarViewModel.swift` | `SwitchResult` 追加、`switchTo()` のフィードバック対応 |
| `SetupWizardView.swift` | ステップインジケーター改善、トランジションアニメーション追加、完了画面アニメーション |
| `SettingsView.swift` | `.formStyle(.grouped)` 適用、`LabeledContent` 使用、自動保存化 |
| `DeviceRowView.swift` | 既存は維持（設定画面用）、`BatteryIndicator` を `BatteryGauge` と共通化検討 |

## 変更しないファイル

| ファイル | 理由 |
|---|---|
| `HostRowView.swift` | 設定画面用としてそのまま使用 |
| `SettingsViewModel.swift` | ロジック変更不要 |
| `SetupWizardViewModel.swift` | ロジック変更不要 |

---

## 実装の優先順位

### Phase 1 (P0): コア体験の改善
1. `Theme.swift` の作成（他のファイルから参照するため最初に）
2. `MenuBarController.swift` の NSPopover 化
3. `PopoverContentView.swift` の作成
4. `DeviceCardView.swift` / `DeviceSectionView.swift` の作成
5. `HostSwitchSectionView.swift` / `HostSwitchCard.swift` の作成
6. `SwitchResultBanner.swift` の作成
7. `MenuBarViewModel.swift` の `SwitchResult` 対応

### Phase 2 (P2): 設定・ウィザード改善
8. `SettingsView.swift` の Settings 風改善
9. `StepIndicator.swift` の作成
10. `SetupWizardView.swift` のアニメーション改善

---

## 技術的制約・注意事項

1. **macOS 13 以上**: `.formStyle(.grouped)` は macOS 13+ で利用可能（対応済み）
2. **NSPopover + SwiftUI**: `NSHostingController` でラップして使用。`@ObservedObject` の更新が正しく伝播することを確認
3. **スレッドセーフティ**: `MenuBarViewModel` は `@MainActor`。ポップオーバー内の SwiftUI View は自動的にメインスレッドで描画
4. **KeyboardShortcuts 2.0.0 互換**: ショートカット機能に変更なし
5. **メモリ**: ポップオーバーを閉じた後もインスタンスは保持（`NSPopover` のライフサイクル）。大きなリソースは不要
6. **`popover.behavior = .transient`**: ポップオーバー外のクリックで自動クローズ。ユーザーが別のアプリをクリックしても閉じる
