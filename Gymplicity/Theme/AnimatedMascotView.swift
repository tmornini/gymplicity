import SwiftUI

// MARK: - Animation Types

enum MascotAnimation {
    case bounce
    case pulse
    case wobble
    case rep
    case wave
    case enterFromBottom
}

// MARK: - AnimatedMascotView

struct AnimatedMascotView: View {
    let pose: MascotPose
    let animation: MascotAnimation
    var color: Color = GymColors.chalk

    @State private var isAnimating = false
    @State private var hasAppeared = false

    var body: some View {
        MascotView(pose: pose, color: color)
            .modifier(AnimationModifier(animation: animation, isAnimating: isAnimating))
            .opacity(animation == .enterFromBottom ? (hasAppeared ? 1 : 0) : 1)
            .offset(y: animation == .enterFromBottom ? (hasAppeared ? 0 : 20) : 0)
            .onAppear {
                withAnimation(timingFor(animation)) {
                    isAnimating = true
                    hasAppeared = true
                }
            }
    }

    private func timingFor(_ animation: MascotAnimation) -> Animation {
        switch animation {
        case .bounce:
            .easeInOut(duration: 0.6).repeatForever(autoreverses: true)
        case .pulse:
            .easeInOut(duration: 1.2).repeatForever(autoreverses: true)
        case .wobble:
            .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
        case .rep:
            .easeInOut(duration: 0.7).repeatForever(autoreverses: true)
        case .wave:
            .easeInOut(duration: 0.5).repeatForever(autoreverses: true)
        case .enterFromBottom:
            .spring(response: 0.5, dampingFraction: 0.7)
        }
    }
}

// MARK: - Animation Modifier

private struct AnimationModifier: ViewModifier {
    let animation: MascotAnimation
    let isAnimating: Bool

    func body(content: Content) -> some View {
        switch animation {
        case .bounce:
            content.offset(y: isAnimating ? -6 : 0)
        case .pulse:
            content.scaleEffect(isAnimating ? 1.05 : 1.0)
        case .wobble:
            content.rotationEffect(.degrees(isAnimating ? 3 : -3))
        case .rep:
            content.offset(y: isAnimating ? -8 : 0)
        case .wave:
            content.rotationEffect(.degrees(isAnimating ? 5 : -5), anchor: .bottom)
        case .enterFromBottom:
            content
        }
    }
}
