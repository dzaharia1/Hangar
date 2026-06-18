import SwiftUI

enum Theme {
    /// The blue → violet gradient used by the scaffolded apps themselves.
    static let brandGradient = LinearGradient(
        colors: [Color(red: 0.36, green: 0.65, blue: 0.98),
                 Color(red: 0.66, green: 0.55, blue: 0.96)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static func gradient(for seed: String) -> LinearGradient {
        let palettes: [[Color]] = [
            [Color(red: 0.36, green: 0.65, blue: 0.98), Color(red: 0.66, green: 0.55, blue: 0.96)],
            [Color(red: 0.96, green: 0.45, blue: 0.55), Color(red: 0.98, green: 0.69, blue: 0.38)],
            [Color(red: 0.30, green: 0.78, blue: 0.62), Color(red: 0.36, green: 0.65, blue: 0.98)],
            [Color(red: 0.55, green: 0.45, blue: 0.96), Color(red: 0.92, green: 0.45, blue: 0.78)],
            [Color(red: 0.98, green: 0.55, blue: 0.36), Color(red: 0.96, green: 0.34, blue: 0.45)],
        ]
        let index = abs(seed.hashValue) % palettes.count
        return LinearGradient(colors: palettes[index], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

extension View {
    /// A Liquid Glass surface on Tahoe, degrading to a translucent material on
    /// anything older.
    @ViewBuilder
    func glassCard(cornerRadius: CGFloat = 16) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            self.background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }
}
