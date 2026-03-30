import SwiftUI

struct LastSetReference: View {
    let set: SetEntity?
    let color: Color

    var body: some View {
        if let set {
            HStack(spacing: 4) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(GymFont.caption)
                let w = Weight.formatted(set.weight)
                Text("Last time: \(w) x \(set.reps)")
                    .font(GymFont.caption)
            }
            .gymPill(color)
        }
    }
}
