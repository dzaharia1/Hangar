import SwiftUI

enum Theme {
    /// The blue → violet gradient used by the scaffolded apps themselves.
    static let brandGradient = LinearGradient(
        colors: [Color(red: 0.36, green: 0.65, blue: 0.98),
                 Color(red: 0.66, green: 0.55, blue: 0.96)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    private static func stableHash(_ string: String) -> Int {
        var hash: UInt32 = 2166136261
        for byte in string.utf8 {
            hash ^= UInt32(byte)
            hash = hash &* 16777619
        }
        return Int(hash)
    }

    static func gradient(for seed: String) -> LinearGradient {
        let palettes: [[Color]] = [
            // A - Amber Gold
            [Color(red: 0.98, green: 0.70, blue: 0.20), Color(red: 0.85, green: 0.40, blue: 0.10)],
            // B - Bermuda Teal
            [Color(red: 0.12, green: 0.73, blue: 0.70), Color(red: 0.08, green: 0.45, blue: 0.65)],
            // C - Coral Blush
            [Color(red: 0.96, green: 0.45, blue: 0.55), Color(red: 0.98, green: 0.69, blue: 0.48)],
            // D - Deep Violet
            [Color(red: 0.30, green: 0.15, blue: 0.60), Color(red: 0.55, green: 0.35, blue: 0.85)],
            // E - Emerald Moss
            [Color(red: 0.05, green: 0.55, blue: 0.35), Color(red: 0.35, green: 0.75, blue: 0.45)],
            // F - Fuchsia Splash
            [Color(red: 0.90, green: 0.10, blue: 0.50), Color(red: 0.95, green: 0.40, blue: 0.75)],
            // G - Glacier Mint
            [Color(red: 0.45, green: 0.82, blue: 0.75), Color(red: 0.15, green: 0.55, blue: 0.65)],
            // H - Heather Lavender
            [Color(red: 0.66, green: 0.55, blue: 0.96), Color(red: 0.88, green: 0.75, blue: 0.95)],
            // I - Indigo Night
            [Color(red: 0.08, green: 0.12, blue: 0.36), Color(red: 0.25, green: 0.35, blue: 0.75)],
            // J - Jasmine Yellow
            [Color(red: 0.98, green: 0.85, blue: 0.38), Color(red: 0.95, green: 0.60, blue: 0.15)],
            // K - Kelp Green
            [Color(red: 0.10, green: 0.45, blue: 0.35), Color(red: 0.48, green: 0.72, blue: 0.52)],
            // L - Lagoon Blue
            [Color(red: 0.05, green: 0.45, blue: 0.85), Color(red: 0.20, green: 0.80, blue: 0.95)],
            // M - Mulberry Plum
            [Color(red: 0.50, green: 0.10, blue: 0.35), Color(red: 0.78, green: 0.30, blue: 0.55)],
            // N - Neon Cyan
            [Color(red: 0.05, green: 0.80, blue: 0.85), Color(red: 0.15, green: 0.45, blue: 0.85)],
            // O - Orchid Rose
            [Color(red: 0.92, green: 0.45, blue: 0.78), Color(red: 0.98, green: 0.70, blue: 0.75)],
            // P - Peach Sunset
            [Color(red: 0.98, green: 0.55, blue: 0.36), Color(red: 0.96, green: 0.34, blue: 0.45)],
            // Q - Quartz Grey
            [Color(red: 0.35, green: 0.40, blue: 0.50), Color(red: 0.65, green: 0.70, blue: 0.80)],
            // R - Ruby Crimson
            [Color(red: 0.80, green: 0.08, blue: 0.20), Color(red: 0.98, green: 0.35, blue: 0.45)],
            // S - Seafoam Mint
            [Color(red: 0.30, green: 0.78, blue: 0.62), Color(red: 0.60, green: 0.90, blue: 0.80)],
            // T - Tangerine Peel
            [Color(red: 0.96, green: 0.45, blue: 0.18), Color(red: 0.98, green: 0.72, blue: 0.36)],
            // U - Ultramarine
            [Color(red: 0.10, green: 0.25, blue: 0.85), Color(red: 0.45, green: 0.65, blue: 0.98)],
            // V - Velvet Wine
            [Color(red: 0.45, green: 0.05, blue: 0.20), Color(red: 0.70, green: 0.20, blue: 0.45)],
            // W - Warm Copper
            [Color(red: 0.80, green: 0.40, blue: 0.20), Color(red: 0.92, green: 0.65, blue: 0.45)],
            // X - Xanthic Lime
            [Color(red: 0.75, green: 0.85, blue: 0.15), Color(red: 0.45, green: 0.75, blue: 0.20)],
            // Y - Yellow Gold
            [Color(red: 0.98, green: 0.82, blue: 0.20), Color(red: 0.80, green: 0.60, blue: 0.10)],
            // Z - Zircon Blue
            [Color(red: 0.25, green: 0.55, blue: 0.75), Color(red: 0.55, green: 0.80, blue: 0.90)],
        ]
        let clean = seed.trimmingCharacters(in: .whitespacesAndNewlines)
        let firstChar = clean.first?.uppercased() ?? ""
        let secondChar = clean.dropFirst().first?.uppercased() ?? ""
        let index: Int
        if let ascii1 = firstChar.unicodeScalars.first?.value, ascii1 >= 65 && ascii1 <= 90,
           let ascii2 = secondChar.unicodeScalars.first?.value, ascii2 >= 65 && ascii2 <= 90 {
            index = Int(ascii1 + ascii2) % palettes.count
        } else if let ascii1 = firstChar.unicodeScalars.first?.value, ascii1 >= 65 && ascii1 <= 90 {
            index = Int(ascii1 - 65) % palettes.count
        } else {
            index = abs(stableHash(clean)) % palettes.count
        }
        return LinearGradient(colors: palettes[index], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

extension View {
    /// A Liquid Glass surface on Tahoe, degrading to a translucent material on
    /// anything older.
    @ViewBuilder
    func glassCard(cornerRadius: CGFloat = 16) -> some View {
        #if compiler(>=6.3)
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            self.background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        #else
        self.background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        #endif
    }

    /// A card with the default app background color and shadow/elevation.
    func elevatedCard(cornerRadius: CGFloat = 16) -> some View {
        self
            .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 3)
            .shadow(color: .black.opacity(0.04), radius: 1, x: 0, y: 1)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
            )
    }
}
