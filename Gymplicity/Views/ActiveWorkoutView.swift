import SwiftUI
import SwiftData

struct ActiveWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var workout: WorkoutEntity
    var onSwitchToGuided: (() -> Void)? = nil
    @State private var showingAddExercise = false
    @State private var showingEndConfirmation = false
    @State private var targetGroup: WorkoutGroupEntity?

    var body: some View {
        List {
            ForEach(workout.sortedGroups(in: modelContext)) { group in
                if group.isSuperset {
                    Section {
                        ForEach(group.sortedSets(in: modelContext)) { set in
                            SetRow(set: set, group: group, workout: workout)
                        }
                        .onDelete { offsets in deleteSets(from: group, at: offsets) }

                        Button {
                            targetGroup = group
                            showingAddExercise = true
                        } label: {
                            Label("Add Set", systemImage: "plus")
                                .font(.subheadline)
                        }
                    } header: {
                        Text("Superset \(group.order + 1)")
                            .font(.headline)
                            .textCase(nil)
                    }
                } else {
                    Section {
                        ForEach(group.sortedSets(in: modelContext)) { set in
                            SetRow(set: set, group: group, workout: workout)
                        }
                        .onDelete { offsets in deleteSets(from: group, at: offsets) }

                        Button {
                            addSetToGroup(group)
                        } label: {
                            Label("Add Set", systemImage: "plus")
                                .font(.subheadline)
                        }
                    } header: {
                        Text(exerciseName(for: group))
                            .font(.headline)
                            .textCase(nil)
                    }
                }
            }

            Section {
                Button {
                    addGroup(isSuperset: false)
                } label: {
                    Label("Add Exercise", systemImage: "plus.circle.fill")
                        .font(.body.weight(.medium))
                }

                Button {
                    addGroup(isSuperset: true)
                } label: {
                    Label("Add Superset", systemImage: "plus.circle.fill")
                        .font(.body.weight(.medium))
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if onSwitchToGuided == nil {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 0) {
                        Text(workout.owner(in: modelContext)?.name ?? "Workout")
                            .font(.headline)
                        Text(workout.date, style: .date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button("End") { showingEndConfirmation = true }
                    .fontWeight(.semibold)
                    .tint(.red)
            }
            ToolbarItem(placement: .bottomBar) {
                if let switchToGuided = onSwitchToGuided {
                    Button { switchToGuided() } label: {
                        Label("Guided Mode", systemImage: "scope")
                    }
                } else {
                    NavigationLink {
                        GuidedWorkoutView(workout: workout)
                    } label: {
                        Label("Guided Mode", systemImage: "scope")
                    }
                }
            }
        }
        .confirmationDialog("End Workout?", isPresented: $showingEndConfirmation) {
            Button("End Workout", role: .destructive) { endWorkout() }
            Button("Cancel", role: .cancel) { }
        } message: {
            let groups = workout.groups(in: modelContext)
            let setCount = groups.flatMap { $0.sets(in: modelContext) }.count
            Text("This workout has \(groups.count) group\(groups.count == 1 ? "" : "s") and \(setCount) set\(setCount == 1 ? "" : "s").")
        }
        .sheet(isPresented: $showingAddExercise) {
            if let group = targetGroup {
                AddExerciseView(group: group)
            }
        }
    }

    private func exerciseName(for group: WorkoutGroupEntity) -> String {
        group.sortedSets(in: modelContext).first?.exercise(in: modelContext)?.name ?? "Exercise"
    }

    private func addGroup(isSuperset: Bool) {
        let group = WorkoutGroupEntity(order: workout.nextGroupOrder(in: modelContext), isSuperset: isSuperset)
        modelContext.insert(group)
        let join = WorkoutGroups(workoutId: workout.id, groupId: group.id)
        modelContext.insert(join)
        targetGroup = group
        showingAddExercise = true
    }

    private func addSetToGroup(_ group: WorkoutGroupEntity) {
        guard let exercise = group.sortedSets(in: modelContext).first?.exercise(in: modelContext) else { return }

        var weight: Double = 0
        var reps: Int = 0
        if let owner = workout.owner(in: modelContext),
           let lastSet = owner.lastSet(for: exercise, in: modelContext) {
            weight = lastSet.weight
            reps = lastSet.reps
        }

        let set = SetEntity(order: group.nextSetOrder(in: modelContext), weight: weight, reps: reps)
        modelContext.insert(set)
        let groupJoin = GroupSets(groupId: group.id, setId: set.id)
        modelContext.insert(groupJoin)
        let exerciseJoin = ExerciseSets(exerciseId: exercise.id, setId: set.id)
        modelContext.insert(exerciseJoin)
    }

    private func deleteSets(from group: WorkoutGroupEntity, at offsets: IndexSet) {
        let sorted = group.sortedSets(in: modelContext)
        for index in offsets {
            modelContext.deleteSet(sorted[index])
        }
    }

    private func endWorkout() {
        workout.isComplete = true
        if onSwitchToGuided == nil {
            dismiss()
        }
    }
}

// MARK: - Set Row

struct SetRow: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var set: SetEntity
    let group: WorkoutGroupEntity
    let workout: WorkoutEntity
    @State private var showingEditor = false

    var body: some View {
        Button {
            showingEditor = true
        } label: {
            HStack {
                let exercise = set.exercise(in: modelContext)
                Text(exercise?.name ?? "Exercise")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 60, alignment: .leading)

                if set.weight > 0 || set.reps > 0 {
                    Text(formatWeight(set.weight))
                        .font(.body.monospacedDigit().weight(.medium))
                    Text("x")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(set.reps)")
                        .font(.body.monospacedDigit().weight(.medium))
                } else {
                    Text("Tap to enter")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                Button {
                    set.isCompleted.toggle()
                    set.completedAt = set.isCompleted ? .now : nil
                } label: {
                    Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(set.isCompleted ? .green : .secondary)
                }
                .buttonStyle(.plain)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingEditor) {
            SetEntryView(
                set: set,
                exercise: set.exercise(in: modelContext),
                previousSet: previousSet()
            )
        }
    }

    private func previousSet() -> SetEntity? {
        guard let exercise = set.exercise(in: modelContext),
              let owner = workout.owner(in: modelContext) else { return nil }
        return owner.lastSet(for: exercise, in: modelContext)
    }

    private func formatWeight(_ weight: Double) -> String {
        if weight == weight.rounded() {
            return "\(Int(weight)) lb"
        }
        return String(format: "%.1f lb", weight)
    }
}
