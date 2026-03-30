import SwiftUI
import SwiftData

struct WorkoutHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let workout: WorkoutEntity
    @State private var showingDeleteConfirmation = false

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
                let totalSets = workout
                    .groups(in: modelContext)
                    .flatMap { $0.sets(in: modelContext) }
                    .count
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
                if let notes = workout.notes(in: modelContext), !notes.isEmpty {
                    VStack(alignment: .leading, spacing: GymMetrics.space4) {
                        Text("Notes")
                            .font(GymFont.caption)
                            .foregroundStyle(GymColors.secondaryText)
                        Text(notes)
                    }
                }
            }

            ForEach(workout.sortedGroups(in: modelContext)) { group in
                Section(header: groupHeaderView(group)) {
                    ForEach(
                        group.sortedSets(in: modelContext)
                    ) { set in
                        let exercise = set.exercise(in: modelContext)
                        HStack {
                            VStack(
                                alignment: .leading,
                                spacing: GymMetrics.space4
                            ) {
                                if let name = exercise?.name {
                                    Text(name)
                                        .font(GymFont.label)
                                        .foregroundStyle(GymColors.secondaryText)
                                }
                                ExerciseAttributePills(exercise: exercise)
                            }
                            .frame(minWidth: GymMetrics.minExerciseNameWidth, alignment: .leading)
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
                        .setCompletion(
                            set.isCompleted(
                                in: modelContext
                            )
                        )
                    }

                    HStack {
                        Spacer()
                        let vol = group
                            .totalVolume(in: modelContext)
                        Text("Volume: \(Int(vol)) lb")
                            .font(GymFont.caption)
                            .foregroundStyle(GymColors.secondaryText)
                    }
                }
            }
        }
        .navigationTitle("Workout Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingDeleteConfirmation = true } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(GymColors.danger)
                }
            }
        }
        .confirmationDialog(
            "Delete Workout?",
            isPresented: $showingDeleteConfirmation
        ) {
            Button("Delete Workout", role: .destructive) {
                modelContext.deleteWorkout(workout)
                SyncTrigger.structureChanged()
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            let groups = workout
                .groups(in: modelContext)
            let setCount = groups
                .flatMap { $0.sets(in: modelContext) }
                .count
            let gs = groups.count == 1 ? "" : "s"
            let ss = setCount == 1 ? "" : "s"
            Text(
                "This workout has"
                + " \(groups.count) group\(gs)"
                + " and \(setCount) set\(ss)."
                + " This cannot be undone."
            )
        }
    }

    @ViewBuilder
    private func groupHeaderView(
        _ group: WorkoutGroupEntity
    ) -> some View {
        if group.isSuperset {
            Text("Superset \(group.order + 1)")
        } else if let name = group
            .sortedSets(in: modelContext)
            .first?
            .exercise(in: modelContext)?
            .name
        {
            Text(name)
        }
    }

}
