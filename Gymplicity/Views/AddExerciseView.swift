import SwiftUI
import SwiftData

struct AddExerciseView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let group: WorkoutGroupEntity
    @State private var searchText = ""
    @FocusState private var nameFieldFocused: Bool

    private var trainer: IdentityEntity? {
        guard let workout = group.workout(in: modelContext),
              let owner = workout.owner(in: modelContext) else { return nil }
        return owner.isTrainer ? owner : owner.trainer(in: modelContext)
    }

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
        dismiss()
    }

    private func createSet(for exercise: ExerciseEntity) {
        let owner: IdentityEntity? = {
            guard let workout = group.workout(in: modelContext) else { return nil }
            return workout.owner(in: modelContext)
        }()

        var weight: Double = 0
        var reps: Int = 0
        if let owner, let lastSet = owner.lastSet(for: exercise, in: modelContext) {
            weight = lastSet.weight
            reps = lastSet.reps
        }

        let set = SetEntity(order: group.nextSetOrder(in: modelContext), weight: weight, reps: reps)
        modelContext.insert(set)
        let groupJoin = GroupSets(groupId: group.id, setId: set.id)
        modelContext.insert(groupJoin)
        let exerciseJoin = ExerciseSets(exerciseId: exercise.id, setId: set.id)
        modelContext.insert(exerciseJoin)
    }
}
