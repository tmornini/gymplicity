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
    @State private var showWalkingTransition = false
    @FocusState private var focusedField: WeightRepsField.Field?

    private var flatSets: [(group: WorkoutGroupEntity, set: SetEntity)] {
        workout.allSetsFlattened(in: modelContext)
    }

    private var currentPair: (group: WorkoutGroupEntity, set: SetEntity)? {
        guard currentIndex >= 0, currentIndex < flatSets.count else { return nil }
        return flatSets[currentIndex]
    }

    var body: some View {
        Group {
            if let pair = currentPair {
                guidedContent(pair: pair)
            } else if flatSets.isEmpty {
                emptyState
            } else {
                completionView
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
        }
        .confirmationDialog("End Workout?", isPresented: $showingEndConfirmation) {
            Button("End Workout", role: .destructive) {
                endWorkout()
            }
            Button("Cancel", role: .cancel) { }
        }
        .onAppear {
            if let saved = initialSetIndex {
                currentIndex = saved
            } else if let first = workout.firstIncompleteSetIndex(in: modelContext) {
                currentIndex = first
            }
            loadCurrentSet()
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: GymMetrics.space16) {
            AnimatedMascotView(pose: .stretching, animation: .wobble, color: GymColors.secondaryText)
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
    private func guidedContent(pair: (group: WorkoutGroupEntity, set: SetEntity)) -> some View {
        let exercise = pair.set.exercise(in: modelContext)
        let groups = workout.sortedGroups(in: modelContext)
        let groupIndex = groups.firstIndex(where: { $0.id == pair.group.id }) ?? 0
        let setsInGroup = pair.group.sortedSets(in: modelContext)
        let setIndex = setsInGroup.firstIndex(where: { $0.id == pair.set.id }) ?? 0

        VStack(spacing: 20) {
            Spacer()

            HStack(spacing: GymMetrics.space8) {
                MascotView(pose: .curling, color: GymColors.energy)
                    .frame(height: GymMetrics.mascotTiny)
                Text(exercise?.name ?? "Exercise")
                    .font(GymFont.heading1)
            }

            Text("Group \(groupIndex + 1) of \(groups.count) \u{00B7} Set \(setIndex + 1) of \(setsInGroup.count)")
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

            progressBar

            LastSetReference(set: previousSet(for: exercise))

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
                MascotView(pose: .walking, color: GymColors.energy.opacity(0.5))
                    .frame(height: GymMetrics.mascotTiny)
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            }
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        let progress = workout.completionProgress(in: modelContext)
        let completed = flatSets.filter { $0.set.isCompleted }.count
        return VStack(spacing: GymMetrics.space4) {
            GymProgressBar(progress: progress)
            Text("\(completed)/\(flatSets.count) sets \u{00B7} \(Int(progress * 100))%")
                .font(GymFont.caption)
                .foregroundStyle(GymColors.secondaryText)
        }
        .padding(.horizontal)
    }

    // MARK: - Completion View

    private var completionView: some View {
        VStack(spacing: GymMetrics.space16) {
            AnimatedMascotView(pose: .celebrating, animation: .bounce, color: GymColors.power)
                .frame(height: GymMetrics.mascotLarge)
            Text("All Sets Complete!")
                .font(GymFont.heading1)
            Text("\(flatSets.count) sets finished")
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
        workout.isComplete = true
        SyncTrigger.entityUpdated("WorkoutEntity", id: workout.id)
        if onSwitchToList == nil { dismiss() }
    }

    private func completeCurrentSet() {
        guard let pair = currentPair else { return }
        pair.set.weight = Double(weightText) ?? 0
        pair.set.reps = Int(repsText) ?? 0
        pair.set.isCompleted = true
        pair.set.completedAt = .now
        SyncTrigger.entityUpdated("SetEntity", id: pair.set.id)

        if let next = workout.nextIncompleteSetIndex(after: currentIndex, in: modelContext) {
            // Brief walking transition
            withAnimation(.easeInOut(duration: 0.3)) {
                showWalkingTransition = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
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
        guard let pair = currentPair else { return }
        weightText = pair.set.weight > 0 ? Weight.rawValue(pair.set.weight) : ""
        repsText = pair.set.reps > 0 ? "\(pair.set.reps)" : ""
        focusedField = .weight
        onSetIndexChange?(currentIndex)
    }

    private func previousSet(for exercise: ExerciseEntity?) -> SetEntity? {
        guard let exercise, let owner = workout.owner(in: modelContext) else { return nil }
        return owner.lastSet(for: exercise, in: modelContext)
    }
}
