import Foundation

/// Lifecycle state of an app. `active` and `removed` mirror the registry's
/// `status` field; `creating` is a transient, in-memory-only state used while
/// the setup script is provisioning a brand new app.
enum AppStatus: String, Codable, Hashable {
    case active
    case removed
    case creating
}

/// A single entry from `apps-registry.json`.
///
/// Decoding is intentionally forgiving so the app keeps working against older
/// registry entries written before the schema gained `domains` (array) and
/// `local_root`. Those fall back to the legacy `domain` string and a computed
/// path respectively.
struct ManagedApp: Identifiable, Hashable {
    var id: String
    var name: String
    var domains: [String]
    var localRoot: String
    var firebaseProjectID: String
    var githubRepos: [String]
    var status: AppStatus
    var createdAt: String
    var pinned: Bool

    init(
        id: String,
        name: String,
        domains: [String],
        localRoot: String,
        firebaseProjectID: String,
        githubRepos: [String],
        status: AppStatus,
        createdAt: String,
        pinned: Bool = false
    ) {
        self.id = id
        self.name = name
        self.domains = domains
        self.localRoot = localRoot
        self.firebaseProjectID = firebaseProjectID
        self.githubRepos = githubRepos
        self.status = status
        self.createdAt = createdAt
        self.pinned = pinned
    }

    init(
        id: String,
        name: String,
        domains: [String],
        localRoot: String,
        firebaseProjectID: String,
        githubRepo: String,
        status: AppStatus,
        createdAt: String,
        pinned: Bool = false
    ) {
        self.init(
            id: id,
            name: name,
            domains: domains,
            localRoot: localRoot,
            firebaseProjectID: firebaseProjectID,
            githubRepos: githubRepo.isEmpty ? [] : [githubRepo],
            status: status,
            createdAt: createdAt,
            pinned: pinned
        )
    }
}

// MARK: - Decoding (schema-tolerant)

extension ManagedApp: Decodable {
    enum CodingKeys: String, CodingKey {
        case id, name, domains
        case localRoot = "local_root"
        case firebaseProjectID = "firebase_project_id"
        case githubRepo = "github_repo"
        case status
        case createdAt = "created_at"
        case pinned
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = (try? c.decode(String.self, forKey: .name)) ?? id

        domains = (try? c.decode([String].self, forKey: .domains))?.map(ManagedApp.cleanDomain).filter { !$0.isEmpty } ?? []

        firebaseProjectID = (try? c.decode(String.self, forKey: .firebaseProjectID)) ?? ""
        
        if let array = try? c.decode([String].self, forKey: .githubRepo) {
            githubRepos = array.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        } else if let single = try? c.decode(String.self, forKey: .githubRepo) {
            let trimmed = single.trimmingCharacters(in: .whitespacesAndNewlines)
            githubRepos = trimmed.isEmpty ? [] : [trimmed]
        } else {
            githubRepos = []
        }
        
        let rawStatus = (try? c.decode(String.self, forKey: .status)) ?? "active"
        status = AppStatus(rawValue: rawStatus) ?? .active
        createdAt = (try? c.decode(String.self, forKey: .createdAt)) ?? ""
        // Filled in by AppController using LOCAL_PROJECTS_DIR when absent.
        localRoot = (try? c.decode(String.self, forKey: .localRoot)) ?? ""
        pinned = (try? c.decode(Bool.self, forKey: .pinned)) ?? false
    }
}

// MARK: - Derived values

extension ManagedApp {
    var primaryDomain: String? { domains.first }

    /// The raw Firebase Hosting URL, e.g. `secretly-candy.web.app`.
    var firebaseWebApp: String? {
        firebaseProjectID.isEmpty ? nil : "\(firebaseProjectID).web.app"
    }

    var firebaseConsoleURL: URL? {
        guard !firebaseProjectID.isEmpty else { return nil }
        return URL(string: "https://console.firebase.google.com/project/\(firebaseProjectID)/overview")
    }

    var githubRepo: String { githubRepos.first ?? "" }

    var githubURL: URL? {
        guard let slug = githubSlug else { return nil }
        return URL(string: "https://github.com/\(slug)")
    }

    /// `owner/repo` extracted from the stored `github_repo` value.
    var githubSlug: String? {
        guard !githubRepo.isEmpty else { return nil }
        var s = githubRepo
        for prefix in ["https://", "http://", "github.com/"] where s.hasPrefix(prefix) {
            s.removeFirst(prefix.count)
        }
        if s.hasSuffix(".git") { s.removeLast(4) }
        return s.isEmpty ? nil : s
    }

    struct GitHubRepoInfo: Identifiable, Hashable {
        var id: String { slug }
        let slug: String
        let url: URL?

        var sshRemote: String {
            "git@github.com:\(slug).git"
        }

        var httpsRemote: String {
            "https://github.com/\(slug).git"
        }
    }

    var githubRepoInfos: [GitHubRepoInfo] {
        githubRepos.compactMap { repo in
            var s = repo.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !s.isEmpty else { return nil }
            for prefix in ["https://", "http://", "github.com/"] where s.hasPrefix(prefix) {
                s.removeFirst(prefix.count)
            }
            if s.hasSuffix(".git") { s.removeLast(4) }
            guard !s.isEmpty else { return nil }
            return GitHubRepoInfo(slug: s, url: URL(string: "https://github.com/\(s)"))
        }
    }

    func url(for domain: String) -> URL? {
        URL(string: "https://\(domain)")
    }

    static func cleanDomain(_ raw: String) -> String {
        var d = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        for prefix in ["https://", "http://"] where d.hasPrefix(prefix) {
            d.removeFirst(prefix.count)
        }
        if d.hasSuffix("/") { d.removeLast() }
        return d
    }
}
