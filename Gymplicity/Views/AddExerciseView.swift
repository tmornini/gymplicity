import SwiftUI
import SwiftData

struct AddExerciseView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let session: Session
    @State private var searchText = ""
    @FocusState private var nameFieldFocused: Bool

    private var trainer: Trainer? {
        session.trainee?.trainer
    }

    /// Exercises from the trainer's catalog, filtered by search text.
    private var suggestions: [Exercise] {
        guard let trainer else { return [] }
        let all = trainer.exercises.sorted { $0.name < $1.name }
        if searchText.isEmpty { return all }
        return all.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    /// Exercise IDs already in this session (to avoid duplicates).
    private var exerciseIDsInSession: Set<UUID> {
        Set(session.entries.compactMap { $0.exercise?.id })
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
                        ForEach(suggestions) { exercise in
                            let alreadyAdded = exerciseIDsInSession.contains(exercise.id)
                            Button {
                                addExisting(exercise)
                            } label: {
                                HStack {
                                    Text(exercise.name)
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

    private func addExisting(_ exercise: Exercise) {
        guard !exerciseIDsInSession.contains(exercise.id) else { return }
        createEntry(for: exercise)
        dismiss()
    }

    private func addExercise() {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let trainer else { return }

        let exercise = trainer.findOrCreateExercise(named: trimmed, in: modelContext)
        guard !exerciseIDsInSession.contains(exercise.id) else { return }
        createEntry(for: exercise)
        dismiss()
    }

    private func createEntry(for exercise: Exercise) {
        let entry = SessionEntry(exercise: exercise, order: session.nextEntryOrder, session: session)
        modelContext.insert(entry)

        // Pre-populate first set from last session
        if let trainee = session.trainee,
           let lastEntry = trainee.lastEntry(for: exercise),
           let lastSet = lastEntry.sortedSets.first {
            let firstSet = ExerciseSet(order: 0, weight: lastSet.weight, reps: lastSet.reps, entry: entry)
            modelContext.insert(firstSet)
        } else {
            let firstSet = ExerciseSet(order: 0, entry: entry)
            modelContext.insert(firstSet)
        }
    }
}
