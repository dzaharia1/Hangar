import Foundation

/// Locates the setup scripts and the shared registry on disk.
enum Paths {
    static let scriptsDirKey = "scriptsDirectory"

    /// The directory containing `setup-new-app.sh`, etc. Prefers a user-chosen
    /// location, then falls back to a couple of well-known spots.
    static var scriptsDirectory: String? {
        if let saved = UserDefaults.standard.string(forKey: scriptsDirKey),
           isValidScriptsDir(saved) {
            return saved
        }
        return defaultScriptsDirectory()
    }

    static func setScriptsDirectory(_ path: String) {
        UserDefaults.standard.set(path, forKey: scriptsDirKey)
    }

    static func defaultScriptsDirectory() -> String? {
        let home = NSHomeDirectory()
        let candidates = [
            "\(home)/Projects/server-setup-scripts/my-setup-scripts",
            "\(home)/Projects/my-setup-scripts",
            "\(home)/Projects/server-setup-scripts",
        ]
        return candidates.first(where: isValidScriptsDir)
    }

    static func isValidScriptsDir(_ path: String) -> Bool {
        FileManager.default.fileExists(atPath: "\(path)/setup-new-app.sh")
    }

    static func registryFile(in scriptsDir: String) -> String {
        "\(scriptsDir)/apps-registry/apps-registry.json"
    }

    static func deploySecretsFile(in scriptsDir: String) -> String {
        "\(scriptsDir)/.deploy-secrets"
    }

    static func settingsFile(in scriptsDir: String) -> String {
        "\(scriptsDir)/.settings"
    }
}
