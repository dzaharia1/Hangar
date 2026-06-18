import SwiftUI
import AppKit

/// Shown when there's no selection — or when the scripts folder can't be found.
struct EmptyDetailView: View {
    @EnvironmentObject var controller: AppController

    var body: some View {
        VStack(spacing: 14) {
            if controller.scriptsDirectory == nil {
                Image(systemName: "questionmark.folder")
                    .font(.system(size: 44))
                    .foregroundStyle(.tertiary)
                Text("Setup scripts not found")
                    .font(.title2.weight(.semibold))
                Text(controller.loadError ?? "Choose the folder that contains setup-new-app.sh.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
                Button {
                    pickScriptsDirectory()
                } label: {
                    Label("Locate Setup Scripts…", systemImage: "folder.badge.questionmark")
                }
                .buttonStyle(.borderedProminent)
            } else {
                Image(systemName: "square.dashed")
                    .font(.system(size: 44))
                    .foregroundStyle(.tertiary)
                Text("Select an app")
                    .font(.title2.weight(.semibold))
                Text("Pick an app from the sidebar, or create a new one.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Button {
                    controller.showCreateSheet = true
                } label: {
                    Label("Create App", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func pickScriptsDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        panel.message = "Select your setup scripts folder (the one containing setup-new-app.sh)"
        if panel.runModal() == .OK, let url = panel.url {
            controller.chooseScriptsDirectory(url.path)
        }
    }
}
