import Foundation

/// One Cloudflare zone mapping — a domain and the zone ID its DNS records are
/// written into. In `.settings` it lives as a single `"domain:zone_id"` string
/// inside the `CLOUDFLARE_ZONES` Bash array.
struct CloudflareZone: Identifiable {
    let id = UUID()
    var domain: String
    var zoneID: String
}

/// The contents of the `.settings` shell file that every setup script `source`s
/// (`setup-new-app.sh`, `remove-app.sh`, `host-manager.sh`).
///
/// It's plain Bash, so we read and write it line-by-line rather than as JSON.
/// Recognised keys: `LOCAL_PROJECTS_DIR`, `BILLING_ACCOUNT_ID`,
/// `CLOUDFLARE_API_TOKEN` (scalar `KEY="value"`) and `CLOUDFLARE_ZONES`
/// (a Bash array of `"domain:zone_id"` entries).
struct Settings {
    /// Stored raw (unexpanded) so a `$HOME` / `~` prefix survives a round-trip.
    var localProjectsDir = "$HOME/Projects"
    var billingAccountID = ""
    var cloudflareAPIToken = ""
    var cloudflareZones: [CloudflareZone] = []

    /// `LOCAL_PROJECTS_DIR` with `$HOME` / `~` expanded, for use on disk. `nil`
    /// when blank.
    var expandedLocalProjectsDir: String? {
        let trimmed = localProjectsDir.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : Self.expand(trimmed)
    }

    // MARK: - Loading

    static func load(from path: String) -> Settings {
        var result = Settings()
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            return result
        }

        let lines = content.components(separatedBy: .newlines)
        var i = 0
        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            i += 1
            if line.hasPrefix("#") || line.isEmpty { continue }

            // The zones array may open and close on one line or span several,
            // up to the line that contains the closing ")".
            if line.hasPrefix("CLOUDFLARE_ZONES=(") {
                var body = String(line.dropFirst("CLOUDFLARE_ZONES=(".count))
                while !body.contains(")") && i < lines.count {
                    body += "\n" + lines[i]
                    i += 1
                }
                if let close = body.firstIndex(of: ")") {
                    body = String(body[..<close])
                }
                result.cloudflareZones = parseZones(body)
                continue
            }

            guard let eq = line.firstIndex(of: "=") else { continue }
            let key = String(line[..<eq]).trimmingCharacters(in: .whitespaces)
            let value = unquote(String(line[line.index(after: eq)...]).trimmingCharacters(in: .whitespaces))
            switch key {
            case "LOCAL_PROJECTS_DIR": result.localProjectsDir = value
            case "BILLING_ACCOUNT_ID": result.billingAccountID = value
            case "CLOUDFLARE_API_TOKEN": result.cloudflareAPIToken = value
            default: break
            }
        }
        return result
    }

    /// Pull every quoted `"domain:zone_id"` token out of the array body.
    private static func parseZones(_ body: String) -> [CloudflareZone] {
        var zones: [CloudflareZone] = []
        var current = ""
        var inQuote = false
        for ch in body {
            if ch == "\"" {
                if inQuote {
                    zones.append(makeZone(from: current))
                    current = ""
                }
                inQuote.toggle()
            } else if inQuote {
                current.append(ch)
            }
        }
        return zones.filter { !$0.domain.isEmpty || !$0.zoneID.isEmpty }
    }

    /// Split a `domain:zone_id` token on its first colon.
    private static func makeZone(from token: String) -> CloudflareZone {
        if let colon = token.firstIndex(of: ":") {
            return CloudflareZone(domain: String(token[..<colon]),
                                  zoneID: String(token[token.index(after: colon)...]))
        }
        return CloudflareZone(domain: token, zoneID: "")
    }

    private static func unquote(_ raw: String) -> String {
        guard raw.count >= 2 else { return raw }
        if (raw.hasPrefix("\"") && raw.hasSuffix("\"")) || (raw.hasPrefix("'") && raw.hasSuffix("'")) {
            return String(raw.dropFirst().dropLast())
        }
        return raw
    }

    // MARK: - Saving

    /// Render the file the way `.settings.example` is laid out, so it stays
    /// readable when opened by hand.
    func serialized() -> String {
        var out = ""
        out += "# Global configuration and settings for setup scripts\n"
        out += "# Managed by the Let Dan Code app — sourced by every setup script at runtime.\n"
        out += "# Do NOT commit this file to git.\n\n"

        out += "# Local directory where projects are scaffolded and stored\n"
        out += "LOCAL_PROJECTS_DIR=\"\(localProjectsDir)\"\n\n"

        out += "# Google Cloud / Firebase Billing Account ID (used to link new projects to billing)\n"
        out += "BILLING_ACCOUNT_ID=\"\(billingAccountID)\"\n\n"

        out += "# Cloudflare Zone mappings (format: \"domain:zone_id\")\n"
        out += "# This format is fully compatible with Bash 3.x (macOS default bash)\n"
        out += "CLOUDFLARE_ZONES=(\n"
        for zone in cloudflareZones {
            let domain = zone.domain.trimmingCharacters(in: .whitespaces)
            let zid = zone.zoneID.trimmingCharacters(in: .whitespaces)
            guard !domain.isEmpty || !zid.isEmpty else { continue }
            out += "  \"\(domain):\(zid)\"\n"
        }
        out += ")\n\n"

        out += "# Cloudflare API token with Edit DNS zone permissions\n"
        out += "CLOUDFLARE_API_TOKEN=\"\(cloudflareAPIToken)\"\n"
        return out
    }

    func write(to path: String) throws {
        try serialized().write(toFile: path, atomically: true, encoding: .utf8)
    }

    // MARK: - Path helpers

    /// Expand `$HOME`, `${HOME}` and a leading `~` the way the shell would.
    static func expand(_ raw: String) -> String {
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

    /// Re-relativize an absolute path under the home directory back to a
    /// `$HOME`-prefixed form, matching the convention in the example file.
    static func relativizeToHome(_ path: String) -> String {
        let home = NSHomeDirectory()
        if path == home { return "$HOME" }
        if path.hasPrefix(home + "/") { return "$HOME" + path.dropFirst(home.count) }
        return path
    }
}
