import Foundation

enum GitHubService {
    enum FetchError: LocalizedError {
        case launchFailed(String)
        case command(String)
        case parse(String)

        var errorDescription: String? {
            switch self {
            case .launchFailed(let m): return "Couldn't run gh: \(m)"
            case .command(let m): return m
            case .parse(let m): return "Couldn't read gh output: \(m)"
            }
        }
    }

    /// Fetch recent workflow runs for `owner/repo` via the `gh` CLI.
    static func fetchRuns(repoSlug: String, limit: Int = 20) async throws -> [ActionRun] {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/zsh")
                let fields = "databaseId,displayTitle,status,conclusion,createdAt,headBranch,event,workflowName,url"
                let command = "gh run list -R \(Shell.quote(repoSlug)) -L \(limit) --json \(fields)"
                process.arguments = ["-lc", command]
                process.environment = Shell.enrichedEnvironment()

                let outPipe = Pipe()
                let errPipe = Pipe()
                process.standardOutput = outPipe
                process.standardError = errPipe

                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: FetchError.launchFailed(error.localizedDescription))
                    return
                }

                let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
                let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()

                guard process.terminationStatus == 0 else {
                    let message = String(decoding: errData, as: UTF8.self)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    continuation.resume(throwing: FetchError.command(
                        message.isEmpty ? "gh exited with code \(process.terminationStatus)." : message
                    ))
                    return
                }

                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                do {
                    let runs = try decoder.decode([ActionRun].self, from: outData)
                    continuation.resume(returning: runs)
                } catch {
                    continuation.resume(throwing: FetchError.parse(error.localizedDescription))
                }
            }
        }
    }
}
