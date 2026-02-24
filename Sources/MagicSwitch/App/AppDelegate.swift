import AppKit
import SwiftUI
import KeyboardShortcuts
import MagicSwitchCore

// MARK: - Keyboard Shortcut Names

extension KeyboardShortcuts.Name {
    static let switchToHost1 = Self("switchToHost1")
    static let switchToHost2 = Self("switchToHost2")
    static let switchToHost3 = Self("switchToHost3")
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let container = DependencyContainer()
    private var menuBarController: MenuBarController?
    private var menuBarViewModel: MenuBarViewModel?
    private var wizardWindow: NSWindow?

    // メニューバーアプリなので、全ウィンドウを閉じてもアプリを終了しない
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // .app バンドル外から直接実行された場合でもメニューバーに表示するため、
        // activationPolicy を .accessory に設定（LSUIElement 相当）
        NSApp.setActivationPolicy(.accessory)

        MagicSwitchLogger.bootstrap()
        MagicSwitchLogger.ui.info("Magic Switch started")

        setupMenuBar()
        startNetworkService()
        registerKeyboardShortcuts()
        checkFirstLaunch()
    }

    func applicationWillTerminate(_ notification: Notification) {
        MagicSwitchLogger.ui.info("Magic Switch terminating")
        Task {
            await container.networkManager.stop()
        }
    }

    // MARK: - Private

    private func setupMenuBar() {
        let viewModel = container.makeMenuBarViewModel()
        self.menuBarViewModel = viewModel

        let controller = MenuBarController(viewModel: viewModel)
        controller.setup()
        self.menuBarController = controller

        // 初回リフレッシュ
        viewModel.refresh()
    }

    private func startNetworkService() {
        Task {
            do {
                try await container.networkManager.start()
                // SwitchService のコマンドハンドラをセットアップ
                await container.switchService.setup()
                MagicSwitchLogger.network.info("Network service started")
            } catch {
                MagicSwitchLogger.network.error("Failed to start network service: \(error)")
            }
        }
    }

    // MARK: - First Launch

    private func checkFirstLaunch() {
        Task {
            let config = await container.configStore.loadOrDefault(
                AppConfig.self,
                from: "config.json",
                default: AppConfig()
            )
            if config.isFirstLaunch {
                showSetupWizard()
            }
        }
    }

    private func showSetupWizard() {
        let viewModel = container.makeSetupWizardViewModel()
        let wizardView = SetupWizardView(viewModel: viewModel) { [weak self] in
            self?.wizardWindow?.close()
            self?.wizardWindow = nil
            // ウィザード完了後にメニューバーを更新し、ポップオーバーを表示
            self?.menuBarViewModel?.refresh()
            // 少し遅延させてリフレッシュ完了後にポップオーバーを表示
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self?.menuBarController?.showPopover()
            }
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 550, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Magic Switch セットアップ"
        window.contentView = NSHostingView(rootView: wizardView)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.wizardWindow = window
    }

    // MARK: - Keyboard Shortcuts

    private func registerKeyboardShortcuts() {
        KeyboardShortcuts.onKeyUp(for: .switchToHost1) { [weak self] in
            Task { @MainActor in
                await self?.switchToHost(index: 0)
            }
        }

        KeyboardShortcuts.onKeyUp(for: .switchToHost2) { [weak self] in
            Task { @MainActor in
                await self?.switchToHost(index: 1)
            }
        }

        KeyboardShortcuts.onKeyUp(for: .switchToHost3) { [weak self] in
            Task { @MainActor in
                await self?.switchToHost(index: 2)
            }
        }
    }

    private func switchToHost(index: Int) async {
        let hosts = await container.configStore.loadOrDefault(
            [HostMac].self,
            from: "hosts.json",
            default: []
        )
        guard index < hosts.count else { return }
        let targetHost = hosts[index]

        do {
            try await container.switchService.switchAllDevices(to: targetHost)
        } catch {
            MagicSwitchLogger.switching.error("Keyboard shortcut switch failed: \(error)")
        }
    }

    // MARK: - Accessors for SwiftUI

    func settingsViewModel() -> SettingsViewModel {
        container.makeSettingsViewModel()
    }

    func setupWizardViewModel() -> SetupWizardViewModel {
        container.makeSetupWizardViewModel()
    }

    var dependencyContainer: DependencyContainer {
        container
    }
}
