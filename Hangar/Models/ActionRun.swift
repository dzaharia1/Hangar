import Foundation

/// A GitHub Actions workflow run, as returned by `gh run list --json`.
struct ActionRun: Identifiable, Hashable, Decodable {
    var databaseId: Int
    var displayTitle: String
    var status: String          // queued | in_progress | completed
    var conclusion: String?     // success | failure | cancelled | ...
    var createdAt: Date?
    var headBranch: String?
    var event: String?
    var workflowName: String?
    var url: String?

    var id: Int { databaseId }

    enum State {
        case running
        case success
        case failure
        case neutral
    }

    var state: State {
        if status != "completed" { return .running }
        switch conclusion {
        case "success":
            return .success
        case "failure", "timed_out", "startup_failure":
            return .failure
        default:
            return .neutral
        }
    }

    var link: URL? { url.flatMap(URL.init(string:)) }
}
