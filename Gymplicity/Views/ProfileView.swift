import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var identity: IdentityEntity
    @State private var showingEditName = false
    @State private var editedName = ""
    @State private var showingTemplateStart = false

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
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.green)
                                Text(workout.date, style: .date)
                                Spacer()
                                Text("\(workout.exerciseCount(in: modelContext)) ex")
                                    .foregroundStyle(.secondary)
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
                            .fontWeight(.medium)
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
            }

            let exercises = identity.allExercises(in: modelContext)
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
                                    Text("\(formatWeight(lastSet.weight)) x \(lastSet.reps)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(identity.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") {
                    editedName = identity.name
                    showingEditName = true
                }
            }
        }
        .alert("Edit Name", isPresented: $showingEditName) {
            TextField("Name", text: $editedName)
            Button("Save") {
                let trimmed = editedName.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty { identity.name = trimmed }
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
        guard identity.activeWorkouts(in: modelContext).isEmpty else { return }
        let workout = WorkoutEntity()
        modelContext.insert(workout)
        let join = IdentityWorkouts(identityId: identity.id, workoutId: workout.id)
        modelContext.insert(join)
    }

    private func formatWeight(_ weight: Double) -> String {
        if weight == weight.rounded() {
            return "\(Int(weight)) lb"
        }
        return String(format: "%.1f lb", weight)
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
                    .font(.body)
                Spacer()
                Text("\(count) exercise\(count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            let volume = workout.totalVolume(in: modelContext)
            if volume > 0 {
                Text("Total volume: \(formatVolume(volume)) lb")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            let exerciseNames = exerciseNamesList()
            if !exerciseNames.isEmpty {
                Text(exerciseNames)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }

    private func exerciseNamesList() -> String {
        let allSets = workout.sortedGroups(in: modelContext).flatMap { $0.sortedSets(in: modelContext) }
        var seen = Swift.Set<UUID>()
        var names: [String] = []
        for set in allSets {
            if let exercise = set.exercise(in: modelContext), seen.insert(exercise.id).inserted {
                names.append(exercise.name)
            }
        }
        return names.joined(separator: ", ")
    }

    private func formatVolume(_ volume: Double) -> String {
        String(format: "%.0f", volume)
    }
}
