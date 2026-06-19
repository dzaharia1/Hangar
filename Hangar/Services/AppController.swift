import Foundation
import Combine
import AppKit

/// App-wide state: the registry contents, the current selection, and the runners
/// that drive create / archive / restore by shelling out to the setup scripts.
@MainActor
final class AppController: ObservableObject {
    @Published var apps: [ManagedApp] = []
    @Published var selectedTab: AppStatus = .active {
        didSet { reconcileSelection() }
    }
    @Published var selectedAppID: String?
    @Published var scriptsDirectory: String?
    @Published var loadError: String?

    @Published var showCreateSheet = false
    @Published var showSettingsSheet = false
    @Published var showEditSheet = false
    @Published var errorMessage: String?
    @Published var githubUser: String?
    @Published var refreshTrigger = UUID()
    @Published var isSyncingRegistry = false

    // Create flow
    let creationRunner = ScriptRunner()
    @Published var creatingApp: ManagedApp?

    // Archive / restore flow
    let actionRunner = ScriptRunner()
    @Published var runningAction: AppAction?

    private var deploySecrets = DeploySecrets()
    private var settings = Settings()

    init() {
        scriptsDirectory = Paths.scriptsDirectory
        load()
        selectedAppID = visibleApps.first?.id
        ensureGitHubUser()
        syncRegistry(showErrorOnFailure: false)
    }

    /// Prefer the new `.settings` file, falling back to the legacy
    /// `.deploy-secrets` for installs that predate it.
    var localProjectsDir: String? {
        settings.expandedLocalProjectsDir ?? deploySecrets.localProjectsDir
    }

    /// A snapshot of the current `.settings` for the editor to start from.
    var currentSettings: Settings { settings }

    /// Look up the authenticated GitHub username once, for auto-filling repo
    /// paths in the manual-log form.
    func ensureGitHubUser() {
        guard githubUser == nil, let dir = scriptsDirectory else { return }
        runShell("gh api user --jq .login", in: dir) { [weak self] code, output in
            let login = output.trimmingCharacters(in: .whitespacesAndNewlines)
            if code == 0, !login.isEmpty { self?.githubUser = login }
        }
    }

    // MARK: - Registry

    func syncRegistry(showErrorOnFailure: Bool = false) {
        guard let dir = scriptsDirectory else { return }
        isSyncingRegistry = true
        runShell("cd apps-registry && git pull", in: dir) { [weak self] code, output in
            guard let self else { return }
            self.isSyncingRegistry = false
            if code != 0 && showErrorOnFailure {
                self.errorMessage = "Couldn't pull the latest registry updates.\n\n\(output.trimmingCharacters(in: .whitespacesAndNewlines))"
            }
            self.load()
        }
    }

    func load() {
        refreshTrigger = UUID()
        guard let dir = scriptsDirectory else {
            apps = []
            loadError = "Couldn't find your setup scripts. Choose the folder that contains setup-new-app.sh."
            return
        }

        deploySecrets = DeploySecrets.load(from: Paths.deploySecretsFile(in: dir))
        settings = Settings.load(from: Paths.settingsFile(in: dir))

        let registryPath = Paths.registryFile(in: dir)
        guard let data = FileManager.default.contents(atPath: registryPath) else {
            apps = []
            loadError = nil
            return
        }

        do {
            let decoded = try JSONDecoder().decode([ManagedApp].self, from: data)
            apps = decoded.map(fillLocalRoot)
            loadError = nil
        } catch {
            loadError = "Couldn't read the registry: \(error.localizedDescription)"
        }
    }

    private func fillLocalRoot(_ app: ManagedApp) -> ManagedApp {
        guard app.localRoot.isEmpty, let base = deploySecrets.localProjectsDir else { return app }
        var copy = app
        copy.localRoot = "\(base)/\(app.id)"
        return copy
    }

    func chooseScriptsDirectory(_ path: String) {
        Paths.setScriptsDirectory(path)
        scriptsDirectory = path
        load()
    }

    // MARK: - Settings

