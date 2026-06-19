import SwiftUI
import AppKit

/// The Settings dialog, in two sections: **App settings** (Hangar's own
/// preferences — scripts folder and appearance, stored on this Mac) and
/// **Hangar settings** (the `.settings` shell file the setup scripts read:
/// local projects directory, billing account, Cloudflare token, and zones).
struct SettingsSheet: View {
    @EnvironmentObject var controller: AppController
    @Environment(\.dismiss) private var dismiss
    @StateObject private var draft: SettingsDraft
    @AppStorage("appTheme") private var appTheme: AppTheme = .system
    @State private var revealToken = false
    @State private var scriptsDirError: String?
    @ObservedObject private var updateManager = UpdateManager.shared

    init(settings: Settings) {
        _draft = StateObject(wrappedValue: SettingsDraft(settings))
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    sectionHeader("App settings",
                                  subtitle: "Hangar's own preferences — saved on this Mac, not in .settings.")

                    FormField(label: "Setup scripts folder") {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Text(controller.scriptsDirectory ?? "Not set")
                                    .font(.system(.body, design: .monospaced))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .background(.quaternary.opacity(0.5),
                                                in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                                    .help(controller.scriptsDirectory ?? "")
                                Button("Change…") { chooseScriptsDir() }
                            }
                            if let scriptsDirError {
                                Text(scriptsDirError)
                                    .font(.caption).foregroundStyle(.red)
                            } else {
                                Text("Where Hangar finds the scripts and this .settings file.")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    FormField(label: "Appearance") {
                        Picker("Appearance", selection: $appTheme) {
                            ForEach(AppTheme.allCases) { theme in
                                Text(theme.label).tag(theme)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                    }

                    Divider().padding(.vertical, 2)

                    sectionHeader("Hangar settings",
                                  subtitle: "Stored in .settings — read by every setup script.")

                    FormField(label: "Local projects directory") {
                        HStack(spacing: 8) {
                            monoTextField("$HOME/Projects", text: $draft.localProjectsDir)
                            Button("Choose…") { chooseProjectsDir() }
                        }
                    }
                    FormField(label: "Billing account ID") {
                        monoTextField("0105D0-22C2AE-D5A09B", text: $draft.billingAccountID)
                    }
                    FormField(label: "Cloudflare API token") {
                        tokenField
                    }
                    FormField(label: "Cloudflare zones") {
                        zonesEditor
                    }

                    Divider().padding(.vertical, 2)

                    sectionHeader("Updates",
                                  subtitle: "Check for updates and manage Hangar versions.")

                    updatesSection
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 8)
            }

            Divider()
            footer
        }
        .frame(width: 520)
        .frame(maxHeight: 640)
    }

    // MARK: - Header / footer

    private var header: some View {
        HStack(spacing: 11) {
            Image(systemName: "gearshape.fill")
                .font(.title2)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text("Settings").font(.headline)
                Text("Hangar preferences and setup-script configuration")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 22)
        .padding(.bottom, 10)
    }

    private func sectionHeader(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(subtitle)
                .font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var footer: some View {
        HStack {
            Text(savePathHint)
                .font(.caption).foregroundStyle(.secondary)
                .lineLimit(1).truncationMode(.middle)
            Spacer()
            Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
            Button("Save") {
                controller.saveSettings(draft.toSettings())
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(controller.scriptsDirectory == nil)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    private var savePathHint: String {
        guard let dir = controller.scriptsDirectory else {
            return "No setup scripts folder selected"
        }
        return "Saved to \(dir)/.settings"
    }

    // MARK: - Fields

    private var tokenField: some View {
        HStack(spacing: 8) {
            Group {
                if revealToken {
                    TextField("cfut_…", text: $draft.cloudflareAPIToken)
                } else {
                    SecureField("cfut_…", text: $draft.cloudflareAPIToken)
                }
            }
            .textFieldStyle(.roundedBorder)
            .font(.system(.body, design: .monospaced))

            Button {
                revealToken.toggle()
            } label: {
                Image(systemName: revealToken ? "eye.slash" : "eye")
            }
            .buttonStyle(.borderless)
            .help(revealToken ? "Hide token" : "Show token")
        }
    }

    private var zonesEditor: some View {
        VStack(spacing: 8) {
            if !draft.zones.isEmpty {
                HStack(spacing: 6) {
                    columnHeader("Domain")
                    columnHeader("Zone ID")
                    Spacer().frame(width: 22)
                }
            }
            ForEach(draft.zones) { zone in
                HStack(spacing: 6) {
                    TextField("example.com", text: Binding(
                        get: { zone.domain },
                        set: { draft.setDomain(id: zone.id, $0) }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))

                    TextField("zone id", text: Binding(
                        get: { zone.zoneID },
                        set: { draft.setZoneID(id: zone.id, $0) }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))

                    Button {
                        draft.removeZone(id: zone.id)
                    } label: {
                        Image(systemName: "minus.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .help("Remove zone")
                }
            }
            Button { draft.addZone() } label: {
                Label("Add zone", systemImage: "plus").font(.callout)
            }
            .buttonStyle(.borderless)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func columnHeader(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func monoTextField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.roundedBorder)
            .font(.system(.body, design: .monospaced))
    }

    // MARK: - Actions

    private func chooseScriptsDir() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        panel.message = "Select your setup scripts folder (the one containing setup-new-app.sh)"
        if let current = controller.scriptsDirectory {
            panel.directoryURL = URL(fileURLWithPath: current)
        }
        guard panel.runModal() == .OK, let url = panel.url else { return }

        guard Paths.isValidScriptsDir(url.path) else {
            scriptsDirError = "That folder doesn't contain setup-new-app.sh."
            return
        }
        scriptsDirError = nil
        controller.chooseScriptsDirectory(url.path)
        // The new folder has its own .settings — reload the rest of the form.
        draft.reseed(controller.currentSettings)
    }

    private func chooseProjectsDir() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        panel.message = "Select the folder where new projects are scaffolded"

        let expanded = Settings.expand(draft.localProjectsDir.trimmingCharacters(in: .whitespaces))
        if !expanded.isEmpty, FileManager.default.fileExists(atPath: expanded) {
            panel.directoryURL = URL(fileURLWithPath: expanded)
        }
        if panel.runModal() == .OK, let url = panel.url {
            draft.localProjectsDir = Settings.relativizeToHome(url.path)
        }
    }

    // MARK: - Updates

    private var updatesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("Current version:")
                    .font(.body)
                    .foregroundStyle(.secondary)
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    .font(.body.weight(.medium))
                
                Spacer()
                
                if updateManager.isChecking {
                    ProgressView()
                        .controlSize(.small)
                } else if updateManager.isDownloading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Button("Check for Updates") {
                        Task {
                            await updateManager.checkForUpdates()
                        }
                    }
                    .disabled(updateManager.isChecking || updateManager.isDownloading)
                }
            }
            
            if let error = updateManager.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            
            if updateManager.isUpdateAvailable, let latestVersion = updateManager.latestVersion {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(.blue)
                        Text("Version \(latestVersion) is available!")
                            .font(.body.weight(.semibold))
                        Spacer()
                    }
                    
                    if let notes = updateManager.latestReleaseNotes, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        ScrollView {
                            Text(notes)
                                .font(.caption.weight(.regular))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }
                        .frame(maxHeight: 100)
                        .padding(8)
                        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 6))
                    }
                    
                    HStack {
                        Spacer()
                        if updateManager.isDownloading {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Downloading update…")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Button("Install & Relaunch") {
                                Task {
                                    await updateManager.installUpdate()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
                .padding(12)
                .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(.blue.opacity(0.3), lineWidth: 1)
                )
            } else if !updateManager.isChecking {
                Text("Hangar is up to date.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
