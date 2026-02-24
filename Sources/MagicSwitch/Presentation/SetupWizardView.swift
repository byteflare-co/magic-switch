import SwiftUI
import MagicSwitchCore

/// セットアップウィザード
struct SetupWizardView: View {
    @ObservedObject var viewModel: SetupWizardViewModel
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // ステップインジケーター
            StepIndicator(
                currentStep: viewModel.currentStep.rawValue - 1,
                totalSteps: viewModel.totalSteps,
                stepLabels: ["権限", "デバイス", "接続先", "完了"]
            )
            .padding(.top, 8)

            Divider()
                .padding(.top, 4)

            // ステップコンテンツ（アニメーション付き）
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: viewModel.currentStep)

            Divider()

            // ナビゲーションボタン
            HStack {
                if viewModel.currentStep != .permissions {
                    Button("戻る") {
                        viewModel.previousStep()
                    }
                }
                Spacer()
                if viewModel.currentStep == .completion {
                    Button("完了") {
                        onComplete()
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                } else {
                    Button("次へ") {
                        viewModel.nextStep()
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!viewModel.canProceed)
                }
            }
            .padding()
        }
        .frame(width: 550, height: 420)
    }
}

// MARK: - Step Indicator

struct StepIndicator: View {
    let currentStep: Int
    let totalSteps: Int
    let stepLabels: [String]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<totalSteps, id: \.self) { index in
                HStack(spacing: 0) {
                    // ドット
                    ZStack {
                        Circle()
                            .fill(index <= currentStep ? Color.accentColor : Color.secondary.opacity(0.3))
                            .frame(width: 24, height: 24)

                        if index < currentStep {
                            Image(systemName: "checkmark")
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                        } else {
                            Text("\(index + 1)")
                                .font(.caption2.bold())
                                .foregroundStyle(index == currentStep ? .white : .secondary)
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
        .padding(.horizontal)
        .animation(MagicSwitchTheme.easeAnimation, value: currentStep)
    }
}

// MARK: - Step 1: Permissions

struct PermissionsStepView: View {
    @ObservedObject var viewModel: SetupWizardViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 36))
                    .foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 4) {
                    Text("権限の設定")
                        .font(.title2)
                        .bold()
                    Text("Magic Switch を使用するには、以下の権限が必要です：")
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                PermissionRow(
                    name: "Bluetooth",
                    icon: "antenna.radiowaves.left.and.right",
                    isGranted: viewModel.bluetoothPermissionGranted,
                    onOpenSettings: { viewModel.openBluetoothSettings() }
                )
                PermissionRow(
                    name: "Local Network",
                    icon: "network",
                    isGranted: viewModel.localNetworkPermissionGranted
                )
            }

            Spacer()

            Button("権限を再確認") {
                viewModel.checkPermissions()
            }
        }
        .padding()
        .onAppear {
            viewModel.checkPermissions()
        }
    }
}

struct PermissionRow: View {
    let name: String
    let icon: String
    let isGranted: Bool
    var isOptional: Bool = false
    var onOpenSettings: (() -> Void)? = nil

    var body: some View {
        HStack {
            Image(systemName: isGranted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isGranted ? .green : .secondary)
                .font(.title3)
            Image(systemName: icon)
                .font(.title3)
                .frame(width: 24)
            Text(name)
                .font(.body)
            Spacer()
            if !isGranted, let onOpenSettings {
                Button("設定を開く") {
                    onOpenSettings()
                }
                .font(.caption)
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            if isGranted {
                Text("許可済み")
                    .foregroundStyle(.green)
                    .font(.caption)
                    .fontWeight(.medium)
            } else if isOptional {
                Text("スキップ可")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                    .fontWeight(.medium)
            } else {
                Text("未許可")
                    .foregroundStyle(.orange)
                    .font(.caption)
                    .fontWeight(.medium)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Step 2: Device Selection

struct DeviceSelectionStepView: View {
    @ObservedObject var viewModel: SetupWizardViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "keyboard.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 4) {
                    Text("デバイスの選択")
                        .font(.title2)
                        .bold()
                    Text("切り替え対象のデバイスを選択してください：")
                        .foregroundStyle(.secondary)
                }
            }

            if viewModel.isDiscoveringDevices {
                VStack {
                    Spacer()
                    ProgressView("デバイスを検出中...")
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else if viewModel.discoveredDevices.isEmpty {
                VStack {
                    Spacer()
                    Image(systemName: "keyboard")
                        .font(.system(size: 40))
                        .foregroundStyle(.tertiary)
                    Text("Magic デバイスが見つかりません")
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                    Button("再検出") {
                        viewModel.discoverDevices()
                    }
                    .buttonStyle(.bordered)
                    .padding(.top, 8)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List(viewModel.discoveredDevices) { device in
                    HStack {
                        Image(systemName: viewModel.selectedDeviceIds.contains(device.id)
                              ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(viewModel.selectedDeviceIds.contains(device.id)
                                             ? .blue : .secondary)
                        DeviceRowView(device: device)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.toggleDeviceSelection(device)
                    }
                }
            }
        }
        .padding()
    }
}

// MARK: - Step 3: Host Registration

struct HostRegistrationStepView: View {
    @ObservedObject var viewModel: SetupWizardViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "desktopcomputer")
                    .font(.system(size: 36))
                    .foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 4) {
                    Text("接続先 Mac の登録")
                        .font(.title2)
                        .bold()
                    Text("切り替え先の Mac を登録してください：")
                        .foregroundStyle(.secondary)
                }
            }

            // 登録済みホスト
            if !viewModel.registeredHosts.isEmpty {
                Text("登録済み")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(viewModel.registeredHosts) { host in
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text(host.label)
                        Spacer()
                        Button(action: { viewModel.removeRegisteredHost(host) }) {
                            Image(systemName: "minus.circle")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.vertical, 2)
                }
            }

            Divider()

            // ネットワーク上のピア
            HStack {
                Text("ネットワーク上の Mac")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: { viewModel.discoverPeers() }) {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(viewModel.isDiscoveringPeers)
            }

            if viewModel.isDiscoveringPeers {
                ProgressView("検出中...")
            } else if viewModel.discoveredPeers.isEmpty {
                Text("検出されたMacがありません")
                    .foregroundStyle(.tertiary)
                    .font(.caption)
            } else {
                ForEach(viewModel.discoveredPeers, id: \.id) { peer in
                    HStack {
                        Image(systemName: "desktopcomputer")
                        Text(peer.hostName)
                        Spacer()
                        Button("追加") {
                            viewModel.registerHost(from: peer)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(viewModel.registeredHosts.count >= 3)
                    }
                    .padding(.vertical, 2)
                }
            }

            Spacer()
        }
        .padding()
    }
}

// MARK: - Step 4: Completion

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
