import SwiftUI
import SwiftData

struct ActiveWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var workout: WorkoutEntity
    var trainer: IdentityEntity? = nil
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
                                .font(GymFont.label)
                                .foregroundStyle(GymColors.energy)
                        }
                    } header: {
                        Text("Superset \(group.order + 1)")
                            .font(GymFont.heading3)
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
                                .font(GymFont.label)
                                .foregroundStyle(GymColors.energy)
                        }
                    } header: {
                        Text(group.exerciseName(in: modelContext))
                            .font(GymFont.heading3)
                            .textCase(nil)
                    }
                }
            }

            Section {
                Button {
                    addGroup(isSuperset: false)
                } label: {
                    Label("Add Exercise", systemImage: "plus.circle.fill")
                        .font(GymFont.bodyStrong)
                        .foregroundStyle(GymColors.energy)
                }

                Button {
                    addGroup(isSuperset: true)
                } label: {
                    Label("Add Superset", systemImage: "plus.circle.fill")
                        .font(GymFont.bodyStrong)
                        .foregroundStyle(GymColors.energy)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if onSwitchToGuided == nil {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 0) {
                        Text(workout.owner(in: modelContext)?.name ?? "Workout")
                            .font(GymFont.heading3)
                        Text(workout.date, style: .date)
                            .font(GymFont.caption)
                            .foregroundStyle(GymColors.secondaryText)
                    }
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button("End") { showingEndConfirmation = true }
                    .fontWeight(.semibold)
                    .foregroundStyle(GymColors.danger)
            }
            ToolbarItem(placement: .bottomBar) {
                if let switchToGuided = onSwitchToGuided {
                    Button { switchToGuided() } label: {
                        HStack(spacing: GymMetrics.space4) {
                            MascotView(pose: .lifting, color: GymColors.energy)
                                .frame(height: GymMetrics.mascotInlineSmall)
                            Text("Guided Mode")
                                .font(GymFont.label)
                        }
                    }
                } else {
                    NavigationLink {
                        GuidedWorkoutView(workout: workout)
                    } label: {
                        HStack(spacing: GymMetrics.space4) {
                            MascotView(pose: .lifting, color: GymColors.energy)
                                .frame(height: GymMetrics.mascotInlineSmall)
                            Text("Guided Mode")
                                .font(GymFont.label)
                        }
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
                AddExerciseView(group: group, trainer: trainer ?? resolveTrainer())
            }
        }
    }

    private func addGroup(isSuperset: Bool) {
        let group = WorkoutGroupEntity(order: workout.nextGroupOrder(in: modelContext), isSuperset: isSuperset)
        modelContext.insert(group)
        let join = WorkoutGroups(workoutId: workout.id, groupId: group.id)
        modelContext.insert(join)
        targetGroup = group
        showingAddExercise = true
        SyncTrigger.structureChanged()
    }

    private func addSetToGroup(_ group: WorkoutGroupEntity) {
        guard let exercise = group.sortedSets(in: modelContext).first?.exercise(in: modelContext) else { return }
        modelContext.addSet(to: group, exercise: exercise, seedingFrom: workout.owner(in: modelContext))
        SyncTrigger.structureChanged()
    }

    private func deleteSets(from group: WorkoutGroupEntity, at offsets: IndexSet) {
        modelContext.deleteSets(from: group, at: offsets)
        SyncTrigger.structureChanged()
    }

    private func endWorkout() {
        workout.markCompleted()
        if onSwitchToGuided == nil { dismiss() }
    }

    private func resolveTrainer() -> IdentityEntity? {
        guard let owner = workout.owner(in: modelContext) else { return nil }
        return owner.isTrainer ? owner : owner.trainer(in: modelContext)
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
                    .font(GymFont.label)
                    .foregroundStyle(GymColors.secondaryText)
                    .frame(minWidth: 60, alignment: .leading)

                if set.weight > 0 || set.reps > 0 {
                    Text(Weight.formatted(set.weight))
                        .font(GymFont.bodyMono)
                    Text("x")
                        .font(GymFont.caption)
                        .foregroundStyle(GymColors.secondaryText)
                    Text("\(set.reps)")
                        .font(GymFont.bodyMono)
                } else {
                    Text("Tap to enter")
                        .font(GymFont.body)
                        .foregroundStyle(GymColors.tertiaryText)
                }

                Spacer()

                Button {
                    withAnimation {
                        set.isCompleted.toggle()
                        set.completedAt = set.isCompleted ? .now : nil
                        SyncTrigger.entityUpdated(.set, id: set.id)
                    }
                } label: {
                    Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(set.isCompleted ? GymColors.completedSet : GymColors.secondaryText)
                        .symbolEffect(.bounce, value: set.isCompleted)
                }
                .buttonStyle(.plain)
            }
            .setCompletion(set.isCompleted)
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

}
