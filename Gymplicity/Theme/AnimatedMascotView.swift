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
    let color: Color

    @State private var isAnimating = false
    @State private var hasAppeared = false

    var body: some View {
        MascotView(pose: pose, color: color)
            .modifier(AnimationModifier(
                animation: animation,
                isAnimating: isAnimating
            ))
            .opacity(
                animation == .enterFromBottom
                    ? (hasAppeared ? 1 : 0) : 1
            )
            .offset(
                y: animation == .enterFromBottom
                    ? (hasAppeared ? 0 : GymMetrics.entryOffset) : 0
            )
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
            .easeInOut(duration: GymMetrics.bounceDuration).repeatForever(autoreverses: true)
        case .pulse:
            .easeInOut(duration: GymMetrics.pulseDuration).repeatForever(autoreverses: true)
        case .wobble:
            .easeInOut(duration: GymMetrics.wobbleDuration).repeatForever(autoreverses: true)
        case .rep:
            .easeInOut(duration: GymMetrics.repDuration).repeatForever(autoreverses: true)
        case .wave:
            .easeInOut(duration: GymMetrics.waveDuration).repeatForever(autoreverses: true)
        case .enterFromBottom:
            .spring(response: GymMetrics.entrySpringResponse, dampingFraction: GymMetrics.entrySpringDamping)
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
            content.offset(y: isAnimating ? GymMetrics.bounceOffset : 0)
        case .pulse:
            content.scaleEffect(isAnimating ? GymMetrics.pulseScale : 1.0)
        case .wobble:
            content.rotationEffect(.degrees(isAnimating ? GymMetrics.wobbleAngle : -GymMetrics.wobbleAngle))
        case .rep:
            content.offset(y: isAnimating ? GymMetrics.repOffset : 0)
        case .wave:
            content.rotationEffect(
                .degrees(isAnimating ? GymMetrics.waveAngle : -GymMetrics.waveAngle),
                anchor: .bottom
            )
        case .enterFromBottom:
            content
        }
    }
}
