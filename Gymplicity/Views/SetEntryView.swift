import SwiftUI

struct SetEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var workoutSet: WorkoutSet
    let exerciseDefinition: ExerciseDefinition?
    let setNumber: Int
    let previousExercise: Exercise?

    @State private var weightText: String = ""
    @State private var repsText: String = ""
    @FocusState private var focusedField: Field?

    enum Field { case weight, reps }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("\(exerciseDefinition?.name ?? "Exercise") — Set \(setNumber)")
                    .font(.headline)

                HStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Text("Weight")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("0", text: $weightText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.center)
                            .font(.system(size: 36, weight: .bold, design: .rounded).monospacedDigit())
                            .frame(width: 120)
                            .focused($focusedField, equals: .weight)
                        Text("lb")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text("x")
                        .font(.title2)
                        .foregroundStyle(.secondary)

                    VStack(spacing: 8) {
                        Text("Reps")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("0", text: $repsText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                            .font(.system(size: 36, weight: .bold, design: .rounded).monospacedDigit())
                            .frame(width: 120)
                            .focused($focusedField, equals: .reps)
                        Text(" ")
                            .font(.caption)
                    }
                }

                if let previousExercise, let lastSet = previousExercise.sortedSets.first {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.caption)
                        Text("Last time: \(formatWeight(lastSet.weight)) x \(lastSet.reps)")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
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
                }
            }
            .onAppear {
                weightText = workoutSet.weight > 0 ? formatWeightValue(workoutSet.weight) : ""
                repsText = workoutSet.reps > 0 ? "\(workoutSet.reps)" : ""
                focusedField = .weight
            }
        }
        .presentationDetents([.medium])
    }

    private func save() {
        workoutSet.weight = Double(weightText) ?? 0
        workoutSet.reps = Int(repsText) ?? 0
        workoutSet.isCompleted = true
        workoutSet.completedAt = .now
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
