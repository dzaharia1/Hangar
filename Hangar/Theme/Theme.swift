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

    /// Built once — this used to be a local, so every `AppGlyph` body rebuilt all
    /// 26 palettes (52 `Color` allocations) just to index one of them.
    private static let palettes: [[Color]] = [
        // A - Amber Gold
        [Color(red: 1.00, green: 0.76, blue: 0.24), Color(red: 0.98, green: 0.52, blue: 0.14)],
        // B - Bermuda Teal
        [Color(red: 0.10, green: 0.86, blue: 0.80), Color(red: 0.05, green: 0.58, blue: 0.84)],
        // C - Coral Blush
        [Color(red: 1.00, green: 0.48, blue: 0.56), Color(red: 1.00, green: 0.72, blue: 0.52)],
        // D - Deep Violet
        [Color(red: 0.56, green: 0.36, blue: 0.98), Color(red: 0.74, green: 0.52, blue: 1.00)],
        // E - Emerald Moss
        [Color(red: 0.10, green: 0.80, blue: 0.48), Color(red: 0.42, green: 0.94, blue: 0.56)],
        // F - Fuchsia Splash
        [Color(red: 1.00, green: 0.16, blue: 0.62), Color(red: 1.00, green: 0.46, blue: 0.84)],
        // G - Glacier Mint
        [Color(red: 0.36, green: 0.94, blue: 0.86), Color(red: 0.08, green: 0.68, blue: 0.82)],
        // H - Heather Lavender
        [Color(red: 0.72, green: 0.56, blue: 1.00), Color(red: 0.90, green: 0.78, blue: 1.00)],
        // I - Indigo Night
        [Color(red: 0.32, green: 0.40, blue: 1.00), Color(red: 0.50, green: 0.60, blue: 1.00)],
        // J - Jasmine Yellow
        [Color(red: 1.00, green: 0.90, blue: 0.36), Color(red: 1.00, green: 0.66, blue: 0.14)],
        // K - Kelp Green
        [Color(red: 0.12, green: 0.72, blue: 0.46), Color(red: 0.46, green: 0.92, blue: 0.58)],
        // L - Lagoon Blue
        [Color(red: 0.06, green: 0.56, blue: 1.00), Color(red: 0.14, green: 0.86, blue: 1.00)],
        // M - Mulberry Plum
        [Color(red: 0.78, green: 0.20, blue: 0.54), Color(red: 1.00, green: 0.44, blue: 0.72)],
        // N - Neon Cyan
        [Color(red: 0.08, green: 0.92, blue: 0.96), Color(red: 0.14, green: 0.56, blue: 1.00)],
        // O - Orchid Rose
        [Color(red: 1.00, green: 0.48, blue: 0.84), Color(red: 1.00, green: 0.72, blue: 0.82)],
        // P - Peach Sunset
        [Color(red: 1.00, green: 0.60, blue: 0.38), Color(red: 1.00, green: 0.38, blue: 0.48)],
        // Q - Quartz Grey
        [Color(red: 0.60, green: 0.68, blue: 0.82), Color(red: 0.82, green: 0.88, blue: 0.98)],
        // R - Ruby Crimson
        [Color(red: 0.96, green: 0.14, blue: 0.32), Color(red: 1.00, green: 0.44, blue: 0.52)],
        // S - Seafoam Mint
        [Color(red: 0.28, green: 0.92, blue: 0.70), Color(red: 0.58, green: 1.00, blue: 0.86)],
        // T - Tangerine Peel
        [Color(red: 1.00, green: 0.52, blue: 0.18), Color(red: 1.00, green: 0.76, blue: 0.38)],
        // U - Ultramarine
        [Color(red: 0.22, green: 0.42, blue: 1.00), Color(red: 0.52, green: 0.72, blue: 1.00)],
        // V - Velvet Wine
        [Color(red: 0.82, green: 0.16, blue: 0.42), Color(red: 1.00, green: 0.40, blue: 0.60)],
        // W - Warm Copper
        [Color(red: 1.00, green: 0.54, blue: 0.24), Color(red: 1.00, green: 0.74, blue: 0.48)],
        // X - Xanthic Lime
        [Color(red: 0.82, green: 0.96, blue: 0.18), Color(red: 0.52, green: 0.90, blue: 0.24)],
        // Y - Yellow Gold
        [Color(red: 1.00, green: 0.86, blue: 0.24), Color(red: 0.98, green: 0.66, blue: 0.12)],
        // Z - Zircon Blue
        [Color(red: 0.30, green: 0.70, blue: 0.98), Color(red: 0.58, green: 0.90, blue: 1.00)],
    ]

    static func gradient(for seed: String) -> LinearGradient {
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
    ///
    /// The shadow hangs off the background *shape*, not off `self`. Applying
    /// `.shadow()` to the whole card makes SwiftUI rasterize all of the card's
    /// content into an offscreen buffer and blur its alpha just to derive a
    /// silhouette — twice, once per shadow. Since the background is an opaque
    /// rounded rect covering the full frame, that silhouette is always just the
    /// rounded rect, so shadowing the shape looks identical and lets Core
    /// Animation take the cheap path. Measured on a window drag: 81 → 100
    /// position updates/sec, p90 frame gap 27ms → 14ms.
    func elevatedCard(cornerRadius: CGFloat = 16) -> some View {
        self
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 3)
                    .shadow(color: .black.opacity(0.04), radius: 1, x: 0, y: 1)
            }
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
            )
    }
}
