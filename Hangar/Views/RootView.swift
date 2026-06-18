import SwiftUI

struct RootView: View {
    @EnvironmentObject var controller: AppController

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 360)
        } detail: {
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 940, minHeight: 620)
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button {
                    controller.showCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .help("Add an app")
                .disabled(controller.scriptsDirectory == nil)

                Button {
                    controller.load()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Reload from registry")

                Text("Let Dan Code")
                    .font(.headline)
                    .padding(.leading, 4)
            }
        }
        .sheet(isPresented: $controller.showCreateSheet) {
            CreateAppSheet()
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
