import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var identity: IdentityEntity
    @State private var showingEditName = false
    @State private var editedName = ""
    @State private var showingTemplateStart = false
    @State private var showingSync = false
    @State private var newWorkout: WorkoutEntity?

    var body: some View {
        let allWorkouts =
            identity.workouts(in: modelContext)
        let active = allWorkouts.filter {
            !$0.isCompleted(in: modelContext)
                && !$0.isTemplate
        }
        let completed = allWorkouts
            .filter {
                $0.isCompleted(in: modelContext)
                    && !$0.isTemplate
            }
            .sorted { $0.date > $1.date }

        // Batch-fetch subgraph for all workouts to derive exercisesUsed
        let allNonTemplate = allWorkouts.filter { !$0.isTemplate }
        let subgraph = BatchTraversal.workoutSubgraph(
            workoutIds: allNonTemplate.map(\.id),
            in: modelContext
        )

        // Derive exercisesUsed from the subgraph
        let exercisesUsed: [ExerciseEntity] = {
            var seen = Set<UUID>()
            var exercises: [ExerciseEntity] = []
            for workout in allNonTemplate {
                for group in subgraph.sortedGroups(for: workout.id) {
                    for set in subgraph.sortedSets(for: group.id) {
                        if let ex = subgraph.exerciseBySet[set.id],
                           seen.insert(ex.id).inserted {
                            exercises.append(ex)
                        }
                    }
                }
            }
            return exercises.sorted { $0.name < $1.name }
        }()

        // Compute lastSets inline from existing subgraph
        // (avoids redundant queries)
        let lastSets: [UUID: SetEntity] = {
            var result: [UUID: SetEntity] = [:]
            let targetIds = Set(exercisesUsed.map(\.id))
            guard !targetIds.isEmpty else { return [:] }
            for workout in completed {
                for group in subgraph.sortedGroups(for: workout.id) {
                    for set in subgraph.sortedSets(for: group.id) {
                        if let exercise = subgraph.exerciseBySet[set.id],
                           targetIds.contains(exercise.id),
                           result[exercise.id] == nil {
                            result[exercise.id] = set
                        }
                    }
                }
                if result.count == targetIds.count { break }
            }
            return result
        }()

        // Pre-compute trainerWithTemplates to avoid
        // re-evaluation in view tree
        let trainerForTemplates: IdentityEntity? = {
            let trainer = identity.isTrainer
                ? identity
                : identity.trainer(in: modelContext)
            guard let trainer,
                  !trainer.templates(
                      in: modelContext
                  ).isEmpty
            else { return nil }
            return trainer
        }()

        List {
            if !active.isEmpty {
                Section("Active Workout") {
                    ForEach(active) { workout in
                        NavigationLink {
                            ActiveWorkoutView(
                                workout: workout,
                                trainer: nil,
                                onSwitchToGuided: nil
                            )
                        } label: {
                            HStack {
                                Circle()
                                    .fill(GymColors.activeIndicator)
                                    .frame(
                                        width: GymMetrics.completionDotSize,
                                        height: GymMetrics.completionDotSize
                                    )
                                Text(workout.date, style: .date)
                                Spacer()
                                let count = subgraph
                                    .exerciseCount(for: workout.id)
                                Text("\(count) ex")
                                    .foregroundStyle(GymColors.secondaryText)
                            }
                        }
                    }
                    .onDelete { offsets in
                        deleteWorkouts(
                            from: active,
                            at: offsets
                        )
                    }
                }
            }

            Section {
                if active.isEmpty {
                    Button {
                        startWorkout()
                    } label: {
                        Label(
                            "Start New Workout",
                            systemImage: "plus.circle.fill"
                        )
                            .font(GymFont.bodyStrong)
                            .foregroundStyle(GymColors.energy)
                    }
                }
                if let trainer = trainerForTemplates {
                    Button {
                        showingTemplateStart = true
                    } label: {
                        Label("Start from Template", systemImage: "doc.text")
                    }
                    .sheet(isPresented: $showingTemplateStart) {
                        StartFromTemplateView(
                            trainer: trainer,
                            trainee: identity,
                            onStart: { _ in }
                        )
                    }
                }
            }

            if !completed.isEmpty {
                Section("Recent Workouts") {
                    let recentCompleted = Array(
                        completed.prefix(
                            GymMetrics
                                .recentWorkoutsLimit
                        )
                    )
                    ForEach(recentCompleted) { workout in
                        NavigationLink {
                            WorkoutHistoryView(workout: workout)
                        } label: {
                            WorkoutRow(
                                workout: workout,
                                exerciseCount: subgraph
                                    .exerciseCount(for: workout.id),
                                totalVolume: subgraph
                                    .totalVolume(for: workout.id),
                                exerciseNames: subgraph
                                    .exerciseNames(for: workout.id)
                            )
                        }
                    }
                    .onDelete { offsets in
                        deleteWorkouts(
                            from: recentCompleted,
                            at: offsets
                        )
                    }
                }
            } else {
                Section {
                    VStack(spacing: GymMetrics.space16) {
                        AnimatedMascotView(
                            pose: .lifting,
                            animation: .rep,
                            color: GymColors.secondaryText
                        )
                            .frame(height: GymMetrics.mascotMedium)
                        Text("Let's get your first workout in!")
                            .font(GymFont.body)
                            .foregroundStyle(GymColors.secondaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, GymMetrics.space16)
                }
            }

            if !exercisesUsed.isEmpty {
                Section("Progress by Exercise") {
                    ForEach(exercisesUsed) { exercise in
                        NavigationLink {
                            ProgressChartsView(
                                identity: identity,
                                exercise: exercise
                            )
                        } label: {
                            VStack(
                                alignment: .leading,
                                spacing: GymMetrics.space4
                            ) {
                                HStack {
                                    Text(exercise.name)
                                    Spacer()
                                    if let lastSet = lastSets[exercise.id] {
                                        let w = Weight.formatted(
                                            lastSet.weight
                                        )
                                        Text(
                                            "\(w) x \(lastSet.reps)"
                                        )
                                        .font(GymFont.bodyMono)
                                        .foregroundStyle(
                                            GymColors.secondaryText
                                        )
                                    }
                                }
                                ExerciseAttributePills(exercise: exercise)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(identity.name)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { showingSync = true } label: {
                    Image(systemName: "person.2.wave.2")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") {
                    editedName = identity.name
                    showingEditName = true
                }
            }
        }
        .sheet(isPresented: $showingSync) {
            SyncView(identity: identity)
        }
        .navigationDestination(item: $newWorkout) { workout in
            ActiveWorkoutView(
                workout: workout,
                trainer: nil,
                onSwitchToGuided: nil
            )
        }
        .alert("Edit Name", isPresented: $showingEditName) {
            TextField("Name", text: $editedName)
            Button("Save") {
                let trimmed = editedName.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    identity.name = trimmed
                    SyncTrigger.entityUpdated(.identity, id: identity.id)
                }
            }
            Button("Cancel", role: .cancel) { }
        }
    }

    private func startWorkout() {
        newWorkout = modelContext.startWorkout(for: identity)
    }

    private func deleteWorkouts(
        from workouts: [WorkoutEntity],
        at offsets: IndexSet
    ) {
        for index in offsets {
            modelContext.deleteWorkout(workouts[index])
        }
        SyncTrigger.structureChanged()
    }

}

private struct WorkoutRow: View {
    let workout: WorkoutEntity
    let exerciseCount: Int
    let totalVolume: Double
    let exerciseNames: String

    var body: some View {
        VStack(alignment: .leading, spacing: GymMetrics.space4) {
            HStack {
                Text(workout.date, style: .date)
                    .font(GymFont.body)
                Spacer()
                Text(
                    "\(exerciseCount)"
                        + " exercise\(exerciseCount == 1 ? "" : "s")"
                )
                    .font(GymFont.caption)
                    .foregroundStyle(GymColors.secondaryText)
            }
            if totalVolume > 0 {
                Text("Total volume: \(formatVolume(totalVolume)) lb")
                    .font(GymFont.caption)
                    .foregroundStyle(GymColors.secondaryText)
            }
            if !exerciseNames.isEmpty {
                Text(exerciseNames)
                    .font(GymFont.caption)
                    .foregroundStyle(GymColors.tertiaryText)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, GymMetrics.space2)
    }

    private func formatVolume(_ volume: Double) -> String {
        String(format: "%.0f", volume)
    }
}
