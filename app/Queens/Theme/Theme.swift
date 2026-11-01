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
    /// Strength of marks made since the pin, which are pencilled rather than inked.
    static let pencilMark = 0.45
    static let error = Color(hex: 0xb8322a)
    static let success = Color(hex: 0x2f7d4f)
    /// Gilding for a solved board: crowns, sparkles, the stamp on the ribbon.
    static let gold = Color(hex: 0xd49a2a)
    static let goldDeep = Color(hex: 0x8a5a12)
    /// Sealing wax for the stamp on the solved ribbon.
    static let wax = Color(hex: 0x9c2f3c)
    static let waxDeep = Color(hex: 0x6e1f2a)

    static let regions: [Color] = [
        0xa8cbe0, 0xf2c58a, 0xb9d9a3, 0xe9a9a1, 0xcbb8de, 0xf1e28f,
        0x9ed1c6, 0xe6b8cf, 0xc9c48a, 0xf4b98c, 0xb4c1e3,
    ].map { Color(hex: $0) }

    /// How hints name each pigment, in the same order.
    static let regionNames = [
        "blue", "apricot", "green", "coral", "lavender", "yellow",
        "teal", "pink", "olive", "orange", "periwinkle",
    ]

    static func region(_ index: Int) -> Color { regions[index % regions.count] }

    /// Unclaimed kingdoms paint lighter; a kingdom with its queen paints at full strength.
    static let washUnclaimed = 0.74

    /// The journey maps: sepia dip pen and watercolour on old paper. Used only by `Atlas/` and
    /// the two map screens; the board and Home keep the tokens above.
    enum Atlas {
        static let paper = Color(hex: 0xf5ecd7)
        /// Blotches and the vignette at the sheet's edge.
        static let paperShade = Color(hex: 0xd9c193)
        static let ink = Color(hex: 0x4a3423)
        /// Everything not yet travelled is pencilled in this grey.
        static let pencil = Color(hex: 0x8d8a94)
        /// The road walked so far, and the current stop's seal and name.
        static let road = Color(hex: 0xa3323c)
        static let sealRing = Color(hex: 0xc48a1e)
        static let sealMark = Color(hex: 0xfbf3e6)
        static let grain = Color(red: 0.3, green: 0.23, blue: 0.15)

        static let sea = Color(hex: 0x8fb8cf)
        static let forest = Color(hex: 0x9fc283)
        static let mountain = Color(hex: 0xb9a585)
        static let hill = Color(hex: 0xc9c48a)
        static let isles = Color(hex: 0xe8c87a)
        static let marsh = Color(hex: 0xa9c9b4)
        static let fire = Color(hex: 0xe39a6a)
        /// Every wash is laid at this strength, so the ink always reads over it.
        static let washOpacity = 0.6

        /// Pen width and how far a line wanders, in map units. Pencil is thinner and looser.
        static let penWidth: CGFloat = 1
        static let penWander: CGFloat = 1.05
        static let pencilWidth: CGFloat = 0.55
        static let pencilWander: CGFloat = 1.6
    }
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
    /// IM Fell English, the period type on the journey maps only.
    static func atlas(_ size: CGFloat, italic: Bool = false) -> Font {
        .custom(italic ? "IM_FELL_English_Italic" : "IM_FELL_English_Roman", size: size)
    }

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
