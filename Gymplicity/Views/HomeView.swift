import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var identities: [IdentityEntity]
    @State private var showingAddTrainee = false
    @State private var showingSetup = false
    @State private var setupName = ""
    @State private var showingTemplateStart = false
    @State private var selectedTrainee: IdentityEntity?

    private var currentIdentity: IdentityEntity? { identities.first }

    var body: some View {
        NavigationStack {
            Group {
                if let identity = currentIdentity {
                    if identity.isTrainer {
                        trainerView(identity: identity)
                    } else {
                        ProfileView(identity: identity)
                    }
                } else {
                    ContentUnavailableView {
                        Label("Welcome to Gymplicity", systemImage: "figure.strengthtraining.traditional")
                    } actions: {
                        Button("Get Started") { showingSetup = true }
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
            .navigationTitle("Gymplicity")
            .toolbar {
                if let identity = currentIdentity, identity.isTrainer {
                    ToolbarItem(placement: .primaryAction) {
                        Button { showingAddTrainee = true } label: {
                            Image(systemName: "person.badge.plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddTrainee) {
                if let identity = currentIdentity {
                    AddTraineeView(trainer: identity)
                }
            }
            .alert("Set Up Your Profile", isPresented: $showingSetup) {
                TextField("Your Name", text: $setupName)
                Button("I'm a Trainer") { createIdentity(isTrainer: true) }
                Button("I'm a Trainee") { createIdentity(isTrainer: false) }
                Button("Cancel", role: .cancel) { }
            }
        }
    }

    // MARK: - Trainer Layout

    @ViewBuilder
    private func trainerView(identity: IdentityEntity) -> some View {
        let trainees = identity.trainees(in: modelContext)
        let active = trainees.flatMap { trainee in
            trainee.activeWorkouts(in: modelContext).map { (identity: trainee, workout: $0) }
        }
        List {
            if !active.isEmpty {
                Section("Active Workouts") {
                    ForEach(active, id: \.workout.id) { pair in
                        NavigationLink {
                            ActiveWorkoutView(workout: pair.workout)
                        } label: {
                            ActiveWorkoutRow(identity: pair.identity, workout: pair.workout)
                        }
                    }
                }
            }

            Section("Templates") {
                NavigationLink {
                    TemplateListView(trainer: identity)
                } label: {
                    let count = identity.templates(in: modelContext).count
                    Label("\(count) Template\(count == 1 ? "" : "s")", systemImage: "doc.text")
                }
            }

            Section("Trainees") {
                ForEach(trainees.sorted(by: { $0.name < $1.name })) { trainee in
                    NavigationLink {
                        ProfileView(identity: trainee)
                    } label: {
                        TraineeRow(identity: trainee)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if trainee.activeWorkouts(in: modelContext).isEmpty {
                            Button("Start") { startWorkout(for: trainee) }
                                .tint(.green)
                            if !identity.templates(in: modelContext).isEmpty {
                                Button("Template") {
                                    selectedTrainee = trainee
                                    showingTemplateStart = true
                                }
                                .tint(.blue)
                            }
                        }
                    }
                }
                .onDelete { offsets in
                    deleteTrainees(from: trainees.sorted(by: { $0.name < $1.name }), at: offsets)
                }
            }

            if trainees.isEmpty {
                ContentUnavailableView {
                    Label("No Trainees Yet", systemImage: "person.2")
                } actions: {
                    Button("Add Trainee") { showingAddTrainee = true }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .sheet(isPresented: $showingTemplateStart) {
            if let trainee = selectedTrainee {
                StartFromTemplateView(trainer: identity, trainee: trainee)
            }
        }
    }

    // MARK: - Actions

    private func createIdentity(isTrainer: Bool) {
        let trimmed = setupName.trimmingCharacters(in: .whitespaces)
        let name = trimmed.isEmpty ? (isTrainer ? "Trainer" : "Trainee") : trimmed
        let identity = IdentityEntity(name: name, isTrainer: isTrainer)
        modelContext.insert(identity)
    }

    private func startWorkout(for identity: IdentityEntity) {
        let workout = WorkoutEntity()
        modelContext.insert(workout)
        let join = IdentityWorkouts(identityId: identity.id, workoutId: workout.id)
        modelContext.insert(join)
    }

    private func deleteTrainees(from sorted: [IdentityEntity], at offsets: IndexSet) {
        for index in offsets {
            modelContext.deleteIdentity(sorted[index])
        }
    }
}

// MARK: - Row Views

private struct ActiveWorkoutRow: View {
    @Environment(\.modelContext) private var modelContext
    let identity: IdentityEntity
    let workout: WorkoutEntity

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "circle.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.green)
                Text(identity.name)
                    .font(.headline)
            }
            Text(timeAgo(workout.date))
                .font(.caption)
                .foregroundStyle(.secondary)
            let count = workout.exerciseCount(in: modelContext)
            if count > 0 {
                Text("\(count) exercise\(count == 1 ? "" : "s")")
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
    @Environment(\.modelContext) private var modelContext
    let identity: IdentityEntity

    var body: some View {
        let completed = identity.completedWorkouts(in: modelContext)
        let active = identity.activeWorkouts(in: modelContext)
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(identity.name)
                    .font(.body)
                if !completed.isEmpty {
                    Text("\(completed.count) workout\(completed.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if active.isEmpty {
                Button("Start") { }
                    .buttonStyle(.bordered)
                    .font(.caption)
                    .allowsHitTesting(false)
            } else {
                Text("In Workout")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
    }
}
