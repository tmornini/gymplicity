import SwiftUI

struct GymProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geo in
            Capsule()
                .fill(GymColors.steel)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(GymColors.energy)
                        .frame(width: max(
                            0,
                            geo.size.width
                                * min(progress, 1.0)
                        ))
                        .animation(
                            .spring(
                                response: GymMetrics.progressSpringResponse,
                                dampingFraction: GymMetrics.progressSpringDamping
                            ),
                            value: progress
                        )
                }
        }
        .frame(height: GymMetrics.progressBarHeight)
    }
}
