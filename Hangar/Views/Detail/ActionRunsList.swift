import SwiftUI

struct ActionRunsList: View {
    let app: ManagedApp

    @State private var runs: [ActionRun] = []
    @State private var loading = false
    @State private var errorMessage: String?

    var body: some View {
        SectionCard(title: "Action runs", systemImage: "play.circle") {
            VStack(spacing: 8) {
                HStack {
                    Spacer()
                    Button {
                        Task { await load() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    .help("Refresh runs")
                    .disabled(loading || app.githubSlug == nil)
                }

                content
            }
        }
        .task(id: app.id) { await load() }
    }

    @ViewBuilder
    private var content: some View {
        if app.githubSlug == nil {
            placeholder("No GitHub repo to read runs from.")
        } else if loading {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Loading runs…").foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
        } else if let errorMessage {
            placeholder(errorMessage)
        } else if runs.isEmpty {
            placeholder("No workflow runs yet.")
        } else {
            ForEach(runs) { run in
                ActionRunRow(run: run)
            }
        }
    }

    private func placeholder(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
    }

    private func load() async {
        guard let slug = app.githubSlug else { return }
        loading = true
        errorMessage = nil
        do {
            runs = try await GitHubService.fetchRuns(repoSlug: slug)
        } catch {
            errorMessage = error.localizedDescription
        }
        loading = false
    }
}

struct ActionRunRow: View {
    let run: ActionRun

    var body: some View {
        HStack(spacing: 12) {
            icon
            VStack(alignment: .leading, spacing: 2) {
                Text(run.displayTitle)
                    .font(.body)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if let link = run.link {
                IconActionButton(systemImage: "arrow.up.right", help: "Open on GitHub") {
                    Browser.open(link)
                }
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    @ViewBuilder
    private var icon: some View {
        switch run.state {
        case .running:
            ProgressView().controlSize(.small).frame(width: 18)
        case .success:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).frame(width: 18)
        case .failure:
            Image(systemName: "xmark.circle.fill").foregroundStyle(.red).frame(width: 18)
        case .neutral:
            Image(systemName: "minus.circle.fill").foregroundStyle(.secondary).frame(width: 18)
        }
    }

    private var subtitle: String {
        var parts: [String] = []
        if let workflow = run.workflowName, !workflow.isEmpty { parts.append(workflow) }
        if let date = run.createdAt { parts.append(Self.relative.localizedString(for: date, relativeTo: Date())) }
        if let branch = run.headBranch, !branch.isEmpty { parts.append(branch) }
        return parts.joined(separator: " · ")
    }

    private static let relative: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()
}
