import SwiftUI
import SwiftData

struct ActiveWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var workout: WorkoutEntity
    @State private var showingAddExercise = false
    @State private var showingEndConfirmation = false
    @State private var targetSuperset: SupersetEntity?

    var body: some View {
        List {
            ForEach(workout.sortedSupersets(in: modelContext)) { superset in
                Section {
                    ForEach(superset.sortedSets(in: modelContext)) { set in
                        SetRow(set: set, superset: superset, workout: workout)
                    }
                    .onDelete { offsets in deleteSets(from: superset, at: offsets) }

                    Button {
                        targetSuperset = superset
                        showingAddExercise = true
                    } label: {
                        Label("Add Set", systemImage: "plus")
                            .font(.subheadline)
                    }
                } header: {
                    Text("Superset \(superset.order + 1)")
                        .font(.headline)
                        .textCase(nil)
                }
            }

            Section {
                Button {
                    addSuperset()
                } label: {
                    Label("Add Superset", systemImage: "plus.circle.fill")
                        .font(.body.weight(.medium))
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 0) {
                    Text(workout.owner(in: modelContext)?.name ?? "Workout")
                        .font(.headline)
                    Text(workout.date, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button("End") { showingEndConfirmation = true }
                    .fontWeight(.semibold)
                    .tint(.red)
            }
        }
        .confirmationDialog("End Workout?", isPresented: $showingEndConfirmation) {
            Button("End Workout", role: .destructive) { endWorkout() }
            Button("Cancel", role: .cancel) { }
        } message: {
            let supersets = workout.supersets(in: modelContext)
            let setCount = supersets.flatMap { $0.sets(in: modelContext) }.count
            Text("This workout has \(supersets.count) superset\(supersets.count == 1 ? "" : "s") and \(setCount) set\(setCount == 1 ? "" : "s").")
        }
        .sheet(isPresented: $showingAddExercise) {
            if let superset = targetSuperset {
                AddExerciseView(superset: superset)
            }
        }
    }

    private func addSuperset() {
        let superset = SupersetEntity(order: workout.nextSupersetOrder(in: modelContext))
        modelContext.insert(superset)
        let join = WorkoutSupersets(workoutId: workout.id, supersetId: superset.id)
        modelContext.insert(join)
        targetSuperset = superset
        showingAddExercise = true
    }

    private func deleteSets(from superset: SupersetEntity, at offsets: IndexSet) {
        let sorted = superset.sortedSets(in: modelContext)
        for index in offsets {
            modelContext.deleteSet(sorted[index])
        }
    }

    private func endWorkout() {
        workout.isComplete = true
        dismiss()
    }
}

// MARK: - Set Row

struct SetRow: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var set: SetEntity
    let superset: SupersetEntity
    let workout: WorkoutEntity
    @State private var showingEditor = false

    var body: some View {
        Button {
            showingEditor = true
        } label: {
            HStack {
                let exercise = set.exercise(in: modelContext)
                Text(exercise?.name ?? "Exercise")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 60, alignment: .leading)

                if set.weight > 0 || set.reps > 0 {
                    Text(formatWeight(set.weight))
                        .font(.body.monospacedDigit().weight(.medium))
                    Text("x")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(set.reps)")
                        .font(.body.monospacedDigit().weight(.medium))
                } else {
                    Text("Tap to enter")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                Button {
                    set.isCompleted.toggle()
                    set.completedAt = set.isCompleted ? .now : nil
                } label: {
                    Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(set.isCompleted ? .green : .secondary)
                }
                .buttonStyle(.plain)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingEditor) {
            SetEntryView(
                set: set,
                exercise: set.exercise(in: modelContext),
                previousSet: previousSet()
            )
        }
    }

    private func previousSet() -> SetEntity? {
        guard let exercise = set.exercise(in: modelContext),
              let owner = workout.owner(in: modelContext) else { return nil }
        return owner.lastSet(for: exercise, in: modelContext)
    }

    private func formatWeight(_ weight: Double) -> String {
        if weight == weight.rounded() {
            return "\(Int(weight)) lb"
        }
        return String(format: "%.1f lb", weight)
    }
}
