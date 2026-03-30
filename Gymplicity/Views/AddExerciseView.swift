import SwiftUI
import SwiftData

struct AddExerciseView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.exerciseSearchEngine) private var searchEngine
    let group: WorkoutGroupEntity
    let trainer: IdentityEntity?
    @State private var searchText = ""
    @State private var results = ExerciseSearchResults(
        userExercises: [],
        catalogExercises: []
    )
    @State private var userExercises: [ExerciseEntity] = []
    @State private var recentlyUsedIDs: Set<UUID> = []
    @State private var isLoaded = false
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

                if !results.userExercises.isEmpty
                    || !results.catalogExercises.isEmpty
                {
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
                                        VStack(
                                        alignment: .leading,
                                        spacing: GymMetrics.space4
                                    ) {
                                            Text(result.exercise.name)
                                                .foregroundStyle(.primary)
                                            ExerciseAttributePills(
                                                exercise: result.exercise
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollDismissesKeyboard(
                        .immediately
                    )
                } else if !searchText.isEmpty {
                    VStack(spacing: GymMetrics.space8) {
                        Spacer()
                        MascotView(
                            pose: .thinking,
                            color: GymColors.secondaryText
                        )
                            .frame(height: GymMetrics.mascotSmall)
                        Text("No matches — tap Add to create")
                            .font(GymFont.body)
                            .foregroundStyle(
                                GymColors.secondaryText
                            )
                        Text("\"\(searchText)\"")
                            .font(GymFont.bodyStrong)
                        Spacer()
                    }
                } else {
                    VStack(spacing: GymMetrics.space8) {
                        Spacer()
                        AnimatedMascotView(
                        pose: .thinking,
                        animation: .pulse,
                        color: GymColors.secondaryText
                    )
                            .frame(height: GymMetrics.mascotSmall)
                        Text(
                            isLoaded
                                ? "Type an exercise name"
                                : "Loading exercises..."
                        )
                            .font(GymFont.body)
                            .foregroundStyle(
                            GymColors.secondaryText
                        )
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
                        .disabled(
                            searchText
                                .trimmingCharacters(
                                    in: .whitespaces
                                ).isEmpty
                        )
                }
            }
            .task {
                nameFieldFocused = true
                guard let trainer else { return }
                userExercises = trainer
                    .exerciseCatalog(in: modelContext)
                results = searchEngine.search(
                    query: "",
                    userExercises: userExercises,
                    recentlyUsedIDs: []
                )
                isLoaded = true
                await Task.yield()
                recentlyUsedIDs = BatchTraversal
                    .exerciseIdsUsed(
                        for: trainer,
                        in: modelContext
                    )
                results = searchEngine.search(
                    query: searchText,
                    userExercises: userExercises,
                    recentlyUsedIDs: recentlyUsedIDs
                )
            }
            .task(id: searchText) {
                try? await Task.sleep(
                    for: .milliseconds(
                        GymMetrics.searchDebounceMs
                    )
                )
                guard !Task.isCancelled, isLoaded
                else { return }
                results = searchEngine.search(
                    query: searchText,
                    userExercises: userExercises,
                    recentlyUsedIDs: recentlyUsedIDs
                )
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func addExisting(_ exercise: ExerciseEntity) {
        nameFieldFocused = false
        createSet(for: exercise)
        dismiss()
    }

    private func addFromCatalog(
        _ catalogExercise: CatalogExercise
    ) {
        nameFieldFocused = false
        guard let trainer else { return }
        let exercise = trainer.findOrCreateExercise(
            named: catalogExercise.name,
            in: modelContext
        )
        if exercise.catalogId == nil {
            exercise.catalogId = catalogExercise.id
        }
        createSet(for: exercise)
        SyncTrigger.structureChanged()
        dismiss()
    }

    private func addExercise() {
        nameFieldFocused = false
        let trimmed = searchText
            .trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let trainer
        else { return }
        let exercise = trainer.findOrCreateExercise(
            named: trimmed,
            in: modelContext
        )
        createSet(for: exercise)
        SyncTrigger.structureChanged()
        dismiss()
    }

    private func createSet(for exercise: ExerciseEntity) {
        let owner = group
            .workout(in: modelContext)
            .owner(in: modelContext)
        modelContext.addSet(
            to: group,
            exercise: exercise,
            seedingFrom: owner
        )
    }
}

