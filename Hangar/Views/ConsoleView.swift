import SwiftUI

/// A terminal-style live log that auto-scrolls as new lines arrive.
struct ConsoleView: View {
    @ObservedObject var runner: ScriptRunner

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    ForEach(runner.lines) { line in
                        Text(line.text.isEmpty ? " " : line.text)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(color(for: line.kind))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(line.id)
                    }
                    Color.clear.frame(height: 1).id(Self.bottomAnchor)
                }
                .padding(14)
            }
            .onChange(of: runner.lines.count) { _, _ in
                withAnimation(.easeOut(duration: 0.15)) {
                    proxy.scrollTo(Self.bottomAnchor, anchor: .bottom)
                }
            }
        }
        .background(Color(red: 0.07, green: 0.08, blue: 0.10))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        )
    }

    private static let bottomAnchor = "console-bottom"

    private func color(for kind: LogLine.Kind) -> Color {
        switch kind {
        case .command: return Color(red: 0.55, green: 0.78, blue: 1.0)
        case .success: return Color(red: 0.45, green: 0.86, blue: 0.55)
        case .failure: return Color(red: 0.98, green: 0.49, blue: 0.49)
        case .warning: return Color(red: 0.98, green: 0.78, blue: 0.40)
        case .normal: return Color(white: 0.85)
        }
    }
}