    /// Write the edited `.settings` back to disk, then reload so derived values
    /// (e.g. local roots built from `LOCAL_PROJECTS_DIR`) pick up the change.
    func saveSettings(_ newSettings: Settings) {
        guard let dir = scriptsDirectory else {
            errorMessage = "Choose your setup scripts folder before editing settings."
            return
        }
        do {
            try newSettings.write(to: Paths.settingsFile(in: dir))
            load()
        } catch {
            errorMessage = "Couldn't save settings.\n\n\(error.localizedDescription)"
        }
    }

    // MARK: - Derived

    var visibleApps: [ManagedApp] {
        apps
            .filter { $0.status == selectedTab }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var selectedApp: ManagedApp? {
        if let creatingApp, creatingApp.id == selectedAppID { return creatingApp }
        return apps.first { $0.id == selectedAppID }
    }

    var isCreatingSelected: Bool {
        guard let creatingApp else { return false }
        return creatingApp.id == selectedAppID
    }

    /// Keep the selection valid for the current tab: if the selected app isn't in
    /// the visible list (e.g. after switching tabs), fall back to the first one.
    private func reconcileSelection() {
        if isCreatingSelected { return }
        if let id = selectedAppID, visibleApps.contains(where: { $0.id == id }) { return }
        selectedAppID = visibleApps.first?.id
    }

    // MARK: - Create

    func createApp(from draft: CreateDraft) {
        guard let dir = scriptsDirectory else { return }

        let id = draft.appID
        let name = draft.name.trimmingCharacters(in: .whitespaces)
        let domainValues = draft.domainValues
        let firebaseID = draft.firebaseProjectID
        let localRoot = deploySecrets.localProjectsDir.map { "\($0)/\(id)" } ?? id

        creatingApp = ManagedApp(
            id: id,
            name: name,
            domains: domainValues,
            localRoot: localRoot,
            firebaseProjectID: firebaseID,
            githubRepo: "",
            status: .creating,
            createdAt: "Provisioning…"
        )
        // Select first so the tab change below sees `isCreatingSelected`.
        selectedAppID = id
        selectedTab = .active

        var command = "./setup-new-app.sh -n \(Shell.quote(name)) -id \(Shell.quote(id))"
        if !domainValues.isEmpty {
            command += " -urldomain \(Shell.quote(domainValues.joined(separator: ",")))"
        }
        if !firebaseID.isEmpty {
            command += " -fid \(Shell.quote(firebaseID))"
        }

        creationRunner.run(scriptsDirectory: dir, command: command) { [weak self] code in
            guard let self else { return }
            self.load()
            if code == 0, self.apps.contains(where: { $0.id == id }) {
                // Provisioned and recorded — drop the transient state and show the
                // real detail page.
                self.creatingApp = nil
                self.selectedAppID = id
            }
            // On failure we keep `creatingApp` so the console (with its error)
            // stays visible until the user dismisses it.
        }
    }

    /// Called by the creating view's error footer to leave the console.
    func dismissCreation() {
        creatingApp = nil
        selectedAppID = visibleApps.first?.id
    }

    // MARK: - Manually log (migrate an existing app into the registry)

    /// Appends a fully-specified entry to the registry and commits/pushes it,
    /// mirroring what `setup-new-app.sh` writes at the end — but without any
    /// provisioning. The new app shows up immediately (optimistically) and is
    /// reconciled against the file once git finishes.
    func logApp(from draft: ManualLogDraft) {
        guard let dir = scriptsDirectory else { return }

        let id = draft.appID
        let name = draft.name.trimmingCharacters(in: .whitespaces)
        let domainValues = draft.domainValues
        let localRoot = draft.localRoot
        let firebaseID = draft.firebaseProjectID
        let githubRepoValues = draft.githubRepoValues
        let status = draft.status
        let createdAt = draft.createdAt

        // Optimistic insert so the app appears right away.
        let optimistic = ManagedApp(
            id: id,
            name: name.isEmpty ? id : name,
            domains: domainValues,
            localRoot: localRoot,
            firebaseProjectID: firebaseID,
            githubRepos: githubRepoValues,
            status: status,
            createdAt: createdAt
        )
        apps.removeAll { $0.id == id && $0.status == status }
        apps.append(optimistic)
        selectedTab = status
        selectedAppID = id

        let domainStr = domainValues.joined(separator: ", ")
        let domainsJSON = (try? JSONSerialization.data(withJSONObject: domainValues))
            .map { String(decoding: $0, as: UTF8.self) } ?? "[]"

        let githubRepoJSON: String
        if githubRepoValues.count > 1 {
            githubRepoJSON = (try? JSONSerialization.data(withJSONObject: githubRepoValues))
                .map { String(decoding: $0, as: UTF8.self) } ?? "[]"
        } else if let single = githubRepoValues.first {
            githubRepoJSON = (try? JSONSerialization.data(withJSONObject: [single]))
                .map { data -> String in
                    let str = String(decoding: data, as: UTF8.self)
                    if str.hasPrefix("[") && str.hasSuffix("]") {
                        return String(str.dropFirst().dropLast())
                    }
                    return str
                } ?? "\"\""
        } else {
            githubRepoJSON = "\"\""
        }

        let entryExpr = "{id:$id,name:$name,domain:$domain,domains:$domains,local_root:$local_root,firebase_project_id:$f_pid,github_repo:$gh_repo,status:$status,created_at:$date}"
        let command = """
        cd apps-registry && \
        ([ -s apps-registry.json ] || echo '[]' > apps-registry.json) && \
        NEW_ENTRY=$(jq -n \
          --arg id \(Shell.quote(id)) \
          --arg name \(Shell.quote(name)) \
          --arg domain \(Shell.quote(domainStr)) \
          --argjson domains \(Shell.quote(domainsJSON)) \
          --arg local_root \(Shell.quote(localRoot)) \
          --arg f_pid \(Shell.quote(firebaseID)) \
          --argjson gh_repo \(Shell.quote(githubRepoJSON)) \
          --arg status \(Shell.quote(status.rawValue)) \
          --arg date \(Shell.quote(createdAt)) \
          '\(entryExpr)') && \
        jq ". + [$NEW_ENTRY]" apps-registry.json > apps-registry.tmp.json && \
        mv apps-registry.tmp.json apps-registry.json && \
        { git add apps-registry.json && git commit -m \(Shell.quote("Manually log app: \(id)")) && git push; } >/dev/null 2>&1; true
        """

        runShell(command, in: dir) { [weak self] code, output in
            guard let self else { return }
            if code != 0 {
                self.errorMessage = "Couldn't write the registry entry.\n\n\(output.trimmingCharacters(in: .whitespacesAndNewlines))"
            }
            self.load()
            if self.apps.contains(where: { $0.id == id }) {
                self.selectedTab = status
                self.selectedAppID = id
            }
        }
    }

    func updateApp(oldID: String, from draft: ManualLogDraft) {
        guard let dir = scriptsDirectory else { return }

        let id = draft.appID
        let name = draft.name.trimmingCharacters(in: .whitespaces)
        let domainValues = draft.domainValues
        let localRoot = draft.localRoot
        let firebaseID = draft.firebaseProjectID
        let githubRepoValues = draft.githubRepoValues
        let status = draft.status
        let createdAt = draft.createdAt

        // Optimistic update
        let updated = ManagedApp(
            id: id,
            name: name.isEmpty ? id : name,
            domains: domainValues,
            localRoot: localRoot,
            firebaseProjectID: firebaseID,
            githubRepos: githubRepoValues,
            status: status,
            createdAt: createdAt
        )
        if let index = apps.firstIndex(where: { $0.id == oldID }) {
            apps[index] = updated
        }
        selectedAppID = id

        let domainStr = domainValues.joined(separator: ", ")
        let domainsJSON = (try? JSONSerialization.data(withJSONObject: domainValues))
            .map { String(decoding: $0, as: UTF8.self) } ?? "[]"

        let githubRepoJSON: String
        if githubRepoValues.count > 1 {
            githubRepoJSON = (try? JSONSerialization.data(withJSONObject: githubRepoValues))
                .map { String(decoding: $0, as: UTF8.self) } ?? "[]"
        } else if let single = githubRepoValues.first {
            githubRepoJSON = (try? JSONSerialization.data(withJSONObject: [single]))
                .map { data -> String in
                    let str = String(decoding: data, as: UTF8.self)
                    if str.hasPrefix("[") && str.hasSuffix("]") {
                        return String(str.dropFirst().dropLast())
                    }
                    return str
                } ?? "\"\""
        } else {
            githubRepoJSON = "\"\""
        }

        let entryExpr = "{id:$id,name:$name,domain:$domain,domains:$domains,local_root:$local_root,firebase_project_id:$f_pid,github_repo:$gh_repo,status:$status,created_at:$date}"
        let command = """
        cd apps-registry && \
        ([ -s apps-registry.json ] || echo '[]' > apps-registry.json) && \
        NEW_ENTRY=$(jq -n \
          --arg id \(Shell.quote(id)) \
          --arg name \(Shell.quote(name)) \
          --arg domain \(Shell.quote(domainStr)) \
          --argjson domains \(Shell.quote(domainsJSON)) \
          --arg local_root \(Shell.quote(localRoot)) \
          --arg f_pid \(Shell.quote(firebaseID)) \
          --argjson gh_repo \(Shell.quote(githubRepoJSON)) \
          --arg status \(Shell.quote(status.rawValue)) \
          --arg date \(Shell.quote(createdAt)) \
          '\(entryExpr)') && \
        jq --arg old_id \(Shell.quote(oldID)) --argjson new_entry "$NEW_ENTRY" 'map(if .id == $old_id then $new_entry else . end)' apps-registry.json > apps-registry.tmp.json && \
        mv apps-registry.tmp.json apps-registry.json && \
        { git add apps-registry.json && git commit -m \(Shell.quote("Update app: \(id)")) && git push; } >/dev/null 2>&1; true
        """

        runShell(command, in: dir) { [weak self] code, output in
            guard let self else { return }
            if code != 0 {
                self.errorMessage = "Couldn't update the registry entry.\n\n\(output.trimmingCharacters(in: .whitespacesAndNewlines))"
            }
            self.load()
            if self.apps.contains(where: { $0.id == id }) {
                self.selectedAppID = id
            }
        }
    }

    /// Fire-and-collect a shell command; result delivered on the main actor.
    private func runShell(_ command: String, in dir: String, completion: @escaping (Int32, String) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-lc", command]
            process.currentDirectoryURL = URL(fileURLWithPath: dir)
            process.environment = Shell.enrichedEnvironment()

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            do {
                try process.run()
            } catch {
                let message = error.localizedDescription
                DispatchQueue.main.async { completion(-1, message) }
                return
            }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            let output = String(decoding: data, as: UTF8.self)
            let status = process.terminationStatus
            DispatchQueue.main.async { completion(status, output) }
        }
    }

    // MARK: - Archive / Restore

    func archive(_ app: ManagedApp) {
        runAction(.archive(appID: app.id, name: app.name),
                  command: "./remove-app.sh --app-id \(Shell.quote(app.id))")
    }

    func restore(_ app: ManagedApp) {
        runAction(.restore(appID: app.id, name: app.name),
                  command: "./host-manager.sh restore-app -id \(Shell.quote(app.id))")
    }

    private func runAction(_ action: AppAction, command: String) {
        guard let dir = scriptsDirectory else { return }
        actionRunner.reset()
        runningAction = action
        actionRunner.run(scriptsDirectory: dir, command: command) { [weak self] _ in
            // Reload so the app hops between Active/Archived; keep the sheet open
            // so the user can read the final output and dismiss it themselves.
            self?.load()
        }
    }

    func finishAction() {
        guard !actionRunner.isRunning else { return }
        let action = runningAction
        runningAction = nil
        // After archiving, follow the app into the Archived tab; after restoring,
        // follow it back to Active.
        if let action {
            switch action {
            case .archive(let appID, _):
                selectedTab = .removed
                selectedAppID = appID
            case .restore(let appID, _):
                selectedTab = .active
                selectedAppID = appID
            }
        }
    }
}
