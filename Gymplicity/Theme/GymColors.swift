import SwiftUI

enum GymColors {
    // MARK: - Core Palette

    /// Dark charcoal backgrounds
    static let iron = Color(hex: 0x2E3338)
    /// Card/section backgrounds
    static let steel = Color(hex: 0x474F57)
    /// Warm off-white text
    static let chalk = Color(hex: 0xF2F0EB)
    /// Deepest background
    static let rubber = Color(hex: 0x1E2124)

    // MARK: - Accent Colors

    /// Primary action orange (CTAs)
    static let energy = Color(hex: 0xFF6B35)
    /// Success/completion green
    static let power = Color(hex: 0x66D972)
    /// Info/charts blue
    static let focus = Color(hex: 0x4DA6FF)
    /// Caution yellow
    static let warning = Color(hex: 0xFFC73D)
    /// Destructive red
    static let danger = Color(hex: 0xF24D4D)

    // MARK: - Text

    /// Subtext
    static let secondaryText = Color(hex: 0x99A1AB)
    /// Hints
    static let tertiaryText = Color(hex: 0x6B737A)

    // MARK: - Semantic Aliases

    static let activeIndicator = power
    static let completedSet = power
    static let incompleteSet = steel
    static let primaryAction = energy
}

// MARK: - Hex Initializer

extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
