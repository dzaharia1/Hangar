import SwiftUI

@main
struct HangarApp: App {
    @StateObject private var controller = AppController()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(controller)
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
                    controller.showSettingsSheet = true
                }
                .keyboardShortcut(",", modifiers: .command)
                .disabled(controller.scriptsDirectory == nil)
            }
            CommandGroup(replacing: .newItem) {
                Button("New App…") {
                    controller.showCreateSheet = true
                }
                .keyboardShortcut("n", modifiers: .command)
                .disabled(controller.scriptsDirectory == nil)
            }
            CommandGroup(after: .toolbar) {
                Button("Reload Registry") {
                    controller.syncRegistry(showErrorOnFailure: true)
                }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(controller.isSyncingRegistry)
            }
        }
    }
}
