import SwiftUI

struct SetEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var set: SetEntity
    let exercise: ExerciseEntity?
    let previousSet: SetEntity?

    @State private var weightText: String = ""
    @State private var repsText: String = ""
    @FocusState private var focusedField: WeightRepsField.Field?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                HStack(spacing: GymMetrics.space8) {
                    MascotView(pose: .curling, color: GymColors.energy)
                        .frame(height: GymMetrics.mascotTiny)
                    VStack(alignment: .leading, spacing: GymMetrics.space4) {
                        Text(exercise?.name ?? "Exercise")
                            .font(GymFont.heading2)
                        ExerciseAttributePills(exercise: exercise)
                    }
                }

                WeightRepsField(
                    weightText: $weightText,
                    repsText: $repsText,
                    focusedField: $focusedField
                )

                LastSetReference(set: previousSet, color: GymColors.focus)

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
                weightText = set.weight > 0 ? Weight.rawValue(set.weight) : ""
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
        SyncTrigger.entityUpdated(.set, id: set.id)
        dismiss()
    }
}
