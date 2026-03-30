import Foundation

enum GymMetrics {
    // MARK: - Spacing (4pt base scale)

    static let space2: CGFloat = 2
    static let space4: CGFloat = 4
    static let space6: CGFloat = 6
    static let space8: CGFloat = 8
    static let space12: CGFloat = 12
    static let space16: CGFloat = 16
    static let space20: CGFloat = 20
    static let space24: CGFloat = 24
    static let space32: CGFloat = 32
    static let space48: CGFloat = 48

    // MARK: - Layout

    static let actionPadding: CGFloat = 40
    static let chartHeight: CGFloat = 240
    static let progressBarHeight: CGFloat = 8
    static let fieldUnderlineHeight: CGFloat = 2
    static let minExerciseNameWidth: CGFloat = 60
    static let fieldWidthCompact: CGFloat = 120
    static let fieldWidthGuided: CGFloat = 130

    // MARK: - Corner Radii

    static let radiusSetBar: CGFloat = 1.5
    static let radiusSmall: CGFloat = 8
    static let radiusMedium: CGFloat = 12
    static let radiusLarge: CGFloat = 16

    // MARK: - Mascot Sizes

    static let mascotTiny: CGFloat = 32
    static let mascotSmall: CGFloat = 60
    static let mascotCard: CGFloat = 80
    static let mascotMedium: CGFloat = 100
    static let mascotLarge: CGFloat = 160

    // MARK: - Mascot Inline Sizes

    static let mascotInline: CGFloat = 20
    static let mascotInlineSmall: CGFloat = 24

    // MARK: - Set Row

    static let setBarWidth: CGFloat = 3
    static let completionDotSize: CGFloat = 10
    static let avatarSize: CGFloat = 36

    // MARK: - Page Dots

    static let activeDotWidth: CGFloat = 16
    static let activeDotHeight: CGFloat = 8
    static let inactiveDotSize: CGFloat = 8

    // MARK: - Gestures

    static let dragMinDistance: CGFloat = 30
    static let dragThreshold: CGFloat = 50
    static let edgeGestureWidth: CGFloat = 24

    // MARK: - Opacity

    static let opacitySubtle: Double = 0.15
    static let opacityLight: Double = 0.2
    static let opacityHalf: Double = 0.5
    static let opacityCompleted: Double = 0.8

    // MARK: - Scale / Transform

    static let buttonPressScale: CGFloat = 0.97
    static let pulseScale: CGFloat = 1.05

    // MARK: - Mascot Animation

    static let bounceOffset: CGFloat = -6
    static let repOffset: CGFloat = -8
    static let entryOffset: CGFloat = 20
    static let wobbleAngle: Double = 3
    static let waveAngle: Double = 5

    // MARK: - Durations

    static let animationShort: Double = 0.15
    static let animationQuick: Double = 0.25
    static let animationMedium: Double = 0.3
    static let bounceDuration: Double = 0.6
    static let pulseDuration: Double = 1.2
    static let wobbleDuration: Double = 0.8
    static let repDuration: Double = 0.7
    static let waveDuration: Double = 0.5

    // MARK: - Springs

    static let entrySpringResponse: Double = 0.5
    static let entrySpringDamping: Double = 0.7
    static let pageSpringResponse: Double = 0.3
    static let pageSpringDamping: Double = 0.7
    static let progressSpringResponse: Double = 0.4
    static let progressSpringDamping: Double = 0.8

    // MARK: - Debounce / Timing

    static let searchDebounceMs: Int = 200
    static let transitionDelayMs: Int = 300
    static let deltaCollectMs: Int = 500
    static let connectionTimeout: TimeInterval = 30
    static let deltaDebounce: TimeInterval = 1

    // MARK: - Data Limits

    static let recentWorkoutsLimit: Int = 20
}
