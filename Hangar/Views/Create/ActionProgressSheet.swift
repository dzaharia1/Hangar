import SwiftUI

/// Streams the output of an archive or restore operation, then lets the user
/// dismiss once it's finished.
struct ActionProgressSheet: View {
    let action: AppAction
    @ObservedObject var runner: ScriptRunner
    @EnvironmentObject var controller: AppController

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                if runner.isRunning {
                    ProgressView().controlSize(.small)
                } else if runner.succeeded {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                } else {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                }
                Text(action.title)
                    .font(.title3.weight(.semibold))
                Spacer()
            }

            ConsoleView(runner: runner)
                .frame(minWidth: 560, minHeight: 320)

            HStack {
                Spacer()
                if runner.isRunning {
                    Button(role: .destructive) { runner.cancel() } label: {
                        Label("Stop", systemImage: "stop.fill")
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button("Done") { controller.finishAction() }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(20)
        .frame(width: 640, height: 460)
    }
}
