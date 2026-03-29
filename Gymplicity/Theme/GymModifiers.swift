import SwiftUI

// MARK: - Primary Button Style

struct GymPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(GymFont.bodyStrong)
            .foregroundStyle(GymColors.chalk)
            .frame(maxWidth: .infinity)
            .padding(.vertical, GymMetrics.space16)
            .background(
                GymColors.energy,
                in: RoundedRectangle(
                    cornerRadius: GymMetrics.radiusMedium
                )
            )
            .scaleEffect(
                configuration.isPressed ? 0.97 : 1.0
            )
            .animation(
                .easeInOut(duration: 0.15),
                value: configuration.isPressed
            )
    }
}

extension ButtonStyle where Self == GymPrimaryButtonStyle {
    static var gymPrimary: GymPrimaryButtonStyle { GymPrimaryButtonStyle() }
}

// MARK: - Card Modifier

struct GymCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(GymMetrics.space16)
            .background(
                GymColors.steel,
                in: RoundedRectangle(
                    cornerRadius: GymMetrics.radiusMedium
                )
            )
    }
}

extension View {
    func gymCard() -> some View {
        modifier(GymCardModifier())
    }
}

// MARK: - Set Completion Modifier

struct SetCompletionModifier: ViewModifier {
    let isCompleted: Bool

    func body(content: Content) -> some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(
                    isCompleted
                        ? GymColors.completedSet
                        : GymColors.incompleteSet
                )
                .frame(width: GymMetrics.setBarWidth)

            content
                .padding(.leading, GymMetrics.space8)
        }
        .opacity(isCompleted ? 0.8 : 1.0)
    }
}

extension View {
    func setCompletion(_ isCompleted: Bool) -> some View {
        modifier(SetCompletionModifier(isCompleted: isCompleted))
    }
}

// MARK: - Pill Modifier

struct GymPillModifier: ViewModifier {
    let color: Color

    func body(content: Content) -> some View {
        content
            .font(GymFont.caption)
            .padding(.horizontal, GymMetrics.space8)
            .padding(.vertical, GymMetrics.space4)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }
}

extension View {
    func gymPill(_ color: Color) -> some View {
        modifier(GymPillModifier(color: color))
    }
}
