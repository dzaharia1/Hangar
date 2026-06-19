import SwiftUI

/// The "add app" dialog. Two tabs: **Create app** (provisions a brand new app via
/// the setup script) and **Manually log app** (records an existing app in the
/// registry without provisioning — used when migrating legacy apps).
struct CreateAppSheet: View {
    enum Mode: String, CaseIterable, Identifiable {
        case create = "Create app"
        case manual = "Manually log app"
        var id: String { rawValue }
    }

    @State private var mode: Mode = .create
    @StateObject private var createDraft = CreateDraft()
    @StateObject private var manualDraft = ManualLogDraft()

    var body: some View {
        VStack(spacing: 0) {
            Picker("Mode", selection: $mode) {
                ForEach(Mode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 24)
            .padding(.top, 22)
            .padding(.bottom, 6)

            switch mode {
            case .create:
                CreateAppForm(draft: createDraft)
            case .manual:
                ManualLogForm(draft: manualDraft)
            }
        }
        .frame(width: 500)
        .frame(maxHeight: 640)
    }
}

// MARK: - Shared field chrome

struct FormField<Content: View>: View {
    let label: String
    var auto: Bool = false
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(label).font(.subheadline.weight(.medium))
                if auto { AutoBadge() }
            }
            content
        }
    }
}

struct AutoBadge: View {
    var body: some View {
        Text("Auto")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.quaternary, in: Capsule())
    }
}

/// An editable list of domains shared by both forms.
struct DomainListEditor: View {
    let domains: [DomainEntry]
    let onEdit: (UUID, String) -> Void
    let onRemove: (UUID) -> Void
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            ForEach(domains) { entry in
                HStack(spacing: 6) {
                    TextField("app.example.com", text: Binding(
                        get: { entry.value },
                        set: { onEdit(entry.id, $0) }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    Button {
                        onRemove(entry.id)
                    } label: {
                        Image(systemName: "minus.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .help("Remove domain")
                }
            }
            Button(action: onAdd) {
                Label("Add domain", systemImage: "plus").font(.callout)
            }
            .buttonStyle(.borderless)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Create tab

struct CreateAppForm: View {
    @ObservedObject var draft: CreateDraft
    @EnvironmentObject var controller: AppController
    @Environment(\.dismiss) private var dismiss
    @FocusState private var nameFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    FormField(label: "App name") {
                        TextField("My New App Idea", text: Binding(
                            get: { draft.name }, set: { draft.setName($0) }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .focused($nameFocused)
                    }
                    FormField(label: "App ID", auto: draft.appIDAuto) {
                        monoField("my-new-app-idea", get: { draft.appID }, set: { draft.setAppID($0) })
                    }
                    FormField(label: "Domains", auto: draft.domainsAuto) {
                        DomainListEditor(
                            domains: draft.domains,
                            onEdit: { draft.setDomain(id: $0, $1) },
                            onRemove: { draft.removeDomain(id: $0) },
                            onAdd: { draft.addDomain() }
                        )
                    }
                    FormField(label: "Firebase Project ID", auto: draft.firebaseAuto) {
                        monoField("my-new-app-idea-12345", get: { draft.firebaseProjectID }, set: { draft.setFirebaseProjectID($0) })
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 10)
                .padding(.bottom, 8)
            }

            Divider()

            HStack {
                Text("Provisions Firebase, GitHub, and DNS.")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Create") {
                    controller.createApp(from: draft)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!draft.isValid)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .onAppear { nameFocused = true }
    }
}

// MARK: - Manually log tab

struct ManualLogForm: View {
    @ObservedObject var draft: ManualLogDraft
    @EnvironmentObject var controller: AppController
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    FormField(label: "App name") {
                        TextField("My New App Idea", text: Binding(
                            get: { draft.name }, set: { draft.setName($0) }
                        ))
                        .textFieldStyle(.roundedBorder)
                    }
                    FormField(label: "App ID", auto: draft.appIDAuto) {
                        monoField("my-new-app-idea", get: { draft.appID }, set: { draft.setAppID($0) })
                    }
                    FormField(label: "Domains", auto: draft.domainsAuto) {
                        DomainListEditor(
                            domains: draft.domains,
                            onEdit: { draft.setDomain(id: $0, $1) },
                            onRemove: { draft.removeDomain(id: $0) },
                            onAdd: { draft.addDomain() }
                        )
                    }
                    FormField(label: "Firebase Project ID", auto: draft.firebaseAuto) {
                        monoField("my-new-app-idea-12345", get: { draft.firebaseProjectID }, set: { draft.setFirebaseProjectID($0) })
                    }
                    FormField(label: "Local root", auto: draft.localRootAuto) {
                        monoField("~/Projects/my-new-app-idea", get: { draft.localRoot }, set: { draft.setLocalRoot($0) })
                    }
                    FormField(label: "GitHub repo", auto: draft.githubAuto) {
                        monoField("github.com/user/my-new-app-idea", get: { draft.githubRepo }, set: { draft.setGithubRepo($0) })
                    }
                    HStack(alignment: .top, spacing: 16) {
                        FormField(label: "Status") {
                            Picker("Status", selection: $draft.status) {
                                Text("Active").tag(AppStatus.active)
                                Text("Archived").tag(AppStatus.removed)
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                        }
                        FormField(label: "Created at") {
                            TextField("date", text: $draft.createdAt)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 10)
                .padding(.bottom, 8)
            }

            Divider()

            HStack {
                Text("Adds a registry entry — no provisioning.")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Log app") {
                    controller.logApp(from: draft)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!draft.isValid)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .onAppear {
            controller.ensureGitHubUser()
            draft.configure(projectsDir: controller.localProjectsDir, githubUser: controller.githubUser)
        }
        .onChange(of: controller.githubUser) { _, newValue in
            draft.updateGitHubUser(newValue)
        }
    }
}

// MARK: - Helpers

private func monoField(
    _ placeholder: String,
    get: @escaping () -> String,
    set: @escaping (String) -> Void
) -> some View {
    TextField(placeholder, text: Binding(get: get, set: set))
        .textFieldStyle(.roundedBorder)
        .font(.system(.body, design: .monospaced))
}
