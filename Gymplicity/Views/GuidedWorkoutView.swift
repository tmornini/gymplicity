import SwiftUI
import SwiftData

struct GuidedWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var workout: WorkoutEntity
    var onSwitchToList: (() -> Void)? = nil
    var initialSetIndex: Int? = nil
    var onSetIndexChange: ((Int) -> Void)? = nil
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

        // Batch-fetch lastSets for all exercises
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
        let groupIndex = groups.firstIndex(
            where: { $0.group.id == pair.group.id }
        ) ?? 0
        let groupSnap = groups.indices
            .contains(groupIndex)
            ? groups[groupIndex]
            : nil
        let setIndex = groupSnap?.sets.firstIndex(
            where: { $0.set.id == pair.set.id }
        ) ?? 0
        let setsInGroupCount = groupSnap?.sets.count ?? 0

        VStack(spacing: 20) {
            Spacer()

            HStack(spacing: GymMetrics.space8) {
                MascotView(pose: .curling, color: GymColors.energy)
                    .frame(height: GymMetrics.mascotTiny)
                VStack(alignment: .leading, spacing: GymMetrics.space4) {
                    Text(exercise?.name ?? "Exercise")
                        .font(GymFont.heading1)
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
                fieldWidth: 130,
                showLabels: false,
                repsUnit: "reps",
                focusedField: $focusedField
            )

            progressBar(snapshot: snapshot, flatSets: flatSets)

            LastSetReference(set: exercise.flatMap { lastSets[$0.id] })

            Button {
                completeCurrentSet()
            } label: {
                Text("Done")
            }
            .buttonStyle(.gymPrimary)
            .padding(.horizontal, 40)

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
            .padding(.horizontal, 40)
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

    private func completeCurrentSet() {
        let flatSets = workout.allSetsFlattened(in: modelContext)
        guard currentIndex >= 0, currentIndex < flatSets.count else { return }
        let pair = flatSets[currentIndex]

        pair.set.weight =
            Double(weightText) ?? 0
        pair.set.reps = Int(repsText) ?? 0
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
            // Brief walking transition
            withAnimation(.easeInOut(duration: 0.3)) {
                showWalkingTransition = true
            }
            Task {
                try? await Task.sleep(for: .milliseconds(300))
                currentIndex = next
                onSetIndexChange?(currentIndex)
                loadCurrentSet()
                withAnimation(.easeInOut(duration: 0.3)) {
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
