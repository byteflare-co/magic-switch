import SwiftUI
import KeyboardShortcuts
import MagicSwitchCore

/// 設定画面ルート
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
        .onAppear {
            viewModel.loadAll()
        }
    }
}

// MARK: - General Tab

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

// MARK: - Devices Tab

struct DevicesTab: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("検出済みデバイス")
                    .font(.headline)
                Spacer()
                Button(action: { viewModel.refreshDevices() }) {
                    if viewModel.isDiscoveringDevices {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(viewModel.isDiscoveringDevices)
            }

            if viewModel.devices.isEmpty {
                VStack {
                    Spacer()
                    Text("Magic デバイスが見つかりません")
                        .foregroundStyle(.secondary)
                    Text("Bluetooth がオンになっていることを確認してください")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List(viewModel.devices) { device in
                    DeviceRowView(device: device)
                }
            }
        }
        .padding()
    }
}

// MARK: - Hosts Tab

struct HostsTab: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var showAddHost = false
    @State private var newHostLabel = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("登録済み Mac")
                    .font(.headline)
                Spacer()
                Button(action: { viewModel.refreshPeers() }) {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(viewModel.isDiscoveringPeers)

                Button(action: { showAddHost = true }) {
                    Image(systemName: "plus")
                }
                .disabled(viewModel.hosts.count >= 3)
            }

            if viewModel.hosts.isEmpty {
                VStack {
                    Spacer()
                    Text("Mac が登録されていません")
                        .foregroundStyle(.secondary)
                    Text("「+」ボタンから追加してください")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List {
                    ForEach(viewModel.hosts) { host in
                        HostRowView(host: host, onDelete: {
                            viewModel.removeHost(host)
                        })
                    }
                }
            }

            if !viewModel.peers.isEmpty {
                Divider()
                Text("ネットワーク上の Mac")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                ForEach(viewModel.peers, id: \.id) { peer in
                    HStack {
                        Image(systemName: "desktopcomputer")
                        Text(peer.hostName)
                        Spacer()
                        Button("追加") {
                            viewModel.addHostFromPeer(peer)
                        }
                        .disabled(viewModel.hosts.count >= 3)
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding()
        .sheet(isPresented: $showAddHost) {
            AddHostSheet(
                label: $newHostLabel,
                existingLabels: viewModel.hosts.map(\.label),
                onAdd: {
                    viewModel.addHost(label: newHostLabel, hostName: newHostLabel)
                    newHostLabel = ""
                    showAddHost = false
                },
                onCancel: {
                    newHostLabel = ""
                    showAddHost = false
                }
            )
        }
    }
}

// MARK: - Shortcuts Tab

struct ShortcutsTab: View {
    var body: some View {
        Form {
            Section("キーボードショートカット") {
                Text("各ホストへの切り替えにショートカットを割り当てられます")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("ホスト切り替え") {
                LabeledContent("ホスト 1 に切り替え") {
                    ShortcutRecorderView(name: .switchToHost1)
                }
                LabeledContent("ホスト 2 に切り替え") {
                    ShortcutRecorderView(name: .switchToHost2)
                }
                LabeledContent("ホスト 3 に切り替え") {
                    ShortcutRecorderView(name: .switchToHost3)
                }
            }
        }
        .formStyle(.grouped)
    }
}

/// KeyboardShortcuts.Recorder の代替（Bundle.module に依存しないカスタム実装）
struct ShortcutRecorderView: View {
    let name: KeyboardShortcuts.Name

    @State private var isRecording = false
    @State private var shortcutText = ""
    @State private var eventMonitor: Any?

    var body: some View {
        HStack(spacing: 4) {
            Text(isRecording ? "キーを押してください…" : (shortcutText.isEmpty ? "ショートカットを録音" : shortcutText))
                .foregroundStyle(isRecording ? .secondary : (shortcutText.isEmpty ? .tertiary : .primary))
                .frame(minWidth: 120)

            if !shortcutText.isEmpty && !isRecording {
                Button(action: clearShortcut) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isRecording ? Color.accentColor.opacity(0.1) : Color.secondary.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isRecording ? Color.accentColor : Color.clear, lineWidth: 1)
        )
        .onTapGesture { startRecording() }
        .onAppear { loadCurrentShortcut() }
        .onDisappear { removeMonitor() }
    }

    private func loadCurrentShortcut() {
        if let shortcut = KeyboardShortcuts.getShortcut(for: name) {
            shortcutText = "\(shortcut)"
        } else {
            shortcutText = ""
        }
    }

    private static let functionKeyCodes: Set<UInt16> = [
        122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111, // F1-F12
        105, 107, 113, 106, 64, 79, 80 // F13-F19
    ]

    private func startRecording() {
        guard !isRecording else { return }
        isRecording = true
        KeyboardShortcuts.disable(.switchToHost1, .switchToHost2, .switchToHost3)

        let monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let modifiers = event.modifierFlags
                .intersection(.deviceIndependentFlagsMask)
                .subtracting([.capsLock, .numericPad, .function])

            // Escape でキャンセル
            if event.keyCode == 53 && modifiers.isEmpty {
                stopRecording()
                return nil
            }

            // Delete/Backspace でクリア
            if (event.keyCode == 51 || event.keyCode == 117) && modifiers.isEmpty {
                clearShortcut()
                stopRecording()
                return nil
            }

            let isFunctionKey = Self.functionKeyCodes.contains(event.keyCode)

            // 修飾キー (Cmd/Ctrl/Opt) が必要（Fn キー以外）
            guard !modifiers.subtracting(.shift).isEmpty || isFunctionKey,
                  let shortcut = KeyboardShortcuts.Shortcut(event: event) else {
                NSSound.beep()
                return nil
            }

            KeyboardShortcuts.setShortcut(shortcut, for: name)
            shortcutText = "\(shortcut)"
            stopRecording()
            return nil
        }
        eventMonitor = monitor
    }

    private func stopRecording() {
        removeMonitor()
        isRecording = false
        KeyboardShortcuts.enable(.switchToHost1, .switchToHost2, .switchToHost3)
    }

    private func removeMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    private func clearShortcut() {
        KeyboardShortcuts.setShortcut(nil, for: name)
        shortcutText = ""
    }
}

struct AddHostSheet: View {
    @Binding var label: String
    var existingLabels: [String] = []
    let onAdd: () -> Void
    let onCancel: () -> Void

    private var trimmedLabel: String {
        label.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isDuplicate: Bool {
        existingLabels.contains(trimmedLabel)
    }

    private var isValid: Bool {
        !trimmedLabel.isEmpty && !isDuplicate
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Mac を追加")
                .font(.headline)

            TextField("Mac の名前", text: $label)
                .textFieldStyle(.roundedBorder)

            if isDuplicate && !trimmedLabel.isEmpty {
                Text("同じ名前のホストが既に登録されています")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Button("キャンセル", action: onCancel)
                Spacer()
                Button("追加", action: onAdd)
                    .buttonStyle(.borderedProminent)
                    .disabled(!isValid)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 300)
    }
}

// MARK: - About Tab

struct AboutTab: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "keyboard.fill")
                .font(.system(size: 48))
                .foregroundStyle(.blue)

            Text("Magic Switch")
                .font(.title)
                .fontWeight(.semibold)

            Text("Version 1.0.0")
                .foregroundStyle(.secondary)

            Text("Apple Magic Keyboard / Trackpad を\n複数の Mac 間で簡単に切り替え")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding()
    }
}
