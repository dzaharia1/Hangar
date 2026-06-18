import Foundation
import Combine

struct DomainEntry: Identifiable, Hashable {
    let id = UUID()
    var value: String
}

/// Backing state for the "Create a new app" dialog.
///
/// The app name is the single source of truth: as the user types it, the App ID,
/// domains, and Firebase Project ID auto-populate. The moment the user edits one
/// of those derived fields by hand, that field's auto-population is disabled and
/// it keeps whatever the user typed.
@MainActor
final class CreateDraft: ObservableObject {
    @Published private(set) var name = ""
    @Published private(set) var appID = ""
    @Published private(set) var domains: [DomainEntry] = []
    @Published private(set) var firebaseProjectID = ""

    @Published private(set) var appIDAuto = true
    @Published private(set) var domainsAuto = true
    @Published private(set) var firebaseAuto = true

    /// Apex domains used to build the two default custom domains, matching the
    /// shell script's default of `<id>.danzaharia.com, <id>.adanmade.app`.
    private let apexDomains = ["danzaharia.com", "adanmade.app"]
    private let firebaseSuffix = String(Int.random(in: 10000...99999))

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !appID.isEmpty
            && !firebaseProjectID.isEmpty
    }

    var domainValues: [String] {
        domains.map { $0.value.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    // MARK: - Edits coming from the UI

    func setName(_ newValue: String) {
        name = newValue
        if appIDAuto { appID = Self.slug(newValue) }
        recomputeDerived()
    }

    func setAppID(_ newValue: String) {
        appIDAuto = false
        appID = newValue
        recomputeDerived()
    }

    func setDomain(id: UUID, _ newValue: String) {
        domainsAuto = false
        if let index = domains.firstIndex(where: { $0.id == id }) {
            domains[index].value = newValue
        }
    }

    func addDomain() {
        domainsAuto = false
        domains.append(DomainEntry(value: ""))
    }

    func removeDomain(id: UUID) {
        domainsAuto = false
        domains.removeAll { $0.id == id }
    }

    func setFirebaseProjectID(_ newValue: String) {
        firebaseAuto = false
        firebaseProjectID = newValue
    }

    // MARK: - Auto-population

    private func recomputeDerived() {
        if domainsAuto {
            domains = appID.isEmpty
                ? []
                : apexDomains.map { DomainEntry(value: "\(appID).\($0)") }
        }
        if firebaseAuto {
            firebaseProjectID = appID.isEmpty ? "" : "\(appID)-\(firebaseSuffix)"
        }
    }

    /// Lowercase, hyphenate spaces, and drop anything that isn't a valid App ID /
    /// Firebase Project ID character. Mirrors (and tightens) the shell's
    /// `generate_app_id`.
    static func slug(_ raw: String) -> String {
        var out = ""
        var lastWasHyphen = false
        for ch in raw.lowercased() {
            if ch == " " || ch == "_" || ch == "-" {
                if !out.isEmpty && !lastWasHyphen {
                    out.append("-")
                    lastWasHyphen = true
                }
            } else if ch.isLetter || ch.isNumber {
                out.append(ch)
                lastWasHyphen = false
            }
        }
        while out.hasSuffix("-") { out.removeLast() }
        return out
    }
}
