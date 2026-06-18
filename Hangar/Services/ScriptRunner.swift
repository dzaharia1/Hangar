import Foundation
import Combine

/// One line of captured output, classified for coloring in the console.
struct LogLine: Identifiable, Hashable {
    let id = UUID()
    let text: String
    let kind: Kind

    enum Kind {
        case command
        case normal
        case success
        case failure
        case warning
    }
}

/// Runs a shell command through a login `zsh`, streaming combined stdout/stderr
/// into `lines` as it arrives. One runner drives one console view.
@MainActor
final class ScriptRunner: ObservableObject {
    @Published private(set) var lines: [LogLine] = []
    @Published private(set) var isRunning = false
    @Published private(set) var exitCode: Int32?

    private var process: Process?

    var succeeded: Bool { exitCode == 0 }

    func run(
        scriptsDirectory: String,
        command: String,
        completion: ((Int32) -> Void)? = nil
    ) {
        guard !isRunning else { return }

        lines = []
        exitCode = nil
        isRunning = true
        append("$ \(command)", forcedKind: .command)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", command]
        process.currentDirectoryURL = URL(fileURLWithPath: scriptsDirectory)
        process.environment = Shell.enrichedEnvironment()

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        let handle = pipe.fileHandleForReading
        let buffer = LineBuffer()

        handle.readabilityHandler = { [weak self] fh in
            let data = fh.availableData
            guard !data.isEmpty else { return }
            let chunk = String(decoding: data, as: UTF8.self)
            let completed = buffer.append(chunk)
            guard !completed.isEmpty else { return }
            Task { @MainActor in
                guard let self else { return }
                for line in completed { self.append(line) }
            }
        }

        process.terminationHandler = { [weak self] proc in
            handle.readabilityHandler = nil
            let remaining = buffer.flush()
            let status = proc.terminationStatus
            Task { @MainActor in
                guard let self else { return }
                if !remaining.isEmpty { self.append(remaining) }
                self.isRunning = false
                self.exitCode = status
                completion?(status)
            }
        }

        self.process = process

        do {
            try process.run()
        } catch {
            append("Failed to launch process: \(error.localizedDescription)", forcedKind: .failure)
            isRunning = false
            exitCode = -1
            completion?(-1)
        }
    }

    func cancel() {
        process?.terminate()
    }

    func reset() {
        guard !isRunning else { return }
        lines = []
        exitCode = nil
    }

    private func append(_ raw: String, forcedKind: LogLine.Kind? = nil) {
        let clean = ANSI.strip(raw)
        let kind = forcedKind ?? Self.classify(clean)
        lines.append(LogLine(text: clean, kind: kind))
    }

    private static func classify(_ line: String) -> LogLine.Kind {
        let upper = line.uppercased()
        if upper.contains("SUCCESS") { return .success }
        if upper.contains("FAILED") || upper.contains("ERROR:") { return .failure }
        if upper.contains("WARNING") { return .warning }
        return .normal
    }
}
