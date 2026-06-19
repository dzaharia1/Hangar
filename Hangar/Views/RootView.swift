import SwiftUI

struct RootView: View {
    @EnvironmentObject var controller: AppController
    @AppStorage("appTheme") private var appTheme: AppTheme = .system

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 360)
        } detail: {
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 940, minHeight: 620)
        .preferredColorScheme(appTheme.colorScheme)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    controller.showCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                    Text("Add an app")
                }
                .help("Add an app")
                .disabled(controller.scriptsDirectory == nil)
                .frame(maxHeight: .infinity)
            }

            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 4) {
                    Button {
                        controller.load()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                        Text("Refresh")
                    }
                    .help("Reload from registry")

                    Rectangle()
                        .frame(width: 1, height: 16)
                        .foregroundColor(Color(nsColor: .separatorColor))

                    Button {
                        controller.showSettingsSheet = true
                    } label: {
                        Image(systemName: "gearshape")
                        Text("Settings")
                    }
                    .help("Settings")
                    .disabled(controller.scriptsDirectory == nil)
                }
                .frame(maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $controller.showCreateSheet) {
            CreateAppSheet()
        }
        .sheet(isPresented: $controller.showSettingsSheet) {
            SettingsSheet(settings: controller.currentSettings)
        }
        .sheet(item: $controller.runningAction) { action in
            ActionProgressSheet(action: action, runner: controller.actionRunner)
        }
        .alert(
            "Something went wrong",
            isPresented: Binding(
                get: { controller.errorMessage != nil },
                set: { if !$0 { controller.errorMessage = nil } }
            ),
            presenting: controller.errorMessage
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { message in
            Text(message)
        }
    }

    @ViewBuilder
    private var detail: some View {
        if controller.isCreatingSelected, let creating = controller.creatingApp {
            CreatingView(app: creating, runner: controller.creationRunner)
        } else if let app = controller.selectedApp {
            AppDetailView(app: app)
        } else {
            EmptyDetailView()
        }
    }
}
