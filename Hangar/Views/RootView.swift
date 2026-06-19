import SwiftUI

struct RootView: View {
    @EnvironmentObject var controller: AppController
    @AppStorage("appTheme") private var appTheme: AppTheme = .system

    @State private var showingArchiveConfirm = false
    @State private var confirmAppName = ""

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

            ToolbarItem(placement: .principal) {
                ControlGroup {
                    Button {
                        controller.showEditSheet = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .help("Edit app")
                    .disabled(controller.selectedApp == nil)

                    Button(role: .destructive) {
                        confirmAppName = ""
                        showingArchiveConfirm = true
                    } label: {
                        Label("Archive", systemImage: "archivebox")
                    }
                    .help("Archive app")
                    .disabled(controller.selectedApp == nil || controller.selectedApp?.status != .active)

                    Button {
                        controller.load()
                    } label: {
                        Label("Reload from registry", systemImage: "arrow.clockwise")
                    }
                    .help("Reload from registry")
                }
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    controller.showSettingsSheet = true
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
                .help("Settings")
                .disabled(controller.scriptsDirectory == nil)
            }
        }
        .sheet(isPresented: $controller.showCreateSheet) {
            CreateAppSheet()
        }
        .sheet(isPresented: $controller.showEditSheet) {
            if let app = controller.selectedApp {
                EditAppSheet(app: app)
            }
        }
        .sheet(isPresented: $controller.showSettingsSheet) {
            SettingsSheet(settings: controller.currentSettings)
        }
        .sheet(item: $controller.runningAction) { action in
            ActionProgressSheet(action: action, runner: controller.actionRunner)
        }
        .alert(
            "Archive \(controller.selectedApp?.name ?? "")?",
            isPresented: $showingArchiveConfirm
        ) {
            TextField("App name", text: $confirmAppName)
            Button("Archive", role: .destructive) {
                if let app = controller.selectedApp, confirmAppName == app.name {
                    controller.archive(app)
                }
            }
            Button("Cancel", role: .cancel) {
                confirmAppName = ""
            }
        } message: {
            if let app = controller.selectedApp {
                Text("This deletes the Firebase project, the local folder, and the Cloudflare DNS records. The GitHub repo is kept. To confirm, please type the application name \"\(app.name)\":")
            }
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
