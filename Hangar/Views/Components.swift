import SwiftUI
import AppKit

/// A rounded gradient tile showing an app's initials — stands in for real
/// per-app iconography until those exist.
struct AppGlyph: View {
    let id: String
    let name: String
    var size: CGFloat = 28

    private var initials: String {
        let words = name.split(separator: " ")
        let letters = words.prefix(2).compactMap { $0.first }
        let result = String(letters).uppercased()
        return result.isEmpty ? "?" : result
    }

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(Theme.gradient(for: id))
            .frame(width: size, height: size)
            .overlay(
                Text(initials)
                    .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                    .strokeBorder(.white.opacity(0.18), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.18), radius: size * 0.08, y: size * 0.04)
    }
}

/// Small pill describing an app's status.
struct StatusBadge: View {
    let status: AppStatus

    private var label: String {
        switch status {
        case .active: return "Active"
        case .removed: return "Archived"
        case .creating: return "Provisioning"
        }
    }

    private var color: Color {
        switch status {
        case .active: return .green
        case .removed: return .secondary
        case .creating: return .orange
        }
    }

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(.quaternary, in: Capsule())
    }
}

/// A titled card used to group a section of the detail view.
struct SectionCard<Content: View, HeaderTrailing: View>: View {
    let title: String
    let systemImage: String
    var headerTrailing: () -> HeaderTrailing
    @ViewBuilder var content: Content

    init(
        title: String,
        systemImage: String,
        @ViewBuilder headerTrailing: @escaping () -> HeaderTrailing,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.headerTrailing = headerTrailing
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(title, systemImage: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                headerTrailing()
            }
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 14)
    }
}

extension SectionCard where HeaderTrailing == EmptyView {
    init(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            title: title,
            systemImage: systemImage,
            headerTrailing: { EmptyView() },
            content: content
        )
    }
}

/// A single label/value row with an optional trailing action.
struct DetailRow<Trailing: View>: View {
    let icon: String
    let value: String
    var monospaced = false
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 18)
            Text(value)
                .font(monospaced ? .system(.body, design: .monospaced) : .body)
                .textSelection(.enabled)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 8)
            trailing
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 10)
        .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

/// A compact, borderless icon button used for row actions (open / copy).
struct IconActionButton: View {
    let systemImage: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body)
        }
        .buttonStyle(.borderless)
        .help(help)
    }
}

// MARK: - Platform helpers

enum Clipboard {
    static func copy(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }
}

enum Browser {
    static func open(_ url: URL?) {
        guard let url else { return }
        NSWorkspace.shared.open(url)
    }

    static func revealInFinder(_ path: String) {
        let url = URL(fileURLWithPath: path)
        if FileManager.default.fileExists(atPath: path) {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } else {
            // Fall back to opening the parent directory if the leaf is missing.
            NSWorkspace.shared.activateFileViewerSelecting([url.deletingLastPathComponent()])
        }
    }
}
