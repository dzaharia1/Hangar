import Foundation

/// A lifecycle operation that shells out to the management scripts and streams
/// its output into a progress sheet.
enum AppAction: Identifiable, Equatable {
    case archive(appID: String, name: String)
    case restore(appID: String, name: String)

    var id: String {
        switch self {
        case .archive(let appID, _): return "archive-\(appID)"
        case .restore(let appID, _): return "restore-\(appID)"
        }
    }

    var appID: String {
        switch self {
        case .archive(let appID, _), .restore(let appID, _): return appID
        }
    }

    var name: String {
        switch self {
        case .archive(_, let name), .restore(_, let name): return name
        }
    }

    var title: String {
        switch self {
        case .archive: return "Archiving \(name)"
        case .restore: return "Restoring \(name)"
        }
    }

    var verb: String {
        switch self {
        case .archive: return "Archive"
        case .restore: return "Restore"
        }
    }
}
