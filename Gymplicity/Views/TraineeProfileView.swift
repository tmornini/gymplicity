import SwiftUI
import SwiftData

struct TraineeProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var trainee: Trainee
    @State private var showingEditName = false
    @State private var editedName = ""

    var body: some View {
        List {
            // Active session quick-access
            if !trainee.activeSessions.isEmpty {
                Section("Active Session") {
                    ForEach(trainee.activeSessions) { session in
                        NavigationLink {
                            ActiveSessionView(session: session)
                        } label: {
                            HStack {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.green)
                                Text(session.date, style: .date)
                                Spacer()
                                Text("\(session.exerciseCount) ex")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            // Start new session
            Section {
                Button {
                    startSession()
                } label: {
                    Label("Start New Session", systemImage: "plus.circle.fill")
                        .fontWeight(.medium)
                }
            }

            // Recent sessions
            if !trainee.completedSessions.isEmpty {
                Section("Recent Sessions") {
                    ForEach(trainee.completedSessions.prefix(20)) { session in
                        NavigationLink {
                            SessionHistoryView(session: session)
                        } label: {
                            SessionRow(session: session)
                        }
                    }
                }
            }

            // Progress by exercise
            let exercises = trainee.allExercises
            if !exercises.isEmpty {
                Section("Progress by Exercise") {
                    ForEach(exercises) { exercise in
                        NavigationLink {
                            ProgressChartsView(trainee: trainee, exercise: exercise)
                        } label: {
                            HStack {
                                Text(exercise.name)
                                Spacer()
                                if let lastEntry = trainee.lastEntry(for: exercise),
                                   let lastSet = lastEntry.sortedSets.first {
                                    Text("\(formatWeight(lastSet.weight)) x \(lastSet.reps)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(trainee.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") {
                    editedName = trainee.name
                    showingEditName = true
                }
            }
        }
        .alert("Edit Name", isPresented: $showingEditName) {
            TextField("Name", text: $editedName)
            Button("Save") {
                let trimmed = editedName.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty { trainee.name = trimmed }
            }
            Button("Cancel", role: .cancel) { }
        }
    }

    private func startSession() {
        let session = Session(trainee: trainee)
        modelContext.insert(session)
    }

    private func formatWeight(_ weight: Double) -> String {
        if weight == weight.rounded() {
            return "\(Int(weight)) lb"
        }
        return String(format: "%.1f lb", weight)
    }
}

private struct SessionRow: View {
    let session: Session

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(session.date, style: .date)
                    .font(.body)
                Spacer()
                Text("\(session.exerciseCount) exercise\(session.exerciseCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if session.totalVolume > 0 {
                Text("Total volume: \(formatVolume(session.totalVolume)) lb")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            let exerciseNames = session.sortedEntries.map { $0.exercise?.name ?? "Unknown" }.joined(separator: ", ")
            if !exerciseNames.isEmpty {
                Text(exerciseNames)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }

    private func formatVolume(_ volume: Double) -> String {
        if volume >= 1000 {
            return String(format: "%.0f", volume)
        }
        return String(format: "%.0f", volume)
    }
}
