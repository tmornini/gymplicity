import SwiftUI
import SwiftData

struct AddExerciseView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let session: Session
    @State private var exerciseName = ""
    @FocusState private var nameFieldFocused: Bool

    /// All unique exercise names ever used by this trainee.
    private var suggestions: [String] {
        guard let trainee = session.trainee else { return [] }
        let allNames = trainee.allExerciseNames
        if exerciseName.isEmpty { return allNames }
        return allNames.filter { $0.localizedCaseInsensitiveContains(exerciseName) }
    }

    /// Exercise names already in this session (to avoid duplicates).
    private var namesInSession: Set<String> {
        Set(session.entries.map { $0.exerciseName.lowercased() })
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TextField("Exercise name", text: $exerciseName)
                    .focused($nameFieldFocused)
                    .font(.title3)
                    .padding()
                    .submitLabel(.done)
                    .onSubmit { addExercise() }
                    .autocorrectionDisabled()

                Divider()

                if !suggestions.isEmpty {
                    List {
                        ForEach(suggestions, id: \.self) { name in
                            Button {
                                exerciseName = name
                                addExercise()
                            } label: {
                                HStack {
                                    Text(name)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if namesInSession.contains(name.lowercased()) {
                                        Text("already added")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .disabled(namesInSession.contains(name.lowercased()))
                        }
                    }
                    .listStyle(.plain)
                } else if !exerciseName.isEmpty {
                    VStack(spacing: 8) {
                        Spacer()
                        Text("New exercise")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("Tap Add to create \"\(exerciseName)\"")
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
                        .disabled(exerciseName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { nameFieldFocused = true }
        }
        .presentationDetents([.medium, .large])
    }

    private func addExercise() {
        let trimmed = exerciseName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        guard !namesInSession.contains(trimmed.lowercased()) else { return }

        let entry = SessionEntry(exerciseName: trimmed, order: session.nextEntryOrder, session: session)
        modelContext.insert(entry)

        // Pre-populate first set from last session
        if let trainee = session.trainee,
           let lastEntry = trainee.lastEntry(for: trimmed),
           let lastSet = lastEntry.sortedSets.first {
            let firstSet = ExerciseSet(order: 0, weight: lastSet.weight, reps: lastSet.reps, entry: entry)
            modelContext.insert(firstSet)
        } else {
            let firstSet = ExerciseSet(order: 0, entry: entry)
            modelContext.insert(firstSet)
        }

        dismiss()
    }
}
