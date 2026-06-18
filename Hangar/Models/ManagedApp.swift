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
    var githubRepo: String
    var status: AppStatus
    var createdAt: String

    init(
        id: String,
        name: String,
        domains: [String],
        localRoot: String,
        firebaseProjectID: String,
        githubRepo: String,
        status: AppStatus,
        createdAt: String
    ) {
        self.id = id
        self.name = name
        self.domains = domains
        self.localRoot = localRoot
        self.firebaseProjectID = firebaseProjectID
        self.githubRepo = githubRepo
        self.status = status
        self.createdAt = createdAt
    }
}

// MARK: - Decoding (schema-tolerant)

extension ManagedApp: Decodable {
    enum CodingKeys: String, CodingKey {
        case id, name, domain, domains
        case localRoot = "local_root"
        case firebaseProjectID = "firebase_project_id"
        case githubRepo = "github_repo"
        case status
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = (try? c.decode(String.self, forKey: .name)) ?? id

        if let array = try? c.decode([String].self, forKey: .domains), !array.isEmpty {
            domains = array.map(ManagedApp.cleanDomain).filter { !$0.isEmpty }
        } else if let legacy = try? c.decode(String.self, forKey: .domain) {
            domains = legacy
                .split(separator: ",")
                .map { ManagedApp.cleanDomain(String($0)) }
                .filter { !$0.isEmpty }
        } else {
            domains = []
        }

        firebaseProjectID = (try? c.decode(String.self, forKey: .firebaseProjectID)) ?? ""
        githubRepo = (try? c.decode(String.self, forKey: .githubRepo)) ?? ""
        let rawStatus = (try? c.decode(String.self, forKey: .status)) ?? "active"
        status = AppStatus(rawValue: rawStatus) ?? .active
        createdAt = (try? c.decode(String.self, forKey: .createdAt)) ?? ""
        // Filled in by AppController using LOCAL_PROJECTS_DIR when absent.
        localRoot = (try? c.decode(String.self, forKey: .localRoot)) ?? ""
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
