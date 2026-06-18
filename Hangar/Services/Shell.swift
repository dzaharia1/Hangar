import Foundation

enum Shell {
    /// Build an environment that resembles the user's login shell so spawned
    /// processes can find `gh`, `gcloud`, `firebase`, `jq`, `npm`, etc. — tools
    /// that typically live in Homebrew or the gcloud SDK and aren't on a GUI
    /// app's bare PATH.
    static func enrichedEnvironment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        let home = NSHomeDirectory()
        let extra = [
            "/opt/homebrew/bin",
            "/opt/homebrew/sbin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin",
            "\(home)/google-cloud-sdk/bin",
            "\(home)/.npm-global/bin",
        ]
        var parts = extra
        if let existing = env["PATH"], !existing.isEmpty {
            parts.append(existing)
        }
        env["PATH"] = parts.joined(separator: ":")
        return env
    }

    /// Single-quote a string for safe interpolation into a shell command line.
    static func quote(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

/// Strips ANSI color/formatting escape sequences (the scripts emit bold + color
/// codes) and carriage returns from a line of output.
enum ANSI {
    private static let regex = try? NSRegularExpression(
        pattern: "\u{1B}\\[[0-9;]*[A-Za-z]"
    )

    static func strip(_ s: String) -> String {
        var out = s.replacingOccurrences(of: "\r", with: "")
        guard let regex else { return out }
        let range = NSRange(out.startIndex..., in: out)
        out = regex.stringByReplacingMatches(in: out, options: [], range: range, withTemplate: "")
        return out
    }
}

/// Accumulates streamed chunks and emits complete lines as they arrive.
final class LineBuffer {
    private var partial = ""

    func append(_ chunk: String) -> [String] {
        partial += chunk
        var lines: [String] = []
        while let idx = partial.firstIndex(of: "\n") {
            lines.append(String(partial[partial.startIndex..<idx]))
            partial = String(partial[partial.index(after: idx)...])
        }
        return lines
    }

    func flush() -> String {
        defer { partial = "" }
        return partial
    }
}
