import SwiftUI
import SwiftData

struct ActiveWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var workout: WorkoutEntity
    let trainer: IdentityEntity?
    let onSwitchToGuided: (() -> Void)?
    @State private var showingAddExercise = false
    @State private var showingEndConfirmation = false
    @State private var showingDeleteWorkout = false
    @State private var targetGroup: WorkoutGroupEntity?
    @State private var groupToDelete: WorkoutGroupEntity?

    var body: some View {
        let snapshot = WorkoutSnapshot.load(workout, in: modelContext)
        let owner = workout.owner(in: modelContext)

        let exerciseIds = exerciseIdsFrom(snapshot)
        let lastSets = BatchTraversal.lastSets(
            for: owner,
            exerciseIds: exerciseIds,
            in: modelContext
        )

        List {
            ForEach(snapshot.groups) { groupSnap in
                let group = groupSnap.group
                if group.isSuperset {
                    Section {
                        ForEach(groupSnap.sets) { setSnap in
                            SetRow(
                                set: setSnap.set,
                                exercise: setSnap.exercise,
                                previousSet: setSnap.exercise
                                    .flatMap { lastSets[$0.id] }
                            )
                        }
                        .onDelete { offsets in
                            deleteSets(
                                from: group,
                                at: offsets
                            )
                        }

                        Button {
                            targetGroup = group
                            showingAddExercise = true
                        } label: {
                            Label("Add Set", systemImage: "plus")
                                .font(GymFont.label)
                                .foregroundStyle(GymColors.energy)
                        }

                        Button(role: .destructive) {
                            groupToDelete = group
                        } label: {
                            Label("Remove Superset", systemImage: "trash")
                                .font(GymFont.label)
                        }
                    } header: {
                        Text("Superset \(group.order + 1)")
                            .font(GymFont.heading3)
                            .textCase(nil)
                    }
                } else {
                    Section {
                        ForEach(groupSnap.sets) { setSnap in
                            SetRow(
                                set: setSnap.set,
                                exercise: setSnap.exercise,
                                previousSet: setSnap.exercise
                                    .flatMap { lastSets[$0.id] }
                            )
                        }
                        .onDelete { offsets in
                            deleteSets(
                                from: group,
                                at: offsets
                            )
                        }

                        Button {
                            addSetToGroup(group)
                        } label: {
                            Label("Add Set", systemImage: "plus")
                                .font(GymFont.label)
                                .foregroundStyle(GymColors.energy)
                        }

                        Button(role: .destructive) {
                            groupToDelete = group
                        } label: {
                            Label("Remove Group", systemImage: "trash")
                                .font(GymFont.label)
                        }
                    } header: {
                        if let name = groupSnap.exerciseName {
                            Text(name)
                                .font(GymFont.heading3)
                                .textCase(nil)
                        }
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
                        Text(owner.name)
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
            ToolbarItem(placement: .primaryAction) {
                Button { showingDeleteWorkout = true } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(GymColors.danger)
                }
            }
            ToolbarItem(placement: .bottomBar) {
                if let switchToGuided = onSwitchToGuided {
                    Button { switchToGuided() } label: {
                        HStack(spacing: GymMetrics.space4) {
                            MascotView(
                                pose: .lifting,
                                color: GymColors.energy
                            )
                                .frame(height: GymMetrics.mascotInlineSmall)
                            Text("Guided Mode")
                                .font(GymFont.label)
                        }
                    }
                } else {
                    NavigationLink {
                        GuidedWorkoutView(
                            workout: workout,
                            onSwitchToList: nil,
                            initialSetIndex: nil,
                            onSetIndexChange: nil
                        )
                    } label: {
                        HStack(spacing: GymMetrics.space4) {
                            MascotView(
                                pose: .lifting,
                                color: GymColors.energy
                            )
                                .frame(height: GymMetrics.mascotInlineSmall)
                            Text("Guided Mode")
                                .font(GymFont.label)
                        }
                    }
                }
            }
        }
        .confirmationDialog(
            "End Workout?",
            isPresented: $showingEndConfirmation
        ) {
            Button(
                "End Workout",
                role: .destructive
            ) { endWorkout() }
            Button("Cancel", role: .cancel) { }
        } message: {
            let groups = snapshot.groups
            let setCount = groups
                .flatMap(\.sets).count
            Text(
                "This workout has"
                    + " \(groups.count)"
                    + " group\(groups.count == 1 ? "" : "s")"
                    + " and \(setCount)"
                    + " set\(setCount == 1 ? "" : "s")."
            )
        }
        .confirmationDialog(
            groupToDelete?.isSuperset == true
                ? "Remove Superset?"
                : "Remove Group?",
            isPresented: Binding(
                get: { groupToDelete != nil },
                set: { if !$0 { groupToDelete = nil } }
            ),
            presenting: groupToDelete
        ) { group in
            Button("Remove", role: .destructive) {
                modelContext.deleteGroup(group)
                SyncTrigger.structureChanged()
                groupToDelete = nil
            }
            Button("Cancel", role: .cancel) { groupToDelete = nil }
        } message: { group in
            let setCount = group.sets(in: modelContext).count
            let label = group.isSuperset ? "superset" : "group"
            Text(
                "This \(label) has \(setCount)"
                    + " set\(setCount == 1 ? "" : "s")"
                    + " that will be deleted."
            )
        }
        .confirmationDialog(
            "Delete Workout?",
            isPresented: $showingDeleteWorkout
        ) {
            Button(
                "Delete Workout",
                role: .destructive
            ) { deleteWorkout() }
            Button("Cancel", role: .cancel) { }
        } message: {
            let groups = snapshot.groups
            let setCount = groups
                .flatMap(\.sets).count
            Text(
                "This workout has"
                    + " \(groups.count)"
                    + " group\(groups.count == 1 ? "" : "s")"
                    + " and \(setCount)"
                    + " set\(setCount == 1 ? "" : "s")."
                    + " This cannot be undone."
            )
        }
        .sheet(isPresented: $showingAddExercise) {
            if let group = targetGroup {
                let resolved: IdentityEntity? =
                    if let trainer {
                        trainer
                    } else {
                        resolveTrainer()
                    }
                AddExerciseView(
                    group: group,
                    trainer: resolved
                )
            }
        }
    }

    private func addGroup(isSuperset: Bool) {
        let group = WorkoutGroupEntity(
            order: workout.nextGroupOrder(
                in: modelContext
            ),
            isSuperset: isSuperset
        )
        modelContext.insert(group)
        let join = WorkoutGroups(workoutId: workout.id, groupId: group.id)
        modelContext.insert(join)
        targetGroup = group
        showingAddExercise = true
        SyncTrigger.structureChanged()
    }

    private func addSetToGroup(_ group: WorkoutGroupEntity) {
        guard let exercise = group
            .sortedSets(in: modelContext)
            .first?.exercise(in: modelContext)
        else { return }
        modelContext.addSet(
            to: group,
            exercise: exercise,
            seedingFrom: workout.owner(
                in: modelContext
            )
        )
        SyncTrigger.structureChanged()
    }

    private func deleteSets(
        from group: WorkoutGroupEntity,
        at offsets: IndexSet
    ) {
        modelContext.deleteSets(from: group, at: offsets)
        SyncTrigger.structureChanged()
    }

    private func endWorkout() {
        workout.markCompleted(in: modelContext)
        if onSwitchToGuided == nil {
            dismiss()
        }
    }

    private func deleteWorkout() {
        modelContext.deleteWorkout(workout)
        SyncTrigger.structureChanged()
        if onSwitchToGuided == nil { dismiss() }
    }

    private func resolveTrainer(
    ) -> IdentityEntity? {
        let owner = workout.owner(in: modelContext)
        return owner.isTrainer
            ? owner
            : owner.trainer(in: modelContext) ?? owner
    }

    private func exerciseIdsFrom(
        _ snapshot: WorkoutSnapshot
    ) -> [UUID] {
        Array(Set(
            snapshot.groups.flatMap { g in
                g.sets.compactMap {
                    $0.exercise?.id
                }
            }
        ))
    }
}

// MARK: - Set Row

struct SetRow: View {
    @Environment(\.modelContext)
    private var modelContext
    @Bindable var set: SetEntity
    let exercise: ExerciseEntity?
    let previousSet: SetEntity?
    @State private var showingEditor = false

    var body: some View {
        let completed =
            set.isCompleted(in: modelContext)
        Button {
            showingEditor = true
        } label: {
            HStack {
                VStack(
                    alignment: .leading,
                    spacing: GymMetrics.space4
                ) {
                    if let name = exercise?.name {
                        Text(name)
                            .font(GymFont.label)
                            .foregroundStyle(
                                GymColors.secondaryText
                            )
                    }
                    ExerciseAttributePills(
                        exercise: exercise
                    )
                }
                .frame(
                    minWidth: GymMetrics
                        .minExerciseNameWidth,
                    alignment: .leading
                )

                if set.weight > 0
                    || set.reps > 0
                {
                    Text(
                        Weight.formatted(
                            set.weight
                        )
                    )
                    .font(GymFont.bodyMono)
                    Text("x")
                        .font(GymFont.caption)
                        .foregroundStyle(
                            GymColors
                                .secondaryText
                        )
                    Text("\(set.reps)")
                        .font(GymFont.bodyMono)
                } else {
                    Text("Tap to enter")
                        .font(GymFont.body)
                        .foregroundStyle(
                            GymColors.tertiaryText
                        )
                }

                Spacer()

                Button {
                    withAnimation {
                        toggleSetCompletion()
                    }
                } label: {
                    Image(
                        systemName: completed
                            ? "checkmark.circle.fill"
                            : "circle"
                    )
                    .font(.title3)
                    .foregroundStyle(
                        completed
                            ? GymColors.completedSet
                            : GymColors.secondaryText
                    )
                    .symbolEffect(
                        .bounce,
                        value: completed
                    )
                }
                .buttonStyle(.plain)
            }
            .setCompletion(completed)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingEditor) {
            SetEntryView(
                set: set,
                exercise: exercise,
                previousSet: previousSet
            )
        }
    }

    private func toggleSetCompletion() {
        let id = set.id
        if set.isCompleted(in: modelContext) {
            let completions =
                modelContext.fetchOrEmpty(
                    FetchDescriptor<
                        SetCompletions
                    >(
                        predicate: #Predicate {
                            $0.setId == id
                        }
                    )
                )
            completions.forEach {
                modelContext.delete($0)
            }
        } else {
            modelContext.insert(
                SetCompletions(
                    setId: id,
                    completedAt: .now
                )
            )
        }
        SyncTrigger.entityUpdated(
            .set,
            id: id
        )
    }
}
