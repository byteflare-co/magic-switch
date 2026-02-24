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
                    KeyboardShortcuts.Recorder(for: .switchToHost1)
                }
                LabeledContent("ホスト 2 に切り替え") {
                    KeyboardShortcuts.Recorder(for: .switchToHost2)
                }
                LabeledContent("ホスト 3 に切り替え") {
                    KeyboardShortcuts.Recorder(for: .switchToHost3)
                }
            }
        }
        .formStyle(.grouped)
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
