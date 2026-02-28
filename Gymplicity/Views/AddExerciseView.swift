import SwiftUI
import SwiftData

struct AddExerciseView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let workout: Workout
    @State private var searchText = ""
    @FocusState private var nameFieldFocused: Bool

    private var trainer: Trainer? {
        workout.trainee?.trainer
    }

    /// Exercise definitions from the trainer's catalog, filtered by search text.
    private var suggestions: [ExerciseDefinition] {
        guard let trainer else { return [] }
        let all = trainer.exerciseDefinitions.sorted { $0.name < $1.name }
        if searchText.isEmpty { return all }
        return all.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    /// Definition IDs already in this workout (to avoid duplicates).
    private var definitionIDsInWorkout: Swift.Set<UUID> {
        Swift.Set(workout.exercises.compactMap { $0.definition?.id })
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TextField("Exercise name", text: $searchText)
                    .focused($nameFieldFocused)
                    .font(.title3)
                    .padding()
                    .submitLabel(.done)
                    .onSubmit { addExercise() }
                    .autocorrectionDisabled()

                Divider()

                if !suggestions.isEmpty {
                    List {
                        ForEach(suggestions) { definition in
                            let alreadyAdded = definitionIDsInWorkout.contains(definition.id)
                            Button {
                                addExisting(definition)
                            } label: {
                                HStack {
                                    Text(definition.name)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if alreadyAdded {
                                        Text("already added")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .disabled(alreadyAdded)
                        }
                    }
                    .listStyle(.plain)
                } else if !searchText.isEmpty {
                    VStack(spacing: 8) {
                        Spacer()
                        Text("New exercise")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("Tap Add to create \"\(searchText)\"")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Spacer()
                    }
                } else {
                    VStack(spacing: 8) {
                        Spacer()
                        Text("Type an exercise name")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                }
            }
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { addExercise() }
                        .fontWeight(.semibold)
                        .disabled(searchText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { nameFieldFocused = true }
        }
        .presentationDetents([.medium, .large])
    }

    private func addExisting(_ definition: ExerciseDefinition) {
        guard !definitionIDsInWorkout.contains(definition.id) else { return }
        createExercise(for: definition)
        dismiss()
    }

    private func addExercise() {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let trainer else { return }

        let definition = trainer.findOrCreateExerciseDefinition(named: trimmed, in: modelContext)
        guard !definitionIDsInWorkout.contains(definition.id) else { return }
        createExercise(for: definition)
        dismiss()
    }

    private func createExercise(for definition: ExerciseDefinition) {
        let exercise = Exercise(definition: definition, order: workout.nextExerciseOrder, workout: workout)
        modelContext.insert(exercise)

        // Pre-populate first set from last workout
        if let trainee = workout.trainee,
           let lastExercise = trainee.lastExercise(for: definition),
           let lastSet = lastExercise.sortedSets.first {
            let firstSet = WorkoutSet(order: 0, weight: lastSet.weight, reps: lastSet.reps, exercise: exercise)
            modelContext.insert(firstSet)
        } else {
            let firstSet = WorkoutSet(order: 0, exercise: exercise)
            modelContext.insert(firstSet)
        }
    }
}
