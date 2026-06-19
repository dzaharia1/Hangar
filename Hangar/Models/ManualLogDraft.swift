import Foundation
import Combine

struct RepoEntry: Identifiable, Hashable {
    let id = UUID()
    var value: String
}

/// Backing state for the "Manually log app" tab — used when migrating a legacy
/// app into the registry without running any provisioning. It exposes every
/// registry field and uses the same name-driven auto-fill as `CreateDraft`:
/// derived fields populate from the name until the user edits them.
@MainActor
final class ManualLogDraft: ObservableObject {
    @Published private(set) var name = ""
    @Published private(set) var appID = ""
    @Published private(set) var domains: [DomainEntry] = []
    @Published private(set) var firebaseProjectID = ""
    @Published private(set) var localRoot = ""
    @Published private(set) var githubRepos: [RepoEntry] = []
    @Published var status: AppStatus = .active
    @Published var createdAt = ManualLogDraft.nowString()

    @Published private(set) var appIDAuto = true
    @Published private(set) var domainsAuto = true
    @Published private(set) var firebaseAuto = true
    @Published private(set) var localRootAuto = true
    @Published private(set) var githubAuto = true

    private let apexDomains = ["danzaharia.com", "adanmade.app"]
    private let firebaseSuffix = String(Int.random(in: 10000...99999))

    private var projectsDir: String?
    private var githubUser: String?

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !appID.isEmpty
    }

    var domainValues: [String] {
        domains.map { $0.value.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    var githubRepoValues: [String] {
        githubRepos.map { $0.value.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    // MARK: - Configuration (injected once the controller has it)

    func configure(projectsDir: String?, githubUser: String?) {
        self.projectsDir = projectsDir
        self.githubUser = githubUser
        recomputeDerived()
    }

    func loadApp(_ app: ManagedApp) {
        name = app.name
        appID = app.id
        domains = app.domains.map { DomainEntry(value: $0) }
        firebaseProjectID = app.firebaseProjectID
        localRoot = app.localRoot
        githubRepos = app.githubRepos.map { RepoEntry(value: $0) }
        status = app.status
        createdAt = app.createdAt

        appIDAuto = false
        domainsAuto = false
        firebaseAuto = false
        localRootAuto = false
        githubAuto = false
    }

    func updateGitHubUser(_ user: String?) {
        githubUser = user
        if githubAuto {
            githubRepos = appID.isEmpty
                ? []
                : [RepoEntry(value: autoGithubRepo())]
        }
    }

    // MARK: - Edits from the UI

    func setName(_ newValue: String) {
        name = newValue
        if appIDAuto { appID = CreateDraft.slug(newValue) }
        recomputeDerived()
    }

    func setAppID(_ newValue: String) {
        appIDAuto = false
        appID = newValue
        recomputeDerived()
    }

    func setDomain(id: UUID, _ newValue: String) {
        domainsAuto = false
        if let index = domains.firstIndex(where: { $0.id == id }) {
            domains[index].value = newValue
        }
    }

    func addDomain() {
        domainsAuto = false
        domains.append(DomainEntry(value: ""))
    }

    func removeDomain(id: UUID) {
        domainsAuto = false
        domains.removeAll { $0.id == id }
    }

    func setFirebaseProjectID(_ newValue: String) {
        firebaseAuto = false
        firebaseProjectID = newValue
    }

    func setLocalRoot(_ newValue: String) {
        localRootAuto = false
        localRoot = newValue
    }

    func setGithubRepo(id: UUID, _ newValue: String) {
        githubAuto = false
        if let index = githubRepos.firstIndex(where: { $0.id == id }) {
            githubRepos[index].value = newValue
        }
    }

    func addGithubRepo() {
        githubAuto = false
        githubRepos.append(RepoEntry(value: ""))
    }

    func removeGithubRepo(id: UUID) {
        githubAuto = false
        githubRepos.removeAll { $0.id == id }
    }

    // MARK: - Auto-population

    private func recomputeDerived() {
        if domainsAuto {
            domains = appID.isEmpty
                ? []
                : apexDomains.map { DomainEntry(value: "\(appID).\($0)") }
        }
        if firebaseAuto {
            firebaseProjectID = appID.isEmpty ? "" : "\(appID)-\(firebaseSuffix)"
        }
        if localRootAuto {
            localRoot = autoLocalRoot()
        }
        if githubAuto {
            githubRepos = appID.isEmpty
                ? []
                : [RepoEntry(value: autoGithubRepo())]
        }
    }

    private func autoLocalRoot() -> String {
        guard !appID.isEmpty else { return "" }
        if let base = projectsDir { return "\(base)/\(appID)" }
        return appID
    }

    private func autoGithubRepo() -> String {
        guard !appID.isEmpty else { return "" }
        if let user = githubUser, !user.isEmpty { return "github.com/\(user)/\(appID)" }
        return "github.com/\(appID)"
    }

    static func nowString() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE MMM d HH:mm:ss zzz yyyy"
        return formatter.string(from: Date())
    }
}
