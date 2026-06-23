import Foundation
import AppKit

struct GitHubRelease: Codable {
    let tagName: String
    let name: String
    let body: String?
    let prerelease: Bool
    let draft: Bool
    let assets: [GitHubAsset]
    
    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case prerelease
        case draft
        case assets
    }
}

struct GitHubAsset: Codable {
    let name: String
    let browserDownloadUrl: String
    
    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadUrl = "browser_download_url"
    }
}

@MainActor
final class UpdateManager: ObservableObject {
    static let shared = UpdateManager()
    
    @Published var isUpdateAvailable = false
    @Published var latestVersion: String?
    @Published var latestReleaseNotes: String?
    @Published var downloadURL: URL?
    
    @Published var isChecking = false
    @Published var isDownloading = false
    @Published var errorMessage: String?
    
    private var checkTimer: Timer?
    
    private init() {}
    
    func startPeriodicChecks() {
        // Initial check on launch
        Task {
            await checkForUpdates()
        }
        
        // Check once every 24 hours while open
        checkTimer?.invalidate()
        checkTimer = Timer.scheduledTimer(withTimeInterval: 86400, repeats: true) { [weak self] _ in
            Task {
                await self?.checkForUpdates()
            }
        }
    }
    
    func checkForUpdates() async {
        guard !isChecking && !isDownloading else { return }
        isChecking = true
        errorMessage = nil
        
        do {
            guard let url = URL(string: "https://api.github.com/repos/dzaharia1/Hangar/releases") else {
                throw NSError(domain: "UpdateManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
            }
            
            var request = URLRequest(url: url)
            request.setValue("Hangar-App-Updater", forHTTPHeaderField: "User-Agent")
            request.cachePolicy = .reloadIgnoringLocalCacheData
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw NSError(domain: "UpdateManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch releases (status code \((response as? HTTPURLResponse)?.statusCode ?? 0))"])
            }
            
            let decoder = JSONDecoder()
            let releases = try decoder.decode([GitHubRelease].self, from: data)
            
            // Find the latest non-draft, non-prerelease release that has a Hangar.zip asset
            let latest = releases.first { release in
                !release.draft && !release.prerelease && release.assets.contains { $0.name == "Hangar.zip" }
            }
            
            guard let latest = latest,
                  let zipAsset = latest.assets.first(where: { $0.name == "Hangar.zip" }),
                  let downloadURL = URL(string: zipAsset.browserDownloadUrl) else {
                self.isUpdateAvailable = false
                self.isChecking = false
                return
            }
            
            let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
            
            if isVersion(latest.tagName, newerThan: currentVersion) {
                self.latestVersion = latest.tagName
                self.latestReleaseNotes = latest.body
                self.downloadURL = downloadURL
                self.isUpdateAvailable = true
            } else {
                self.isUpdateAvailable = false
            }
        } catch {
            print("Update check error: \(error)")
            self.errorMessage = "Failed to check for updates: \(error.localizedDescription)"
        }
        isChecking = false
    }
    
    func installUpdate() async {
        guard let downloadURL = downloadURL else { return }
        isDownloading = true
        errorMessage = nil
        
        do {
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            
            let zipFileURL = tempDir.appendingPathComponent("HangarUpdate.zip")
            
            let (localURL, _) = try await URLSession.shared.download(from: downloadURL)
            try FileManager.default.moveItem(at: localURL, to: zipFileURL)
            
            try await unzip(archiveURL: zipFileURL, to: tempDir)
            
            let extractedAppURL = tempDir.appendingPathComponent("Hangar.app")
            guard FileManager.default.fileExists(atPath: extractedAppURL.path) else {
                throw NSError(domain: "UpdateManager", code: -3, userInfo: [NSLocalizedDescriptionKey: "Extracted Hangar.app not found in zip archive."])
            }
            
            let targetAppPath = Bundle.main.bundlePath
            
            let currentPID = ProcessInfo.processInfo.processIdentifier
            let zshScript = """
            #!/bin/zsh
            # Wait for the main app to exit
            while kill -0 \(currentPID) 2>/dev/null; do
                sleep 0.1
            done

            # Replace the app
            rm -rf "\(targetAppPath)"
            cp -R "\(extractedAppURL.path)" "\(targetAppPath)"
            xattr -cr "\(targetAppPath)" 2>/dev/null

            # Relaunch the app
            open "\(targetAppPath)"

            # Clean up temporary directory
            rm -rf "\(tempDir.path)"
            """
            
            let scriptURL = tempDir.appendingPathComponent("update.sh")
            try zshScript.write(to: scriptURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = [scriptURL.path]
            try process.run()
            
            DispatchQueue.main.async {
                exit(0)
            }
        } catch {
            print("Installation failed: \(error)")
            self.errorMessage = "Failed to install update: \(error.localizedDescription)"
            isDownloading = false
        }
    }
    
    private func unzip(archiveURL: URL, to destinationURL: URL) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            process.arguments = ["-x", "-k", archiveURL.path, destinationURL.path]
            
            do {
                try process.run()
                process.waitUntilExit()
                if process.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: NSError(domain: "UnzipError", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "ditto exited with status \(process.terminationStatus)"]))
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    private func isVersion(_ version1: String, newerThan version2: String) -> Bool {
        let v1 = version1.trimmingCharacters(in: CharacterSet(charactersIn: "vV")).split(separator: ".").compactMap { Int($0) }
        let v2 = version2.trimmingCharacters(in: CharacterSet(charactersIn: "vV")).split(separator: ".").compactMap { Int($0) }
        
        for i in 0..<max(v1.count, v2.count) {
            let num1 = i < v1.count ? v1[i] : 0
            let num2 = i < v2.count ? v2[i] : 0
            if num1 > num2 {
                return true
            } else if num1 < num2 {
                return false
            }
        }
        return false
    }
}
