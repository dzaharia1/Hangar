import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var controller: AppController
    @State private var filterText = ""

    var body: some View {
        VStack(spacing: 0) {
            Picker("Tab", selection: $controller.selectedTab) {
                Text("Active apps").tag(AppStatus.active)
                Text("Archived apps").tag(AppStatus.removed)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 12)
            .padding(.top, 0)
            .padding(.bottom, 8)

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.tertiary)
                    .font(.callout)
                TextField("Filter", text: $filterText)
                    .textFieldStyle(.plain)
                    .font(.callout)
                if !filterText.isEmpty {
                    Button {
                        filterText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            appList
        }
        .frame(minWidth: 240)
    }

    private var filteredApps: [ManagedApp] {
        guard !filterText.isEmpty else { return controller.visibleApps }
        let q = filterText.lowercased()
        return controller.visibleApps.filter {
            $0.name.lowercased().contains(q) ||
            ($0.primaryDomain ?? "").lowercased().contains(q)
        }
    }

    @ViewBuilder
    private var appList: some View {
        if filteredApps.isEmpty {
            VStack(spacing: 6) {
                Spacer()
                Image(systemName: filterText.isEmpty
                      ? (controller.selectedTab == .active ? "square.stack.3d.up.slash" : "archivebox")
                      : "magnifyingglass")
                    .font(.title)
                    .foregroundStyle(.tertiary)
                Text(filterText.isEmpty
                     ? (controller.selectedTab == .active ? "No active apps" : "No archived apps")
                     : "No results")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else {
            List(selection: $controller.selectedAppID) {
                ForEach(filteredApps) { app in
                    AppRow(app: app)
                        .tag(app.id)
                }
            }
            .listStyle(.sidebar)
        }
    }
}

struct AppRow: View {
    let app: ManagedApp

    var body: some View {
        HStack(spacing: 10) {
            AppGlyph(id: app.id, name: app.name, size: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                Text(app.primaryDomain ?? app.id)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 3)
    }
}
