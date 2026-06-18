import Foundation

/// A minimal parser for the `.deploy-secrets` shell file that sits alongside the
/// setup scripts. We only read the couple of values the GUI needs; everything
/// else (Cloudflare tokens, billing account) stays in the script's hands.
struct DeploySecrets {
    var localProjectsDir: String?
    var billingAccountID: String?

    static func load(from path: String) -> DeploySecrets {
        var result = DeploySecrets()
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            return result
        }

        for rawLine in content.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.hasPrefix("#"), let eq = line.firstIndex(of: "=") else { continue }

            let key = String(line[..<eq]).trimmingCharacters(in: .whitespaces)
            var value = String(line[line.index(after: eq)...]).trimmingCharacters(in: .whitespaces)
            value = value.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            value = Self.expand(value)

            switch key {
            case "LOCAL_PROJECTS_DIR": result.localProjectsDir = value
            case "BILLING_ACCOUNT_ID": result.billingAccountID = value
            default: break
            }
        }
        return result
    }

    /// Expand `$HOME`, `${HOME}` and a leading `~` the way the shell would.
    private static func expand(_ raw: String) -> String {
        let home = NSHomeDirectory()
        var out = raw
            .replacingOccurrences(of: "${HOME}", with: home)
            .replacingOccurrences(of: "$HOME", with: home)
        if out == "~" {
            out = home
        } else if out.hasPrefix("~/") {
            out = home + out.dropFirst()
        }
        return out
    }
}
