import SwiftUI

struct WorkoutHistoryView: View {
    let workout: Workout

    var body: some View {
        List {
            Section {
                LabeledContent("Date") {
                    Text(workout.date, style: .date)
                }
                LabeledContent("Exercises") {
                    Text("\(workout.exerciseCount)")
                }
                let totalSets = workout.exercises.flatMap(\.sets).count
                LabeledContent("Sets") {
                    Text("\(totalSets)")
                }
                if workout.totalVolume > 0 {
                    LabeledContent("Total Volume") {
                        Text("\(Int(workout.totalVolume)) lb")
                    }
                }
                if let notes = workout.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notes")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(notes)
                    }
                }
            }

            ForEach(workout.sortedExercises) { exercise in
                Section(exercise.name) {
                    ForEach(exercise.sortedSets) { workoutSet in
                        HStack {
                            Text("Set \(setNumber(workoutSet, in: exercise))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(width: 50, alignment: .leading)
                            Text(formatWeight(workoutSet.weight))
                                .font(.body.monospacedDigit())
                            Text("x")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(workoutSet.reps)")
                                .font(.body.monospacedDigit())
                            Spacer()
                            Text("\(Int(workoutSet.volume)) lb vol")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack {
                        Spacer()
                        Text("Volume: \(Int(exercise.totalVolume)) lb")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Workout Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func setNumber(_ workoutSet: WorkoutSet, in exercise: Exercise) -> Int {
        (exercise.sortedSets.firstIndex(where: { $0.id == workoutSet.id }) ?? 0) + 1
    }

    private func formatWeight(_ weight: Double) -> String {
        if weight == weight.rounded() {
            return "\(Int(weight)) lb"
        }
        return String(format: "%.1f lb", weight)
    }
}
