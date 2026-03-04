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
        List {
            let active = identity.activeWorkouts(in: modelContext)
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
                                Text("\(workout.exerciseCount(in: modelContext)) ex")
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

            let completed = identity.completedWorkouts(in: modelContext)
            if !completed.isEmpty {
                Section("Recent Workouts") {
                    ForEach(completed.prefix(20)) { workout in
                        NavigationLink {
                            WorkoutHistoryView(workout: workout)
                        } label: {
                            WorkoutRow(workout: workout)
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

            let exercises = identity.exercisesUsed(in: modelContext)
            if !exercises.isEmpty {
                Section("Progress by Exercise") {
                    ForEach(exercises) { exercise in
                        NavigationLink {
                            ProgressChartsView(identity: identity, exercise: exercise)
                        } label: {
                            HStack {
                                Text(exercise.name)
                                Spacer()
                                if let lastSet = identity.lastSet(for: exercise, in: modelContext) {
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
    @Environment(\.modelContext) private var modelContext
    let workout: WorkoutEntity

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            let count = workout.exerciseCount(in: modelContext)
            HStack {
                Text(workout.date, style: .date)
                    .font(GymFont.body)
                Spacer()
                Text("\(count) exercise\(count == 1 ? "" : "s")")
                    .font(GymFont.caption)
                    .foregroundStyle(GymColors.secondaryText)
            }
            let volume = workout.totalVolume(in: modelContext)
            if volume > 0 {
                Text("Total volume: \(formatVolume(volume)) lb")
                    .font(GymFont.caption)
                    .foregroundStyle(GymColors.secondaryText)
            }
            let exerciseNames = exerciseNamesList()
            if !exerciseNames.isEmpty {
                Text(exerciseNames)
                    .font(GymFont.caption)
                    .foregroundStyle(GymColors.tertiaryText)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }

    private func exerciseNamesList() -> String {
        workout.exerciseNames(in: modelContext)
    }

    private func formatVolume(_ volume: Double) -> String {
        String(format: "%.0f", volume)
    }
}
