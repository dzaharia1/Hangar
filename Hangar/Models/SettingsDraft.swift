import Foundation
import Combine

/// Backing state for the Settings dialog. Seeded from the on-disk `Settings` and
/// flattened back into one with `toSettings()` when the user saves.
@MainActor
final class SettingsDraft: ObservableObject {
    @Published var localProjectsDir: String
    @Published var billingAccountID: String
    @Published var cloudflareAPIToken: String
    @Published var zones: [CloudflareZone]

    init(_ settings: Settings) {
        localProjectsDir = settings.localProjectsDir
        billingAccountID = settings.billingAccountID
        cloudflareAPIToken = settings.cloudflareAPIToken
        zones = settings.cloudflareZones
    }

    /// Re-point the draft at a different `.settings` (e.g. after the user
    /// changes the scripts folder while the dialog is open). Discards any
    /// unsaved edits, which is intentional — they belonged to the old file.
    func reseed(_ settings: Settings) {
        localProjectsDir = settings.localProjectsDir
        billingAccountID = settings.billingAccountID
        cloudflareAPIToken = settings.cloudflareAPIToken
        zones = settings.cloudflareZones
    }

    func addZone() {
        zones.append(CloudflareZone(domain: "", zoneID: ""))
    }

    func removeZone(id: UUID) {
        zones.removeAll { $0.id == id }
    }

    func setDomain(id: UUID, _ value: String) {
        if let index = zones.firstIndex(where: { $0.id == id }) { zones[index].domain = value }
    }

    func setZoneID(id: UUID, _ value: String) {
        if let index = zones.firstIndex(where: { $0.id == id }) { zones[index].zoneID = value }
    }

    func toSettings() -> Settings {
        Settings(
            localProjectsDir: localProjectsDir.trimmingCharacters(in: .whitespaces),
            billingAccountID: billingAccountID.trimmingCharacters(in: .whitespaces),
            cloudflareAPIToken: cloudflareAPIToken.trimmingCharacters(in: .whitespaces),
            cloudflareZones: zones
        )
    }
}
