import SwiftUI

struct SetEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var set: SetEntity
    let exercise: ExerciseEntity?
    let previousSet: SetEntity?

    @State private var weightText: String = ""
    @State private var repsText: String = ""
    @FocusState private var focusedField: Field?

    enum Field { case weight, reps }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                HStack(spacing: GymMetrics.space8) {
                    MascotView(pose: .curling, color: GymColors.energy)
                        .frame(height: GymMetrics.mascotTiny)
                    Text(exercise?.name ?? "Exercise")
                        .font(GymFont.heading2)
                }

                HStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Text("Weight")
                            .font(GymFont.caption)
                            .foregroundStyle(GymColors.secondaryText)
                        TextField("0", text: $weightText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.center)
                            .font(GymFont.numericEntrySmall)
                            .textFieldStyle(.plain)
                            .frame(width: 120)
                            .focused($focusedField, equals: .weight)
                        Rectangle()
                            .fill(GymColors.energy)
                            .frame(width: 120, height: 2)
                        Text("lb")
                            .font(GymFont.caption)
                            .foregroundStyle(GymColors.secondaryText)
                    }

                    Text("x")
                        .font(GymFont.heading2)
                        .foregroundStyle(GymColors.secondaryText)

                    VStack(spacing: 8) {
                        Text("Reps")
                            .font(GymFont.caption)
                            .foregroundStyle(GymColors.secondaryText)
                        TextField("0", text: $repsText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                            .font(GymFont.numericEntrySmall)
                            .textFieldStyle(.plain)
                            .frame(width: 120)
                            .focused($focusedField, equals: .reps)
                        Rectangle()
                            .fill(GymColors.energy)
                            .frame(width: 120, height: 2)
                        Text(" ")
                            .font(GymFont.caption)
                    }
                }

                if let previousSet {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(GymFont.caption)
                        Text("Last time: \(formatWeight(previousSet.weight)) x \(previousSet.reps)")
                            .font(GymFont.caption)
                    }
                    .gymPill(GymColors.focus)
                }

                Spacer()
            }
            .padding(.top, 24)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { save() }
                        .fontWeight(.semibold)
                        .foregroundStyle(GymColors.energy)
                }
            }
            .onAppear {
                weightText = set.weight > 0 ? formatWeightValue(set.weight) : ""
                repsText = set.reps > 0 ? "\(set.reps)" : ""
                focusedField = .weight
            }
        }
        .presentationDetents([.medium])
    }

    private func save() {
        set.weight = Double(weightText) ?? 0
        set.reps = Int(repsText) ?? 0
        set.isCompleted = true
        set.completedAt = .now
        dismiss()
    }

    private func formatWeight(_ weight: Double) -> String {
        if weight == weight.rounded() {
            return "\(Int(weight)) lb"
        }
        return String(format: "%.1f lb", weight)
    }

    private func formatWeightValue(_ weight: Double) -> String {
        if weight == weight.rounded() {
            return "\(Int(weight))"
        }
        return String(format: "%.1f", weight)
    }
}
