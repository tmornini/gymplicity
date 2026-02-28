import SwiftUI
import SwiftData

struct ActiveSessionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var session: Session
    @State private var showingAddExercise = false
    @State private var showingEndConfirmation = false

    var body: some View {
        List {
            ForEach(session.sortedEntries) { entry in
                Section {
                    ForEach(entry.sortedSets) { exerciseSet in
                        SetRow(exerciseSet: exerciseSet, entry: entry, trainee: session.trainee)
                    }
                    .onDelete { offsets in deleteSets(from: entry, at: offsets) }

                    Button {
                        addSet(to: entry)
                    } label: {
                        Label("Add Set", systemImage: "plus")
                            .font(.subheadline)
                    }
                } header: {
                    Text(entry.exerciseName)
                        .font(.headline)
                        .textCase(nil)
                }
            }

            Section {
                Button {
                    showingAddExercise = true
                } label: {
                    Label("Add Exercise", systemImage: "plus.circle.fill")
                        .font(.body.weight(.medium))
                }
            }
        }
        .navigationTitle(session.trainee?.name ?? "Session")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 0) {
                    Text(session.trainee?.name ?? "Session")
                        .font(.headline)
                    Text(session.date, style: .date)
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
        .confirmationDialog("End Session?", isPresented: $showingEndConfirmation) {
            Button("End Session", role: .destructive) { endSession() }
            Button("Cancel", role: .cancel) { }
        } message: {
            let setCount = session.entries.flatMap(\.sets).count
            Text("This session has \(session.exerciseCount) exercise\(session.exerciseCount == 1 ? "" : "s") and \(setCount) set\(setCount == 1 ? "" : "s").")
        }
        .sheet(isPresented: $showingAddExercise) {
            AddExerciseView(session: session)
        }
    }

    private func addSet(to entry: SessionEntry) {
        let previousSets = entry.sortedSets
        let lastSet = previousSets.last

        // Pre-fill from previous set in this entry, or from last session
        let weight = lastSet?.weight ?? previousWeight(for: entry)
        let reps = lastSet?.reps ?? previousReps(for: entry)

        let newSet = ExerciseSet(order: entry.nextSetOrder, weight: weight, reps: reps, entry: entry)
        modelContext.insert(newSet)
    }

    private func previousWeight(for entry: SessionEntry) -> Double {
        guard let trainee = session.trainee,
              let lastEntry = trainee.lastEntry(for: entry.exerciseName),
              let lastSet = lastEntry.sortedSets.first else { return 0 }
        return lastSet.weight
    }

    private func previousReps(for entry: SessionEntry) -> Int {
        guard let trainee = session.trainee,
              let lastEntry = trainee.lastEntry(for: entry.exerciseName),
              let lastSet = lastEntry.sortedSets.first else { return 0 }
        return lastSet.reps
    }

    private func deleteSets(from entry: SessionEntry, at offsets: IndexSet) {
        let sorted = entry.sortedSets
        for index in offsets {
            modelContext.delete(sorted[index])
        }
    }

    private func endSession() {
        session.isComplete = true
        dismiss()
    }
}

// MARK: - Set Row

struct SetRow: View {
    @Bindable var exerciseSet: ExerciseSet
    let entry: SessionEntry
    let trainee: Trainee?
    @State private var showingEditor = false

    var body: some View {
        Button {
            showingEditor = true
        } label: {
            HStack {
                Text("Set \(setNumber)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(width: 44, alignment: .leading)

                if exerciseSet.weight > 0 || exerciseSet.reps > 0 {
                    Text(formatWeight(exerciseSet.weight))
                        .font(.body.monospacedDigit().weight(.medium))
                    Text("x")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(exerciseSet.reps)")
                        .font(.body.monospacedDigit().weight(.medium))
                } else {
                    Text("Tap to enter")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                Button {
                    exerciseSet.isCompleted.toggle()
                } label: {
                    Image(systemName: exerciseSet.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(exerciseSet.isCompleted ? .green : .secondary)
                }
                .buttonStyle(.plain)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingEditor) {
            SetEntryView(
                exerciseSet: exerciseSet,
                exerciseName: entry.exerciseName,
                setNumber: setNumber,
                previousEntry: trainee?.lastEntry(for: entry.exerciseName)
            )
        }
    }

    private var setNumber: Int {
        let sorted = entry.sortedSets
        return (sorted.firstIndex(where: { $0.id == exerciseSet.id }) ?? 0) + 1
    }

    private func formatWeight(_ weight: Double) -> String {
        if weight == weight.rounded() {
            return "\(Int(weight)) lb"
        }
        return String(format: "%.1f lb", weight)
    }
}
