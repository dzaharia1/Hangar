import SwiftUI

struct AppDetailView: View {
    let app: ManagedApp
    @EnvironmentObject var controller: AppController
    @State private var confirmingRestore = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                localFolderSection
                domainsSection
                firebaseSection
                githubSection
                ActionRunsList(app: app)
            }
            .padding(24)
            .frame(maxWidth: 820, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .confirmationDialog(
            "Restore \(app.name)?",
            isPresented: $confirmingRestore,
            titleVisibility: .visible
        ) {
            Button("Restore") { controller.restore(app) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This re-clones the repo, recreates the Firebase project, and redeploys from GitHub.")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            AppGlyph(id: app.id, name: app.name, size: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text(app.name)
                    .font(.title2.weight(.semibold))
                HStack(spacing: 10) {
                    StatusBadge(status: app.status)
                    Text(app.id)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                if !app.createdAt.isEmpty {
                    Text("Created \(app.createdAt)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
            actionButton
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        switch app.status {
        case .active:
            EmptyView()
        case .removed:
            Button {
                confirmingRestore = true
            } label: {
                Label("Restore", systemImage: "arrow.uturn.up")
            }
            .buttonStyle(.borderedProminent)
        case .creating:
            EmptyView()
        }
    }

    // MARK: - Sections

    private var localFolderSection: some View {
        SectionCard(title: "Local Folder", systemImage: "folder") {
            DetailRow(icon: "folder", value: displayPath(app.localRoot), monospaced: true) {
                HStack(spacing: 6) {
                    IconActionButton(systemImage: "doc.on.doc", help: "Copy path") {
                        Clipboard.copy(app.localRoot)
                    }
                    IconActionButton(systemImage: "arrow.up.forward.app", help: "Reveal in Finder") {
                        Browser.revealInFinder(app.localRoot)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var domainsSection: some View {
        SectionCard(title: "URLs", systemImage: "link") {
            VStack(spacing: 8) {
                ForEach(app.domains, id: \.self) { domain in
                    linkRow(label: domain, url: app.url(for: domain))
                }
                if let webApp = app.firebaseWebApp {
                    linkRow(label: webApp, url: URL(string: "https://\(webApp)"), subtitle: "Firebase Hosting")
                }
                if app.domains.isEmpty && app.firebaseWebApp == nil {
                    Text("No domains recorded.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var firebaseSection: some View {
        SectionCard(title: "Firebase", systemImage: "flame") {
            VStack(spacing: 8) {
                if !app.firebaseProjectID.isEmpty {
                    DetailRow(icon: "number", value: app.firebaseProjectID, monospaced: true) {
                        IconActionButton(systemImage: "doc.on.doc", help: "Copy project ID") {
                            Clipboard.copy(app.firebaseProjectID)
                        }
                    }
                }
                if let console = app.firebaseConsoleURL {
                    linkRow(label: "Open Firebase Console", url: console, icon: "arrow.up.right.square")
                } else {
                    Text("No Firebase project recorded.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var githubSection: some View {
        SectionCard(title: "GitHub", systemImage: "chevron.left.forwardslash.chevron.right") {
            let infos = app.githubRepoInfos
            if infos.isEmpty {
                Text("No GitHub repo recorded.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(infos) { info in
                        linkRow(label: info.slug, url: info.url, icon: "chevron.left.forwardslash.chevron.right")
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func linkRow(label: String, url: URL?, subtitle: String? = nil, icon: String = "globe") -> some View {
        DetailRow(icon: icon, value: label) {
            HStack(spacing: 6) {
                if let subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                if let url {
                    IconActionButton(systemImage: "doc.on.doc", help: "Copy") {
                        Clipboard.copy(url.absoluteString)
                    }
                    IconActionButton(systemImage: "arrow.up.right", help: "Open") {
                        Browser.open(url)
                    }
                }
            }
        }
    }

    private func displayPath(_ path: String) -> String {
        let home = NSHomeDirectory()
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }
}
