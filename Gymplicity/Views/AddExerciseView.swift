import SwiftUI
import SwiftData

struct AddExerciseView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let group: WorkoutGroupEntity
    let trainer: IdentityEntity?
    @State private var searchText = ""
    @FocusState private var nameFieldFocused: Bool

    private var suggestions: [ExerciseEntity] {
        guard let trainer else { return [] }
        let catalog = trainer.exercises(in: modelContext).sorted { $0.name < $1.name }
        if searchText.isEmpty { return catalog }
        return catalog.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TextField("Exercise name", text: $searchText)
                    .focused($nameFieldFocused)
                    .font(GymFont.heading3)
                    .padding()
                    .submitLabel(.done)
                    .onSubmit { addExercise() }
                    .autocorrectionDisabled()

                Divider()

                if !suggestions.isEmpty {
                    List {
                        ForEach(suggestions) { exercise in
                            Button {
                                addExisting(exercise)
                            } label: {
                                Text(exercise.name)
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                    .listStyle(.plain)
                } else if !searchText.isEmpty {
                    VStack(spacing: GymMetrics.space8) {
                        Spacer()
                        MascotView(pose: .thinking, color: GymColors.secondaryText)
                            .frame(height: GymMetrics.mascotSmall)
                        Text("No matches — tap Add to create")
                            .font(GymFont.body)
                            .foregroundStyle(GymColors.secondaryText)
                        Text("\"\(searchText)\"")
                            .font(GymFont.bodyStrong)
                        Spacer()
                    }
                } else {
                    VStack(spacing: GymMetrics.space8) {
                        Spacer()
                        AnimatedMascotView(pose: .thinking, animation: .pulse, color: GymColors.secondaryText)
                            .frame(height: GymMetrics.mascotSmall)
                        Text("Type an exercise name")
                            .font(GymFont.body)
                            .foregroundStyle(GymColors.secondaryText)
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
                        .foregroundStyle(GymColors.energy)
                        .disabled(searchText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { nameFieldFocused = true }
        }
        .presentationDetents([.medium, .large])
    }

    private func addExisting(_ exercise: ExerciseEntity) {
        createSet(for: exercise)
        dismiss()
    }

    private func addExercise() {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let trainer else { return }
        let exercise = trainer.findOrCreateExercise(named: trimmed, in: modelContext)
        createSet(for: exercise)
        SyncTrigger.structureChanged()
        dismiss()
    }

    private func createSet(for exercise: ExerciseEntity) {
        let owner = group.workout(in: modelContext)?.owner(in: modelContext)
        modelContext.addSet(to: group, exercise: exercise, seedingFrom: owner)
    }
}
