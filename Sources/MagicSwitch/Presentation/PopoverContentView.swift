import SwiftUI
import MagicSwitchCore

/// メニューバーポップオーバーのメインコンテンツ
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

                    Divider()
                        .padding(.horizontal)

                    // ホスト切り替えセクション
                    HostSwitchSectionView(
                        hosts: viewModel.hosts,
                        currentHostId: viewModel.currentHostId,
                        isSwitching: viewModel.isSwitching,
                        onSwitch: { host in viewModel.switchTo(host: host) }
                    )
                }
                .padding()
            }

            // 切り替え結果バナー
            if let result = viewModel.switchResult {
                SwitchResultBanner(result: result)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            Divider()

            // フッター（終了ボタン）
            HStack {
                Spacer()
                Button("終了") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .font(.caption)
                .padding(.vertical, 8)
                Spacer()
            }
        }
        .frame(width: 320)
        .background(.ultraThinMaterial)
        .animation(MagicSwitchTheme.springAnimation, value: viewModel.switchResult)
    }
}

// MARK: - Header

struct PopoverHeaderView: View {
    var body: some View {
        HStack {
            Text("Magic Switch")
                .font(.system(.headline, weight: .semibold))

            Spacer()

            Button(action: {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                NSApp.activate(ignoringOtherApps: true)
            }) {
                Image(systemName: "gear")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Device Section

struct DeviceSectionView: View {
    let devices: [MagicDevice]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("接続デバイス", systemImage: "cable.connector")
                .font(.caption)
                .foregroundStyle(.secondary)

            if devices.isEmpty {
                Text("デバイスが見つかりません")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                ForEach(devices) { device in
                    DeviceCardView(device: device)
                }
            }
        }
    }
}

// MARK: - Host Switch Section

struct HostSwitchSectionView: View {
    let hosts: [HostMac]
    let currentHostId: UUID?
    let isSwitching: Bool
    let onSwitch: (HostMac) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("切り替え先", systemImage: "arrow.triangle.swap")
                .font(.caption)
                .foregroundStyle(.secondary)

            if hosts.isEmpty {
                Text("ホストが登録されていません")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                ForEach(hosts) { host in
                    HostCardView(
                        host: host,
                        isCurrent: host.id == currentHostId,
                        isSwitching: isSwitching,
                        onSwitch: { onSwitch(host) }
                    )
                }
            }
        }
    }
}

// MARK: - Switch Result Banner

struct SwitchResultBanner: View {
    let result: SwitchResult

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
            Text(message)
                .font(.caption)
        }
        .foregroundStyle(isSuccess ? MagicSwitchTheme.success : MagicSwitchTheme.error)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(
            (isSuccess ? Color.green : Color.red).opacity(0.1)
        )
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
