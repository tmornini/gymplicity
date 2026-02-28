import SwiftUI
import SwiftData

struct TrainerHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var trainers: [Trainer]
    @State private var showingAddTrainee = false

    private var trainer: Trainer? { trainers.first }

    var body: some View {
        NavigationStack {
            Group {
                if let trainer {
                    traineeList(trainer: trainer)
                } else {
                    ContentUnavailableView("Welcome to Gymplicity", systemImage: "figure.strengthtraining.traditional") {
                        Button("Get Started") { createDefaultTrainer() }
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
            .navigationTitle("Gymplicity")
            .toolbar {
                if trainer != nil {
                    ToolbarItem(placement: .primaryAction) {
                        Button { showingAddTrainee = true } label: {
                            Image(systemName: "person.badge.plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddTrainee) {
                AddTraineeView(trainer: trainer!)
            }
        }
    }

    @ViewBuilder
    private func traineeList(trainer: Trainer) -> some View {
        List {
            let active = trainer.trainees
                .flatMap { $0.activeWorkouts.map { (trainee: $0.trainee!, workout: $0) } }
            if !active.isEmpty {
                Section("Active Workouts") {
                    ForEach(active, id: \.workout.id) { pair in
                        NavigationLink {
                            ActiveWorkoutView(workout: pair.workout)
                        } label: {
                            ActiveWorkoutRow(trainee: pair.trainee, workout: pair.workout)
                        }
                    }
                }
            }

            Section("Trainees") {
                ForEach(trainer.trainees.sorted(by: { $0.name < $1.name })) { trainee in
                    NavigationLink {
                        TraineeProfileView(trainee: trainee)
                    } label: {
                        TraineeRow(trainee: trainee)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if trainee.activeWorkouts.isEmpty {
                            Button("Start Workout") { startWorkout(for: trainee) }
                                .tint(.green)
                        }
                    }
                }
                .onDelete { offsets in
                    deleteTrainees(trainer: trainer, at: offsets)
                }
            }

            if trainer.trainees.isEmpty {
                ContentUnavailableView("No Trainees Yet", systemImage: "person.2") {
                    Button("Add Trainee") { showingAddTrainee = true }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    private func createDefaultTrainer() {
        let trainer = Trainer(name: "Trainer")
        modelContext.insert(trainer)
    }

    private func startWorkout(for trainee: Trainee) {
        let workout = Workout(trainee: trainee)
        modelContext.insert(workout)
    }

    private func deleteTrainees(trainer: Trainer, at offsets: IndexSet) {
        let sorted = trainer.trainees.sorted { $0.name < $1.name }
        for index in offsets {
            modelContext.delete(sorted[index])
        }
    }
}

// MARK: - Row Views

private struct ActiveWorkoutRow: View {
    let trainee: Trainee
    let workout: Workout

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "circle.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.green)
                Text(trainee.name)
                    .font(.headline)
            }
            Text(timeAgo(workout.date))
                .font(.caption)
                .foregroundStyle(.secondary)
            if workout.exerciseCount > 0 {
                Text("\(workout.exerciseCount) exercise\(workout.exerciseCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private func timeAgo(_ date: Date) -> String {
        let minutes = Int(-date.timeIntervalSinceNow / 60)
        if minutes < 1 { return "Just started" }
        if minutes < 60 { return "Started \(minutes) min ago" }
        let hours = minutes / 60
        return "Started \(hours) hr \(minutes % 60) min ago"
    }
}

private struct TraineeRow: View {
    let trainee: Trainee

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(trainee.name)
                    .font(.body)
                if !trainee.completedWorkouts.isEmpty {
                    Text("\(trainee.completedWorkouts.count) workout\(trainee.completedWorkouts.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if trainee.activeWorkouts.isEmpty {
                Button("Start") { }
                    .buttonStyle(.bordered)
                    .font(.caption)
                    .allowsHitTesting(false) // handled by swipe action
            } else {
                Text("In Workout")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
    }
}
