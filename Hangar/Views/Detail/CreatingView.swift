import SwiftUI

/// Shown in the detail pane while a new app is being provisioned. On success the
/// controller swaps this out for the real detail page; on failure we stay here
/// so the error stays on screen.
struct CreatingView: View {
    let app: ManagedApp
    @ObservedObject var runner: ScriptRunner
    @EnvironmentObject var controller: AppController

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            ConsoleView(runner: runner)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            if !runner.isRunning, !runner.succeeded {
                footer
            }
        }
        .padding(24)
    }

    private var header: some View {
        HStack(spacing: 14) {
            AppGlyph(id: app.id, name: app.name, size: 48)
            VStack(alignment: .leading, spacing: 4) {
                Text(app.name)
                    .font(.title.weight(.bold))
                HStack(spacing: 8) {
                    if runner.isRunning {
                        ProgressView().controlSize(.small)
                        Text("Provisioning — running setup-new-app.sh…")
                            .foregroundStyle(.secondary)
                    } else if runner.succeeded {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        Text("Done").foregroundStyle(.secondary)
                    } else {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                        Text("Setup failed (exit code \(runner.exitCode.map(String.init) ?? "?"))")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.callout)
            }
            Spacer()
            if runner.isRunning {
                Button(role: .destructive) {
                    runner.cancel()
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var footer: some View {
        HStack {
            Text("The app wasn't fully provisioned. Review the log above, fix the issue, and try again.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Dismiss") {
                controller.dismissCreation()
            }
            .buttonStyle(.bordered)
        }
        .padding(14)
        .glassCard(cornerRadius: 14)
    }
}
