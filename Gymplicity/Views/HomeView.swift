import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var identities: [IdentityEntity]
    @EnvironmentObject private var syncManager: SyncSessionManager
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
                    welcomeView
                }
            }
            .navigationTitle("Gymplicity")
            .toolbar {
                if let identity = currentIdentity {
                    ToolbarItem(placement: .topBarLeading) {
                        SyncStatusButton(syncManager: syncManager, identity: identity)
                    }
                    if identity.isTrainer {
                        ToolbarItem(placement: .primaryAction) {
                            Button { showingAddTrainee = true } label: {
                                Image(systemName: "person.badge.plus")
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddTrainee) {
                if let identity = currentIdentity {
                    AddTraineeView(trainer: identity)
                }
            }
            .onChange(of: currentIdentity?.id) { _, newId in
                if newId != nil {
                    syncManager.startAutoSync(container: modelContext.container)
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

    // MARK: - Welcome View

    private var welcomeView: some View {
        VStack(spacing: GymMetrics.space24) {
            Spacer()
            AnimatedMascotView(pose: .waving, animation: .wave, color: GymColors.energy)
                .frame(height: GymMetrics.mascotLarge)
            Text("Welcome to Gymplicity")
                .font(GymFont.heading1)
            Text("Train smarter. Track everything.")
                .font(GymFont.body)
                .foregroundStyle(GymColors.secondaryText)
            Button("Get Started") { showingSetup = true }
                .buttonStyle(.gymPrimary)
                .padding(.horizontal, 40)
            Spacer()
        }
        .padding()
    }

    // MARK: - Trainer Layout

    @ViewBuilder
    private func trainerView(identity: IdentityEntity) -> some View {
        let trainees = identity.trainees(in: modelContext)
        let active = trainees.flatMap { trainee in
            trainee.activeWorkouts(in: modelContext).map { (identity: trainee, workout: $0) }
        }.sorted { $0.workout.date < $1.workout.date }
        List {
            if !active.isEmpty {
                Section {
                    ForEach(active, id: \.workout.id) { pair in
                        NavigationLink {
                            ActiveWorkoutsContainerView(trainer: identity, initialWorkoutId: pair.workout.id)
                        } label: {
                            ActiveWorkoutRow(identity: pair.identity, workout: pair.workout)
                        }
                    }
                } header: {
                    HStack(spacing: GymMetrics.space4) {
                        MascotView(pose: .curling, color: GymColors.energy)
                            .frame(height: GymMetrics.mascotInline)
                        Text("Active Workouts")
                    }
                }
            }

            Section {
                NavigationLink {
                    TemplateListView(trainer: identity)
                } label: {
                    let count = identity.templates(in: modelContext).count
                    HStack(spacing: GymMetrics.space4) {
                        MascotView(pose: .thinking, color: GymColors.secondaryText)
                            .frame(height: GymMetrics.mascotInline)
                        Text("\(count) Template\(count == 1 ? "" : "s")")
                    }
                }
            } header: {
                Text("Templates")
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
                                .tint(GymColors.power)
                            if !identity.templates(in: modelContext).isEmpty {
                                Button("Template") {
                                    selectedTrainee = trainee
                                    showingTemplateStart = true
                                }
                                .tint(GymColors.focus)
                            }
                        }
                    }
                }
                .onDelete { offsets in
                    deleteTrainees(from: trainees.sorted(by: { $0.name < $1.name }), at: offsets)
                }
            }

            if trainees.isEmpty {
                Section {
                    VStack(spacing: GymMetrics.space16) {
                        AnimatedMascotView(pose: .spotting, animation: .pulse, color: GymColors.secondaryText)
                            .frame(height: GymMetrics.mascotMedium)
                        Text("Add your first trainee")
                            .font(GymFont.body)
                            .foregroundStyle(GymColors.secondaryText)
                        Button("Add Trainee") { showingAddTrainee = true }
                            .buttonStyle(.gymPrimary)
                            .padding(.horizontal, 40)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, GymMetrics.space16)
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
        guard identity.activeWorkouts(in: modelContext).isEmpty else { return }
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
                Circle()
                    .fill(GymColors.activeIndicator)
                    .frame(width: GymMetrics.completionDotSize, height: GymMetrics.completionDotSize)
                Text(identity.name)
                    .font(GymFont.heading3)
            }
            Text(timeAgo(workout.date))
                .font(GymFont.caption)
                .foregroundStyle(GymColors.secondaryText)
            let count = workout.exerciseCount(in: modelContext)
            if count > 0 {
                Text("\(count) exercise\(count == 1 ? "" : "s")")
                    .font(GymFont.caption)
                    .foregroundStyle(GymColors.secondaryText)
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
            ZStack {
                Circle()
                    .fill(GymColors.steel)
                    .frame(width: GymMetrics.avatarSize, height: GymMetrics.avatarSize)
                Text(String(identity.name.prefix(1)).uppercased())
                    .font(GymFont.bodyStrong)
                    .foregroundStyle(GymColors.chalk)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(identity.name)
                    .font(GymFont.body)
                if !completed.isEmpty {
                    Text("\(completed.count) workout\(completed.count == 1 ? "" : "s")")
                        .font(GymFont.caption)
                        .foregroundStyle(GymColors.secondaryText)
                }
            }
            Spacer()
            if active.isEmpty {
                Button("Start") { }
                    .buttonStyle(.bordered)
                    .font(GymFont.caption)
                    .allowsHitTesting(false)
            } else {
                Text("In Workout")
                    .gymPill(GymColors.power)
            }
        }
    }
}
