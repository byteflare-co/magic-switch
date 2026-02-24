import SwiftUI
import MagicSwitchCore

@main
struct MagicSwitchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(viewModel: appDelegate.settingsViewModel())
        }
    }
}
