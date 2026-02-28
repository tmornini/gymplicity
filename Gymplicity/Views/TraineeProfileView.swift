import SwiftUI
import SwiftData

struct TraineeProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var trainee: Trainee
    @State private var showingEditName = false
    @State private var editedName = ""

    var body: some View {
        List {
            // Active workout quick-access
            if !trainee.activeWorkouts.isEmpty {
                Section("Active Workout") {
                    ForEach(trainee.activeWorkouts) { workout in
                        NavigationLink {
                            ActiveWorkoutView(workout: workout)
                        } label: {
                            HStack {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.green)
                                Text(workout.date, style: .date)
                                Spacer()
                                Text("\(workout.exerciseCount) ex")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            // Start new workout
            Section {
                Button {
                    startWorkout()
                } label: {
                    Label("Start New Workout", systemImage: "plus.circle.fill")
                        .fontWeight(.medium)
                }
            }

            // Recent workouts
            if !trainee.completedWorkouts.isEmpty {
                Section("Recent Workouts") {
                    ForEach(trainee.completedWorkouts.prefix(20)) { workout in
                        NavigationLink {
                            WorkoutHistoryView(workout: workout)
                        } label: {
                            WorkoutRow(workout: workout)
                        }
                    }
                }
            }

            // Progress by exercise
            let definitions = trainee.allExerciseDefinitions
            if !definitions.isEmpty {
                Section("Progress by Exercise") {
                    ForEach(definitions) { definition in
                        NavigationLink {
                            ProgressChartsView(trainee: trainee, exerciseDefinition: definition)
                        } label: {
                            HStack {
                                Text(definition.name)
                                Spacer()
                                if let lastExercise = trainee.lastExercise(for: definition),
                                   let lastSet = lastExercise.sortedSets.first {
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
        .navigationTitle(trainee.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") {
                    editedName = trainee.name
                    showingEditName = true
                }
            }
        }
        .alert("Edit Name", isPresented: $showingEditName) {
            TextField("Name", text: $editedName)
            Button("Save") {
                let trimmed = editedName.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty { trainee.name = trimmed }
            }
            Button("Cancel", role: .cancel) { }
        }
    }

    private func startWorkout() {
        let workout = Workout(trainee: trainee)
        modelContext.insert(workout)
    }

    private func formatWeight(_ weight: Double) -> String {
        if weight == weight.rounded() {
            return "\(Int(weight)) lb"
        }
        return String(format: "%.1f lb", weight)
    }
}

private struct WorkoutRow: View {
    let workout: Workout

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(workout.date, style: .date)
                    .font(.body)
                Spacer()
                Text("\(workout.exerciseCount) exercise\(workout.exerciseCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if workout.totalVolume > 0 {
                Text("Total volume: \(formatVolume(workout.totalVolume)) lb")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            let exerciseNames = workout.sortedExercises.map(\.name).joined(separator: ", ")
            if !exerciseNames.isEmpty {
                Text(exerciseNames)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }

    private func formatVolume(_ volume: Double) -> String {
        if volume >= 1000 {
            return String(format: "%.0f", volume)
        }
        return String(format: "%.0f", volume)
    }
}
