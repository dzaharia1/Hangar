import Foundation

/// A lifecycle operation that shells out to the management scripts and streams
/// its output into a progress sheet.
enum AppAction: Identifiable, Equatable {
    case archive(appID: String, name: String)
    case restore(appID: String, name: String)
    case updateDomains(appID: String, name: String, added: [String], removed: [String])

    var id: String {
        switch self {
        case .archive(let appID, _): return "archive-\(appID)"
        case .restore(let appID, _): return "restore-\(appID)"
        case .updateDomains(let appID, _, _, _): return "update-domains-\(appID)"
        }
    }

    var appID: String {
        switch self {
        case .archive(let appID, _), .restore(let appID, _): return appID
        case .updateDomains(let appID, _, _, _): return appID
        }
    }

    var name: String {
        switch self {
        case .archive(_, let name), .restore(_, let name): return name
        case .updateDomains(_, let name, _, _): return name
        }
    }

    var title: String {
        switch self {
        case .archive: return "Archiving \(name)"
        case .restore: return "Restoring \(name)"
        case .updateDomains(_, _, let added, let removed):
            if removed.isEmpty {
                return added.count == 1
                    ? "Adding \(added[0]) to \(name)"
                    : "Adding \(added.count) domains to \(name)"
            }
            if added.isEmpty {
                return removed.count == 1
                    ? "Removing \(removed[0]) from \(name)"
                    : "Removing \(removed.count) domains from \(name)"
            }
            return "Updating domains for \(name)"
        }
    }

    var verb: String {
        switch self {
        case .archive: return "Archive"
        case .restore: return "Restore"
        case .updateDomains: return "Update Domains"
        }
    }
}
