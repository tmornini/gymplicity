import SwiftUI

// MARK: - Poses

enum MascotPose {
    case lifting
    case celebrating
    case resting
    case curling
    case stretching
    case thinking
    case deadlifting
    case walking
    case waving

    var symbolName: String {
        switch self {
        case .lifting:      "figure.strengthtraining.traditional"
        case .celebrating:  "figure.dance"
        case .resting:      "figure.cooldown"
        case .curling:      "figure.strengthtraining.functional"
        case .stretching:   "figure.flexibility"
        case .thinking:     "figure.mind.and.body"
        case .deadlifting:  "figure.core.training"
        case .walking:      "figure.walk"
        case .waving:       "figure.arms.open"
        }
    }
}

// MARK: - MascotView

struct MascotView: View {
    let pose: MascotPose
    var color: Color = GymColors.mascotGray

    var body: some View {
        Image(systemName: pose.symbolName)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .foregroundStyle(color)
    }
}
