import AppKit
import SwiftUI
import Combine
import MagicSwitchCore

/// NSStatusItem + NSPopover ベースのメニューバー制御
/// - 左クリック: ポップオーバーを表示/非表示
/// - 右クリック: シンプルなコンテキストメニュー（設定、終了のみ）
@MainActor
final class MenuBarController: NSObject {
    private var statusItem: NSStatusItem!
    private let popover: NSPopover
    private let viewModel: MenuBarViewModel
    private var cancellables = Set<AnyCancellable>()
    private var eventMonitor: Any?
    private var globalClickMonitor: Any?

    init(viewModel: MenuBarViewModel) {
        self.viewModel = viewModel
        self.popover = NSPopover()
        super.init()
    }

    func setup() {
        statusItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.variableLength
        )

        // ポップオーバーの設定
        popover.contentSize = NSSize(width: 320, height: 420)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(
            rootView: PopoverContentView(viewModel: viewModel)
        )

        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "keyboard",
                accessibilityDescription: "Magic Switch"
            )
            // 左クリック: ポップオーバーを表示
            button.action = #selector(togglePopover)
            button.target = self
            button.sendAction(on: [.leftMouseUp])
        }

        // 右クリック: コンテキストメニューを表示
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .rightMouseUp) { [weak self] event in
            guard let self = self,
                  let button = self.statusItem.button,
                  button.isMousePoint(button.convert(event.locationInWindow, from: nil), in: button.bounds) else {
                return event
            }
            self.showContextMenu()
            return nil
        }

        // ViewModel の変更を監視してアイコンを更新
        viewModel.$isSwitching.receive(on: RunLoop.main).sink { [weak self] isSwitching in
            self?.updateIcon(isSwitching: isSwitching)
        }.store(in: &cancellables)

        viewModel.$connectedDevices.receive(on: RunLoop.main).sink { [weak self] devices in
            guard let self = self, !self.viewModel.isSwitching else { return }
            self.updateIcon(isSwitching: false)
        }.store(in: &cancellables)
    }

    deinit {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = globalClickMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    // MARK: - Popover

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
            stopGlobalClickMonitor()
        } else {
            showPopover()
        }
    }

    func showPopover() {
        if let button = statusItem.button {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
            viewModel.refresh()
            startGlobalClickMonitor()
        }
    }

    // MARK: - Global Click Monitor

    private func startGlobalClickMonitor() {
        stopGlobalClickMonitor()
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            guard let self = self else { return }
            if self.popover.isShown {
                self.popover.performClose(nil)
            }
            self.stopGlobalClickMonitor()
        }
    }

    private func stopGlobalClickMonitor() {
        if let monitor = globalClickMonitor {
            NSEvent.removeMonitor(monitor)
            globalClickMonitor = nil
        }
    }

    // MARK: - Context Menu

    private func showContextMenu() {
        // ポップオーバーが開いていれば閉じる
        if popover.isShown {
            popover.performClose(nil)
            stopGlobalClickMonitor()
        }

        let menu = buildContextMenu()
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        DispatchQueue.main.async { [weak self] in
            self?.statusItem.menu = nil
        }
    }

    private func buildContextMenu() -> NSMenu {
        let menu = NSMenu()

        let settingsItem = NSMenuItem(
            title: "設定...",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "終了",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    // MARK: - Actions

    @objc private func openSettings() {
        (NSApp.delegate as? AppDelegate)?.openSettings()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Icon

    private func updateIcon(isSwitching: Bool) {
        let symbolName: String
        if isSwitching {
            symbolName = "keyboard.badge.ellipsis"
        } else if viewModel.connectedDevices.isEmpty {
            symbolName = "keyboard"
        } else {
            symbolName = "keyboard.fill"
        }

        statusItem.button?.image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: "Magic Switch"
        )
    }
}
