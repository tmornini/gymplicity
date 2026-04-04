import SwiftUI
import SwiftData

struct GuidedWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var workout: WorkoutEntity
    let onSwitchToList: (() -> Void)?
    let initialSetIndex: Int?
    let onSetIndexChange: ((Int) -> Void)?
    @State private var currentIndex: Int = 0
    @State private var weightText: String = ""
    @State private var repsText: String = ""
    @State private var showingEndConfirmation = false
    @State private var showingDeleteWorkout = false
    @State private var showWalkingTransition = false
    @FocusState private var focusedField: WeightRepsField.Field?

    var body: some View {
        let snapshot = WorkoutSnapshot.load(workout, in: modelContext)
        let flatSets = snapshot.allSetsFlattened
        let owner = workout.owner(in: modelContext)

        // Single fetch prevents N+1 queries
        let exerciseIds = Array(Set(
            snapshot.groups.flatMap { g in
                g.sets.compactMap { $0.exercise?.id }
            }
        ))
        let lastSets = BatchTraversal.lastSets(
            for: owner,
            exerciseIds: exerciseIds,
            in: modelContext
        )

        let currentPair: (group: WorkoutGroupEntity, set: SetEntity)? = {
            guard currentIndex >= 0,
                  currentIndex < flatSets.count
            else { return nil }
            return flatSets[currentIndex]
        }()

        Group {
            if let pair = currentPair {
                guidedContent(
                    pair: pair,
                    snapshot: snapshot,
                    flatSets: flatSets,
                    lastSets: lastSets
                )
            } else if flatSets.isEmpty {
                emptyState
            } else {
                completionView(setCount: flatSets.count)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("List View") {
                    if let onSwitchToList {
                        onSwitchToList()
                    } else {
                        dismiss()
                    }
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button("End") { showingEndConfirmation = true }
                    .fontWeight(.semibold)
                    .foregroundStyle(GymColors.danger)
            }
            ToolbarItem(placement: .primaryAction) {
                Button { showingDeleteWorkout = true } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(GymColors.danger)
                }
            }
        }
        .confirmationDialog(
            "End Workout?",
            isPresented: $showingEndConfirmation
        ) {
            Button("End Workout", role: .destructive) {
                endWorkout()
            }
            Button("Cancel", role: .cancel) { }
        }
        .confirmationDialog(
            "Delete Workout?",
            isPresented: $showingDeleteWorkout
        ) {
            Button(
                "Delete Workout",
                role: .destructive
            ) {
                deleteWorkout()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            let groups = snapshot.groups
            let setCount = groups
                .flatMap(\.sets).count
            Text(
                "This workout has"
                    + " \(groups.count)"
                    + " group\(groups.count == 1 ? "" : "s")"
                    + " and \(setCount)"
                    + " set\(setCount == 1 ? "" : "s")."
                    + " This cannot be undone."
            )
        }
        .onAppear {
            if let saved = initialSetIndex {
                currentIndex = saved
            } else if let first = workout
                .firstIncompleteSetIndex(in: modelContext) {
                currentIndex = first
            }
            loadCurrentSet()
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: GymMetrics.space16) {
            AnimatedMascotView(
                pose: .stretching,
                animation: .wobble,
                color: GymColors.secondaryText
            )
                .frame(height: GymMetrics.mascotMedium)
            Text("No Sets")
                .font(GymFont.heading2)
            Text("Add exercises to this workout first")
                .font(GymFont.body)
                .foregroundStyle(GymColors.secondaryText)
        }
    }

    // MARK: - Guided Content

    @ViewBuilder
    private func guidedContent(
        pair: (group: WorkoutGroupEntity, set: SetEntity),
        snapshot: WorkoutSnapshot,
        flatSets: [(group: WorkoutGroupEntity, set: SetEntity)],
        lastSets: [UUID: SetEntity]
    ) -> some View {
        let exercise = snapshot.subgraph.exercise(for: pair.set.id)
        let groups = snapshot.groups
        let groupIndex: Int = {
            guard let i = groups.firstIndex(
                where: {
                    $0.group.id == pair.group.id
                }
            ) else {
                fatalError(
                    "Group \(pair.group.id)"
                    + " not in snapshot"
                )
            }
            return i
        }()
        let groupSnap = groups[groupIndex]
        let setIndex: Int = {
            guard let i = groupSnap
                .sets.firstIndex(
                    where: {
                        $0.set.id == pair.set.id
                    }
                )
            else {
                fatalError(
                    "Set \(pair.set.id) not in"
                    + " group \(pair.group.id)"
                )
            }
            return i
        }()
        let setsInGroupCount = groupSnap.sets.count

        VStack(spacing: GymMetrics.space20) {
            Spacer()

            HStack(spacing: GymMetrics.space8) {
                MascotView(pose: .curling, color: GymColors.energy)
                    .frame(height: GymMetrics.mascotTiny)
                VStack(alignment: .leading, spacing: GymMetrics.space4) {
                    if let name = exercise?.name {
                        Text(name)
                            .font(GymFont.heading1)
                    }
                    ExerciseAttributePills(exercise: exercise)
                }
            }

            Text(
                "Group \(groupIndex + 1)"
                    + " of \(groups.count)"
                    + " \u{00B7} Set \(setIndex + 1)"
                    + " of \(setsInGroupCount)"
            )
                .font(GymFont.label)
                .foregroundStyle(GymColors.secondaryText)

            WeightRepsField(
                weightText: $weightText,
                repsText: $repsText,
                font: GymFont.numericEntry,
                accentColor: GymColors.energy,
                fieldWidth: GymMetrics
                    .fieldWidthGuided,
                showLabels: false,
                repsUnit: "reps",
                focusedField: $focusedField
            )

            progressBar(snapshot: snapshot, flatSets: flatSets)

            LastSetReference(
                set: exercise.flatMap { lastSets[$0.id] },
                color: GymColors.steel
            )

            Button {
                completeCurrentSet()
            } label: {
                Text("Done")
            }
            .buttonStyle(.gymPrimary)
            .padding(.horizontal, GymMetrics.actionPadding)
            .disabled(!isInputValid)

            Spacer()
        }
        .padding()
        .overlay {
            if showWalkingTransition {
                MascotView(
                    pose: .walking,
                    color: GymColors.energy
                        .opacity(0.5)
                )
                .frame(height: GymMetrics.mascotTiny)
                .transition(.asymmetric(
                    insertion: .move(edge: .leading)
                        .combined(with: .opacity),
                    removal: .move(edge: .trailing)
                        .combined(with: .opacity)
                ))
            }
        }
    }

    // MARK: - Progress Bar

    private func progressBar(
        snapshot: WorkoutSnapshot,
        flatSets: [(
            group: WorkoutGroupEntity,
            set: SetEntity
        )]
    ) -> some View {
        let progress = snapshot.completionProgress
        let completed = flatSets.filter {
            snapshot.subgraph
                .isSetCompleted($0.set.id)
        }.count
        return VStack(spacing: GymMetrics.space4) {
            GymProgressBar(progress: progress)
            Text(
                "\(completed)/\(flatSets.count)"
                    + " sets \u{00B7}"
                    + " \(Int(progress * 100))%"
            )
            .font(GymFont.caption)
            .foregroundStyle(
                GymColors.secondaryText
            )
        }
        .padding(.horizontal)
    }

    // MARK: - Completion View

    private func completionView(setCount: Int) -> some View {
        VStack(spacing: GymMetrics.space16) {
            AnimatedMascotView(
                pose: .celebrating,
                animation: .bounce,
                color: GymColors.power
            )
                .frame(height: GymMetrics.mascotLarge)
            Text("All Sets Complete!")
                .font(GymFont.heading1)
            Text("\(setCount) sets finished")
                .font(GymFont.body)
                .foregroundStyle(GymColors.secondaryText)

            Button("End Workout") {
                endWorkout()
            }
            .buttonStyle(.gymPrimary)
            .padding(.horizontal, GymMetrics.actionPadding)
            .padding(.top)
        }
    }

    // MARK: - Actions

    private func endWorkout() {
        workout.markCompleted(in: modelContext)
        if onSwitchToList == nil { dismiss() }
    }

    private func deleteWorkout() {
        modelContext.deleteWorkout(workout)
        SyncTrigger.structureChanged()
        if onSwitchToList == nil { dismiss() }
    }

    private var isInputValid: Bool {
        (weightText.isEmpty
            || Double(weightText) != nil)
            && (repsText.isEmpty
                || Int(repsText) != nil)
    }

    private func completeCurrentSet() {
        let flatSets = workout.allSetsFlattened(
            in: modelContext
        )
        let parsedWeight = Double(weightText)
        let parsedReps = Int(repsText)
        guard
            weightText.isEmpty
                || parsedWeight != nil,
            repsText.isEmpty
                || parsedReps != nil,
            currentIndex >= 0,
            currentIndex < flatSets.count
        else { return }
        let pair = flatSets[currentIndex]

        pair.set.weight = parsedWeight ?? 0
        pair.set.reps = parsedReps ?? 0
        modelContext.insert(
            SetCompletions(
                setId: pair.set.id,
                completedAt: .now
            )
        )
        SyncTrigger.entityUpdated(
            .set,
            id: pair.set.id
        )

        if let next = workout.nextIncompleteSetIndex(
            after: currentIndex,
            in: modelContext
        ) {
            // Visual breathing room between exercises
            withAnimation(
                .easeInOut(
                    duration: GymMetrics
                        .animationMedium
                )
            ) {
                showWalkingTransition = true
            }
            Task {
                do {
                    try await Task.sleep(
                        for: .milliseconds(
                            GymMetrics
                                .transitionDelayMs
                        )
                    )
                } catch {
                    return
                }
                currentIndex = next
                onSetIndexChange?(currentIndex)
                loadCurrentSet()
                withAnimation(
                    .easeInOut(
                        duration: GymMetrics
                            .animationMedium
                    )
                ) {
                    showWalkingTransition = false
                }
            }
        } else {
            currentIndex = flatSets.count
            onSetIndexChange?(currentIndex)
        }
    }

    private func loadCurrentSet() {
        let flatSets = workout.allSetsFlattened(in: modelContext)
        guard currentIndex >= 0, currentIndex < flatSets.count else { return }
        let pair = flatSets[currentIndex]
        weightText = pair.set.weight > 0
            ? Weight.rawValue(pair.set.weight)
            : ""
        repsText = pair.set.reps > 0 ? "\(pair.set.reps)" : ""
        focusedField = .weight
        onSetIndexChange?(currentIndex)
    }
}
