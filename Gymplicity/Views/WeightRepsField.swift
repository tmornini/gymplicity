import SwiftUI

struct WeightRepsField: View {
    @Binding var weightText: String
    @Binding var repsText: String
    let font: Font
    let accentColor: Color
    let fieldWidth: CGFloat
    let showLabels: Bool
    let repsUnit: String
    var focusedField: FocusState<Field?>.Binding

    enum Field: Hashable { case weight, reps }

    var body: some View {
        HStack(spacing: GymMetrics.space24) {
            VStack(spacing: GymMetrics.space8) {
                if showLabels {
                    Text("Weight")
                        .font(GymFont.caption)
                        .foregroundStyle(GymColors.secondaryText)
                }
                TextField("0", text: $weightText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .font(font)
                    .textFieldStyle(.plain)
                    .frame(width: fieldWidth)
                    .focused(focusedField, equals: .weight)
                Rectangle()
                    .fill(accentColor)
                    .frame(width: fieldWidth, height: 2)
                Text("lb")
                    .font(GymFont.caption)
                    .foregroundStyle(GymColors.secondaryText)
            }

            Text("x")
                .font(GymFont.heading2)
                .foregroundStyle(GymColors.secondaryText)

            VStack(spacing: GymMetrics.space8) {
                if showLabels {
                    Text("Reps")
                        .font(GymFont.caption)
                        .foregroundStyle(GymColors.secondaryText)
                }
                TextField("0", text: $repsText)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(font)
                    .textFieldStyle(.plain)
                    .frame(width: fieldWidth)
                    .focused(focusedField, equals: .reps)
                Rectangle()
                    .fill(accentColor)
                    .frame(width: fieldWidth, height: 2)
                Text(repsUnit)
                    .font(GymFont.caption)
                    .foregroundStyle(GymColors.secondaryText)
            }
        }
    }
}
