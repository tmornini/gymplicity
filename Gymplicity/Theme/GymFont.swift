import SwiftUI

enum GymFont {
    /// 56pt black rounded mono — hero numbers
    static let displayLarge = Font.system(
        size: 56,
        weight: .black,
        design: .rounded
    )
    .monospacedDigit()
    /// 28pt bold rounded
    static let heading1 = Font.system(
        size: 28,
        weight: .bold,
        design: .rounded
    )
    /// 22pt bold rounded
    static let heading2 = Font.system(
        size: 22,
        weight: .bold,
        design: .rounded
    )
    /// 17pt semibold rounded
    static let heading3 = Font.system(
        size: 17,
        weight: .semibold,
        design: .rounded
    )
    /// 17pt semibold rounded
    static let bodyStrong = Font.system(
        size: 17,
        weight: .semibold,
        design: .rounded
    )
    /// 17pt regular rounded
    static let body = Font.system(
        size: 17,
        weight: .regular,
        design: .rounded
    )
    /// 17pt medium rounded monospacedDigit
    static let bodyMono = Font.system(
        size: 17,
        weight: .medium,
        design: .rounded
    )
    .monospacedDigit()
    /// 13pt medium rounded
    static let caption = Font.system(
        size: 13,
        weight: .medium,
        design: .rounded
    )
    /// 15pt medium rounded
    static let label = Font.system(
        size: 15,
        weight: .medium,
        design: .rounded
    )
    /// 44pt bold rounded mono — weight/reps entry fields
    static let numericEntry = Font.system(
        size: 44,
        weight: .bold,
        design: .rounded
    )
    .monospacedDigit()
    /// 32pt bold rounded mono — smaller numeric fields
    static let numericEntrySmall = Font.system(
        size: 32,
        weight: .bold,
        design: .rounded
    )
    .monospacedDigit()
}
