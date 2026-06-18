import SwiftUI

@main
struct HangarApp: App {
    @StateObject private var controller = AppController()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(controller)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New App…") {
                    controller.showCreateSheet = true
                }
                .keyboardShortcut("n", modifiers: .command)
                .disabled(controller.scriptsDirectory == nil)
            }
            CommandGroup(after: .toolbar) {
                Button("Reload Registry") {
                    controller.load()
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }
    }
}
