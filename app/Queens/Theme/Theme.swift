import SwiftUI

/// Tokens from DESIGN.md. No colour or font literals outside this file.
enum Theme {
    static let paper = Color(hex: 0xfbfcfd)
    static let card = Color.white
    static let sunken = Color(hex: 0xf1f3f6)
    static let border = Color(hex: 0xd9dee6)
    static let ink = Color(hex: 0x2a3446)
    static let muted = Color(hex: 0x5a6578)
    static let pencil = Color(hex: 0x2a3446).opacity(0.28)
    static let error = Color(hex: 0xb8322a)
    static let success = Color(hex: 0x2f7d4f)

    static let regions: [Color] = [
        0xa8cbe0, 0xf2c58a, 0xb9d9a3, 0xe9a9a1, 0xcbb8de, 0xf1e28f,
        0x9ed1c6, 0xe6b8cf, 0xc9c48a, 0xf4b98c, 0xb4c1e3,
    ].map { Color(hex: $0) }

    static func region(_ index: Int) -> Color { regions[index % regions.count] }

    /// Unclaimed kingdoms paint lighter; a kingdom with its queen paints at full strength.
    static let washUnclaimed = 0.74
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255
        )
    }
}

enum SansWeight: String {
    case regular = "NunitoSans-Normal"
    case bold = "NunitoSans-NormalBold"
    case extraBold = "NunitoSans-NormalExtraBold"
}

extension Font {
    static func serif(_ size: CGFloat) -> Font { .custom("YoungSerif-Regular", size: size) }
    static func sans(_ size: CGFloat, _ weight: SansWeight = .regular) -> Font { .custom(weight.rawValue, size: size) }

    static let displayLg = serif(34)
    static let headlineMd = serif(28)
    static let headlineSm = serif(20)
    static let bodyMd = sans(16)
    static let bodySm = sans(14)
    static let labelMd = sans(15, .bold)
    static let timer = sans(15, .bold).monospacedDigit()
}

func formatTime(_ seconds: Double) -> String {
    let s = Int(seconds.rounded(.down))
    if s >= 3600 { return String(format: "%d:%02d:%02d", s / 3600, (s / 60) % 60, s % 60) }
    return String(format: "%d:%02d", s / 60, s % 60)
}
