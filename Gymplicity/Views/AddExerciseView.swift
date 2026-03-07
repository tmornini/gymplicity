import SwiftUI
import SwiftData

struct AddExerciseView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let group: WorkoutGroupEntity
    let trainer: IdentityEntity?
    @State private var searchText = ""
    @State private var results = ExerciseSearchResults(userExercises: [], catalogExercises: [])
    @State private var cachedUserExercises: [ExerciseEntity] = []
    @State private var cachedRecentlyUsedIDs: Set<UUID> = []
    @FocusState private var nameFieldFocused: Bool

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

                if !results.userExercises.isEmpty || !results.catalogExercises.isEmpty {
                    List {
                        if !results.userExercises.isEmpty {
                            Section("Your Exercises") {
                                ForEach(results.userExercises) { result in
                                    Button {
                                        addExisting(result.exercise)
                                    } label: {
                                        Text(result.exercise.name)
                                            .foregroundStyle(.primary)
                                    }
                                }
                            }
                        }

                        if !results.catalogExercises.isEmpty {
                            Section("Exercise Catalog") {
                                ForEach(results.catalogExercises) { result in
                                    Button {
                                        addFromCatalog(result.exercise)
                                    } label: {
                                        VStack(alignment: .leading, spacing: GymMetrics.space4) {
                                            Text(result.exercise.name)
                                                .foregroundStyle(.primary)
                                            MatchReasonPillRow(reasons: result.reasons)
                                        }
                                    }
                                }
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
            .onAppear {
                nameFieldFocused = true
                guard let trainer else { return }
                cachedUserExercises = trainer.exerciseCatalog(in: modelContext)
                cachedRecentlyUsedIDs = Set(trainer.exercisesUsed(in: modelContext).map(\.id))
                results = ExerciseSearchEngine.shared.search(
                    query: "",
                    userExercises: cachedUserExercises,
                    recentlyUsedIDs: cachedRecentlyUsedIDs
                )
            }
            .task(id: searchText) {
                try? await Task.sleep(for: .milliseconds(200))
                guard !Task.isCancelled else { return }
                results = ExerciseSearchEngine.shared.search(
                    query: searchText,
                    userExercises: cachedUserExercises,
                    recentlyUsedIDs: cachedRecentlyUsedIDs
                )
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func addExisting(_ exercise: ExerciseEntity) {
        createSet(for: exercise)
        dismiss()
    }

    private func addFromCatalog(_ catalogExercise: CatalogExercise) {
        guard let trainer else { return }
        let exercise = trainer.findOrCreateExercise(named: catalogExercise.name, in: modelContext)
        if exercise.catalogId == nil {
            exercise.catalogId = catalogExercise.id
        }
        createSet(for: exercise)
        SyncTrigger.structureChanged()
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

// MARK: - Match Reason Pills

private struct MatchReasonPillRow: View {
    let reasons: [MatchReason]

    var body: some View {
        HStack(spacing: GymMetrics.space4) {
            ForEach(Array(reasons.prefix(3).enumerated()), id: \.offset) { _, reason in
                Text(reason.displayLabel)
                    .gymPill(reason.pillColor)
            }
        }
    }
}
