import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var identity: IdentityEntity
    @State private var showingEditName = false
    @State private var editedName = ""
    @State private var showingTemplateStart = false
    @State private var showingSync = false

    var body: some View {
        let allWorkouts = identity.workouts(in: modelContext)
        let active = allWorkouts.filter { !$0.isCompleted && !$0.isTemplate }
        let completed = allWorkouts
            .filter { $0.isCompleted && !$0.isTemplate }
            .sorted { $0.date > $1.date }

        // Batch-fetch subgraph for all workouts to derive exercisesUsed
        let allNonTemplate = allWorkouts.filter { !$0.isTemplate }
        let subgraph = BatchTraversal.workoutSubgraph(workoutIds: allNonTemplate.map(\.id), in: modelContext)

        // Derive exercisesUsed from the subgraph
        let exercisesUsed: [ExerciseEntity] = {
            var seen = Set<UUID>()
            var exercises: [ExerciseEntity] = []
            for workout in allNonTemplate {
                for group in subgraph.sortedGroups(for: workout.id) {
                    for set in subgraph.sortedSets(for: group.id) {
                        if let ex = subgraph.exerciseBySet[set.id], seen.insert(ex.id).inserted {
                            exercises.append(ex)
                        }
                    }
                }
            }
            return exercises.sorted { $0.name < $1.name }
        }()

        // Batch-fetch lastSets for all exercises
        let lastSets = BatchTraversal.lastSets(for: identity, exerciseIds: exercisesUsed.map(\.id), in: modelContext)

        // Batch-fetch subgraph for completed workouts (for WorkoutRow)
        let completedSubgraph: WorkoutSubgraph = {
            guard !completed.isEmpty else {
                return WorkoutSubgraph(groupsByWorkout: [:], setsByGroup: [:], exerciseBySet: [:])
            }
            return BatchTraversal.workoutSubgraph(workoutIds: completed.map(\.id), in: modelContext)
        }()

        List {
            if !active.isEmpty {
                Section("Active Workout") {
                    ForEach(active) { workout in
                        NavigationLink {
                            ActiveWorkoutView(workout: workout)
                        } label: {
                            HStack {
                                Circle()
                                    .fill(GymColors.activeIndicator)
                                    .frame(width: GymMetrics.completionDotSize, height: GymMetrics.completionDotSize)
                                Text(workout.date, style: .date)
                                Spacer()
                                let count = subgraph.exerciseCount(for: workout.id)
                                Text("\(count) ex")
                                    .foregroundStyle(GymColors.secondaryText)
                            }
                        }
                    }
                }
            }

            Section {
                if active.isEmpty {
                    Button {
                        startWorkout()
                    } label: {
                        Label("Start New Workout", systemImage: "plus.circle.fill")
                            .font(GymFont.bodyStrong)
                            .foregroundStyle(GymColors.energy)
                    }
                }
                if let trainer = trainerWithTemplates() {
                    Button {
                        showingTemplateStart = true
                    } label: {
                        Label("Start from Template", systemImage: "doc.text")
                    }
                    .sheet(isPresented: $showingTemplateStart) {
                        StartFromTemplateView(trainer: trainer, trainee: identity)
                    }
                }
            }

            if !completed.isEmpty {
                Section("Recent Workouts") {
                    ForEach(completed.prefix(20)) { workout in
                        NavigationLink {
                            WorkoutHistoryView(workout: workout)
                        } label: {
                            WorkoutRow(
                                workout: workout,
                                exerciseCount: completedSubgraph.exerciseCount(for: workout.id),
                                totalVolume: completedSubgraph.totalVolume(for: workout.id),
                                exerciseNames: completedSubgraph.exerciseNames(for: workout.id)
                            )
                        }
                    }
                }
            } else {
                Section {
                    VStack(spacing: GymMetrics.space16) {
                        AnimatedMascotView(pose: .lifting, animation: .rep, color: GymColors.secondaryText)
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
                            ProgressChartsView(identity: identity, exercise: exercise)
                        } label: {
                            HStack {
                                Text(exercise.name)
                                Spacer()
                                if let lastSet = lastSets[exercise.id] {
                                    Text("\(Weight.formatted(lastSet.weight)) x \(lastSet.reps)")
                                        .font(GymFont.bodyMono)
                                        .foregroundStyle(GymColors.secondaryText)
                                }
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

    private func trainerWithTemplates() -> IdentityEntity? {
        let trainer = identity.isTrainer ? identity : identity.trainer(in: modelContext)
        guard let trainer, !trainer.templates(in: modelContext).isEmpty else { return nil }
        return trainer
    }

    private func startWorkout() {
        modelContext.startWorkout(for: identity)
    }

}

private struct WorkoutRow: View {
    let workout: WorkoutEntity
    let exerciseCount: Int
    let totalVolume: Double
    let exerciseNames: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(workout.date, style: .date)
                    .font(GymFont.body)
                Spacer()
                Text("\(exerciseCount) exercise\(exerciseCount == 1 ? "" : "s")")
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
        .padding(.vertical, 2)
    }

    private func formatVolume(_ volume: Double) -> String {
        String(format: "%.0f", volume)
    }
}
