import SwiftUI

/// The colors of one appearance (dark or light) with one blue. Blue and white is the brand:
/// the blue is the accent, white is the text on it, and goals bring every other color.
struct Palette: Equatable {
    var bg: Color
    var card: Color
    var elevated: Color
    var text: Color
    var secondary: Color
    var muted: Color
    var line: Color
    var border: Color
    var accent: Color
    var onAccent: Color
    var danger: Color
    var isDark: Bool

    var accentSoft: Color { accent.opacity(isDark ? 0.2 : 0.12) }
    var dangerSoft: Color { danger.opacity(0.16) }
    /// Text over a goal's color band: near-black on the bright dark-mode shades, white on the
    /// deeper light-mode ones.
    var onBand: Color { isDark ? Color(hex: 0x0A0D14) : .white }

    /// A goal's color in this appearance.
    func color(_ c: GoalColor) -> Color { Color(hex: c.hex(dark: isDark)) }

    static func accentHex(_ scheme: BlueScheme, dark: Bool) -> UInt32 {
        switch (scheme, dark) {
        case (.royal, true): return 0x3B7BFF
        case (.royal, false): return 0x1E5BE6
        case (.tech, true): return 0x0A84FF
        case (.tech, false): return 0x007AFF
        }
    }

    static func make(scheme: BlueScheme, dark: Bool) -> Palette {
        let accent = Color(hex: accentHex(scheme, dark: dark))
        if dark {
            return Palette(bg: Color(hex: 0x0A0D14), card: Color(hex: 0x131826), elevated: Color(hex: 0x1C2335),
                           text: Color(hex: 0xF4F6FB), secondary: Color(hex: 0xA3ABBD), muted: Color(hex: 0x8A93A6),
                           line: Color(hex: 0x232B3D), border: Color(hex: 0x36405A), accent: accent, onAccent: .white,
                           danger: Color(hex: 0xFF8A94), isDark: true)
        }
        return Palette(bg: Color(hex: 0xF5F7FC), card: .white, elevated: Color(hex: 0xE8ECF5),
                       text: Color(hex: 0x0F1626), secondary: Color(hex: 0x4A5368), muted: Color(hex: 0x6C778C),
                       line: Color(hex: 0xE1E6F0), border: Color(hex: 0xC6CEDD), accent: accent, onAccent: .white,
                       danger: Color(hex: 0xC8313F), isDark: false)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}

private struct PaletteKey: EnvironmentKey { static let defaultValue = Palette.make(scheme: .royal, dark: true) }

extension EnvironmentValues {
    var palette: Palette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}

enum Radius {
    static let card: CGFloat = 22
    static let row: CGFloat = 18
    static let field: CGFloat = 12
    static let chip: CGFloat = 10
    static let button: CGFloat = 14
}
