import SwiftUI
import SwiftData

struct WorkoutHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    let workout: WorkoutEntity

    var body: some View {
        List {
            Section {
                HStack(spacing: GymMetrics.space8) {
                    MascotView(pose: .celebrating, color: GymColors.power)
                        .frame(height: GymMetrics.mascotTiny)
                    Text("Workout Summary")
                        .font(GymFont.heading3)
                }

                LabeledContent("Date") {
                    Text(workout.date, style: .date)
                }
                LabeledContent("Exercises") {
                    Text("\(workout.exerciseCount(in: modelContext))")
                        .font(GymFont.bodyMono)
                }
                let totalSets = workout.groups(in: modelContext).flatMap { $0.sets(in: modelContext) }.count
                LabeledContent("Sets") {
                    Text("\(totalSets)")
                        .font(GymFont.bodyMono)
                }
                let volume = workout.totalVolume(in: modelContext)
                if volume > 0 {
                    LabeledContent("Total Volume") {
                        Text("\(Int(volume)) lb")
                            .font(GymFont.bodyMono)
                    }
                }
                if let notes = workout.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notes")
                            .font(GymFont.caption)
                            .foregroundStyle(GymColors.secondaryText)
                        Text(notes)
                    }
                }
            }

            ForEach(workout.sortedGroups(in: modelContext)) { group in
                Section(groupHeader(group)) {
                    ForEach(group.sortedSets(in: modelContext)) { set in
                        let exercise = set.exercise(in: modelContext)
                        HStack {
                            Text(exercise?.name ?? "Exercise")
                                .font(GymFont.label)
                                .foregroundStyle(GymColors.secondaryText)
                                .frame(minWidth: 60, alignment: .leading)
                            Text(Weight.formatted(set.weight))
                                .font(GymFont.bodyMono)
                            Text("x")
                                .font(GymFont.caption)
                                .foregroundStyle(GymColors.secondaryText)
                            Text("\(set.reps)")
                                .font(GymFont.bodyMono)
                            Spacer()
                            Text("\(Int(set.volume)) lb vol")
                                .font(GymFont.caption)
                                .foregroundStyle(GymColors.secondaryText)
                        }
                        .setCompletion(set.isCompleted)
                    }

                    HStack {
                        Spacer()
                        Text("Volume: \(Int(group.totalVolume(in: modelContext))) lb")
                            .font(GymFont.caption)
                            .foregroundStyle(GymColors.secondaryText)
                    }
                }
            }
        }
        .navigationTitle("Workout Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func groupHeader(_ group: WorkoutGroupEntity) -> String {
        if group.isSuperset {
            return "Superset \(group.order + 1)"
        }
        return group.sortedSets(in: modelContext).first?.exercise(in: modelContext)?.name ?? "Exercise"
    }

}
