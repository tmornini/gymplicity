import SwiftUI
import SwiftData

struct WorkoutHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    let workout: WorkoutEntity

    var body: some View {
        List {
            Section {
                LabeledContent("Date") {
                    Text(workout.date, style: .date)
                }
                LabeledContent("Exercises") {
                    Text("\(workout.exerciseCount(in: modelContext))")
                }
                let totalSets = workout.supersets(in: modelContext).flatMap { $0.sets(in: modelContext) }.count
                LabeledContent("Sets") {
                    Text("\(totalSets)")
                }
                let volume = workout.totalVolume(in: modelContext)
                if volume > 0 {
                    LabeledContent("Total Volume") {
                        Text("\(Int(volume)) lb")
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

            ForEach(workout.sortedSupersets(in: modelContext)) { superset in
                Section("Superset \(superset.order + 1)") {
                    ForEach(superset.sortedSets(in: modelContext)) { set in
                        let exercise = set.exercise(in: modelContext)
                        HStack {
                            Text(exercise?.name ?? "Exercise")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(minWidth: 60, alignment: .leading)
                            Text(formatWeight(set.weight))
                                .font(.body.monospacedDigit())
                            Text("x")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(set.reps)")
                                .font(.body.monospacedDigit())
                            Spacer()
                            Text("\(Int(set.volume)) lb vol")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack {
                        Spacer()
                        Text("Volume: \(Int(superset.totalVolume(in: modelContext))) lb")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Workout Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func formatWeight(_ weight: Double) -> String {
        if weight == weight.rounded() {
            return "\(Int(weight)) lb"
        }
        return String(format: "%.1f lb", weight)
    }
}
