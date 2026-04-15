import SwiftUI
import SwiftData

struct SetEntryView: View {
    @Environment(\.modelContext)
    private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var set: SetEntity
    let exercise: ExerciseEntity?
    let previousSet: SetEntity?

    @State private var weightText: String = ""
    @State private var repsText: String = ""
    @FocusState private var focusedField: WeightRepsField.Field?

    var body: some View {
        NavigationStack {
            VStack(spacing: GymMetrics.space24) {
                HStack(spacing: GymMetrics.space8) {
                    MascotView(pose: .curling, color: GymColors.energy)
                        .frame(height: GymMetrics.mascotTiny)
                    VStack(alignment: .leading, spacing: GymMetrics.space4) {
                        if let name = exercise?.name {
                            Text(name)
                                .font(GymFont.heading2)
                        }
                        ExerciseAttributePills(exercise: exercise)
                    }
                }

                WeightRepsField(
                    weightText: $weightText,
                    repsText: $repsText,
                    font: GymFont.numericEntrySmall,
                    accentColor: GymColors.energy,
                    fieldWidth: GymMetrics
                        .fieldWidthCompact,
                    showLabels: true,
                    repsUnit: " ",
                    focusedField: $focusedField
                )

                LastSetReference(set: previousSet, color: GymColors.focus)

                Spacer()
            }
            .padding(.top, GymMetrics.space24)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { save() }
                        .fontWeight(.semibold)
                        .foregroundStyle(GymColors.energy)
                        .disabled(!isInputValid)
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

    private var isInputValid: Bool {
        Double(weightText) != nil && Int(repsText) != nil
    }

    private func save() {
        guard let parsedWeight = Double(weightText),
              let parsedReps = Int(repsText)
        else { return }
        set.weight = parsedWeight
        set.reps = parsedReps
        modelContext.insert(
            SetCompletions(
                setId: set.id,
                completedAt: .now
            )
        )
        SyncTrigger.entityUpdated(
            .set,
            id: set.id
        )
        dismiss()
    }
}
