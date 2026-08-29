import Foundation

/// A lifecycle operation that shells out to the management scripts and streams
/// its output into a progress sheet.
enum AppAction: Identifiable, Equatable {
    case archive(appID: String, name: String)
    case restore(appID: String, name: String)
    case addDomain(appID: String, name: String, domains: [String])

    var id: String {
        switch self {
        case .archive(let appID, _): return "archive-\(appID)"
        case .restore(let appID, _): return "restore-\(appID)"
        case .addDomain(let appID, _, _): return "add-domain-\(appID)"
        }
    }

    var appID: String {
        switch self {
        case .archive(let appID, _), .restore(let appID, _): return appID
        case .addDomain(let appID, _, _): return appID
        }
    }

    var name: String {
        switch self {
        case .archive(_, let name), .restore(_, let name): return name
        case .addDomain(_, let name, _): return name
        }
    }

    var title: String {
        switch self {
        case .archive: return "Archiving \(name)"
        case .restore: return "Restoring \(name)"
        case .addDomain(_, _, let domains):
            return domains.count == 1
                ? "Adding \(domains[0]) to \(name)"
                : "Adding \(domains.count) domains to \(name)"
        }
    }

    var verb: String {
        switch self {
        case .archive: return "Archive"
        case .restore: return "Restore"
        case .addDomain: return "Add Domain"
        }
    }
}
