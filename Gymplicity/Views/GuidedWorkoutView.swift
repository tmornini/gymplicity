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
    @FocusState private var focusedField: Field?

    enum Field { case weight, reps }

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
                ContentUnavailableView {
                    Label("No Sets", systemImage: "figure.strengthtraining.traditional")
                } description: {
                    Text("Add exercises to this workout first")
                }
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
                    .tint(.red)
            }
        }
        .confirmationDialog("End Workout?", isPresented: $showingEndConfirmation) {
            Button("End Workout", role: .destructive) {
                workout.isComplete = true
                if onSwitchToList == nil {
                    dismiss()
                }
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

            Text(exercise?.name ?? "Exercise")
                .font(.title2.weight(.bold))

            Text("Group \(groupIndex + 1) of \(groups.count) \u{00B7} Set \(setIndex + 1) of \(setsInGroup.count)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 24) {
                VStack(spacing: 8) {
                    TextField("0", text: $weightText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 44, weight: .bold, design: .rounded).monospacedDigit())
                        .frame(width: 130)
                        .focused($focusedField, equals: .weight)
                    Text("lb")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text("x")
                    .font(.title2)
                    .foregroundStyle(.secondary)

                VStack(spacing: 8) {
                    TextField("0", text: $repsText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 44, weight: .bold, design: .rounded).monospacedDigit())
                        .frame(width: 130)
                        .focused($focusedField, equals: .reps)
                    Text("reps")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            progressBar

            lastTimeReference(exercise: exercise)

            Button {
                completeCurrentSet()
            } label: {
                Text("Done")
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 40)

            Spacer()
        }
        .padding()
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        let progress = workout.completionProgress(in: modelContext)
        let completed = flatSets.filter { $0.set.isCompleted }.count
        return VStack(spacing: 4) {
            ProgressView(value: progress)
                .tint(.green)
            Text("\(completed)/\(flatSets.count) sets \u{00B7} \(Int(progress * 100))%")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
    }

    // MARK: - Last Time Reference

    @ViewBuilder
    private func lastTimeReference(exercise: ExerciseEntity?) -> some View {
        if let exercise,
           let owner = workout.owner(in: modelContext),
           let lastSet = owner.lastSet(for: exercise, in: modelContext) {
            HStack(spacing: 4) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.caption)
                Text("Last time: \(formatWeight(lastSet.weight)) x \(lastSet.reps)")
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Completion View

    private var completionView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
            Text("All Sets Complete!")
                .font(.title2.weight(.bold))
            Text("\(flatSets.count) sets finished")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button("End Workout") {
                workout.isComplete = true
                if onSwitchToList == nil {
                    dismiss()
                }
            }
            .buttonStyle(.borderedProminent)
            .padding(.top)
        }
    }

    // MARK: - Actions

    private func completeCurrentSet() {
        guard let pair = currentPair else { return }
        pair.set.weight = Double(weightText) ?? 0
        pair.set.reps = Int(repsText) ?? 0
        pair.set.isCompleted = true
        pair.set.completedAt = .now

        if let next = workout.nextIncompleteSetIndex(after: currentIndex, in: modelContext) {
            currentIndex = next
            onSetIndexChange?(currentIndex)
            loadCurrentSet()
        } else {
            // All complete — show completion view
            currentIndex = flatSets.count
            onSetIndexChange?(currentIndex)
        }
    }

    private func loadCurrentSet() {
        guard let pair = currentPair else { return }
        weightText = pair.set.weight > 0 ? formatWeightValue(pair.set.weight) : ""
        repsText = pair.set.reps > 0 ? "\(pair.set.reps)" : ""
        focusedField = .weight
        onSetIndexChange?(currentIndex)
    }

    private func formatWeight(_ weight: Double) -> String {
        if weight == weight.rounded() {
            return "\(Int(weight)) lb"
        }
        return String(format: "%.1f lb", weight)
    }

    private func formatWeightValue(_ weight: Double) -> String {
        if weight == weight.rounded() {
            return "\(Int(weight))"
        }
        return String(format: "%.1f", weight)
    }
}
