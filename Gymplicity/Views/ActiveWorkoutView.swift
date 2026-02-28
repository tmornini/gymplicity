import SwiftUI
import SwiftData

struct ActiveWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var workout: Workout
    @State private var showingAddExercise = false
    @State private var showingEndConfirmation = false

    var body: some View {
        List {
            ForEach(workout.sortedExercises) { exercise in
                Section {
                    ForEach(exercise.sortedSets) { workoutSet in
                        SetRow(workoutSet: workoutSet, exercise: exercise, trainee: workout.trainee)
                    }
                    .onDelete { offsets in deleteSets(from: exercise, at: offsets) }

                    Button {
                        addSet(to: exercise)
                    } label: {
                        Label("Add Set", systemImage: "plus")
                            .font(.subheadline)
                    }
                } header: {
                    Text(exercise.name)
                        .font(.headline)
                        .textCase(nil)
                }
            }

            Section {
                Button {
                    showingAddExercise = true
                } label: {
                    Label("Add Exercise", systemImage: "plus.circle.fill")
                        .font(.body.weight(.medium))
                }
            }
        }
        .navigationTitle(workout.trainee?.name ?? "Workout")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 0) {
                    Text(workout.trainee?.name ?? "Workout")
                        .font(.headline)
                    Text(workout.date, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button("End") { showingEndConfirmation = true }
                    .fontWeight(.semibold)
                    .tint(.red)
            }
        }
        .confirmationDialog("End Workout?", isPresented: $showingEndConfirmation) {
            Button("End Workout", role: .destructive) { endWorkout() }
            Button("Cancel", role: .cancel) { }
        } message: {
            let setCount = workout.exercises.flatMap(\.sets).count
            Text("This workout has \(workout.exerciseCount) exercise\(workout.exerciseCount == 1 ? "" : "s") and \(setCount) set\(setCount == 1 ? "" : "s").")
        }
        .sheet(isPresented: $showingAddExercise) {
            AddExerciseView(workout: workout)
        }
    }

    private func addSet(to exercise: Exercise) {
        let previousSets = exercise.sortedSets
        let lastSet = previousSets.last

        // Pre-fill from previous set in this exercise, or from last workout
        let weight = lastSet?.weight ?? previousWeight(for: exercise)
        let reps = lastSet?.reps ?? previousReps(for: exercise)

        let newSet = WorkoutSet(order: exercise.nextSetOrder, weight: weight, reps: reps, exercise: exercise)
        modelContext.insert(newSet)
    }

    private func previousWeight(for exercise: Exercise) -> Double {
        guard let trainee = workout.trainee,
              let definition = exercise.definition,
              let lastExercise = trainee.lastExercise(for: definition),
              let lastSet = lastExercise.sortedSets.first else { return 0 }
        return lastSet.weight
    }

    private func previousReps(for exercise: Exercise) -> Int {
        guard let trainee = workout.trainee,
              let definition = exercise.definition,
              let lastExercise = trainee.lastExercise(for: definition),
              let lastSet = lastExercise.sortedSets.first else { return 0 }
        return lastSet.reps
    }

    private func deleteSets(from exercise: Exercise, at offsets: IndexSet) {
        let sorted = exercise.sortedSets
        for index in offsets {
            modelContext.delete(sorted[index])
        }
    }

    private func endWorkout() {
        workout.isComplete = true
        dismiss()
    }
}

// MARK: - Set Row

struct SetRow: View {
    @Bindable var workoutSet: WorkoutSet
    let exercise: Exercise
    let trainee: Trainee?
    @State private var showingEditor = false

    var body: some View {
        Button {
            showingEditor = true
        } label: {
            HStack {
                Text("Set \(setNumber)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(width: 44, alignment: .leading)

                if workoutSet.weight > 0 || workoutSet.reps > 0 {
                    Text(formatWeight(workoutSet.weight))
                        .font(.body.monospacedDigit().weight(.medium))
                    Text("x")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(workoutSet.reps)")
                        .font(.body.monospacedDigit().weight(.medium))
                } else {
                    Text("Tap to enter")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                Button {
                    workoutSet.isCompleted.toggle()
                    workoutSet.completedAt = workoutSet.isCompleted ? .now : nil
                } label: {
                    Image(systemName: workoutSet.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(workoutSet.isCompleted ? .green : .secondary)
                }
                .buttonStyle(.plain)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingEditor) {
            SetEntryView(
                workoutSet: workoutSet,
                exerciseDefinition: exercise.definition,
                setNumber: setNumber,
                previousExercise: {
                    guard let definition = exercise.definition else { return nil }
                    return trainee?.lastExercise(for: definition)
                }()
            )
        }
    }

    private var setNumber: Int {
        let sorted = exercise.sortedSets
        return (sorted.firstIndex(where: { $0.id == workoutSet.id }) ?? 0) + 1
    }

    private func formatWeight(_ weight: Double) -> String {
        if weight == weight.rounded() {
            return "\(Int(weight)) lb"
        }
        return String(format: "%.1f lb", weight)
    }
}
