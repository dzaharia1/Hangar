import SwiftUI

struct EditAppSheet: View {
    let app: ManagedApp
    @EnvironmentObject var controller: AppController
    @StateObject private var draft = ManualLogDraft()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Text("Edit \(app.name)")
                .font(.headline)
                .padding(.top, 22)
                .padding(.bottom, 6)

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
                    FormField(label: "GitHub repos", auto: draft.githubAuto) {
                        RepoListEditor(
                            repos: draft.githubRepos,
                            onEdit: { draft.setGithubRepo(id: $0, $1) },
                            onRemove: { draft.removeGithubRepo(id: $0) },
                            onAdd: { draft.addGithubRepo() }
                        )
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
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save") {
                    controller.updateApp(oldID: app.id, from: draft)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!draft.isValid)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .frame(width: 500)
        .frame(maxHeight: 640)
        .onAppear {
            draft.loadApp(app)
        }
    }
}

private func monoField(
    _ placeholder: String,
    get: @escaping () -> String,
    set: @escaping (String) -> Void
) -> some View {
    TextField(placeholder, text: Binding(get: get, set: set))
        .textFieldStyle(.roundedBorder)
        .font(.system(.body, design: .monospaced))
}
