import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    let identity: IdentityEntity
    @State private var showingAddTrainee = false
    @State private var showingTemplateStart = false
    @State private var selectedTrainee: IdentityEntity?
    @State private var showingSync = false
    @State private var newWorkout: WorkoutEntity?
    @State private var newWorkoutTrainee: IdentityEntity?

    var body: some View {
        let hasTemplates = !identity.templates(in: modelContext).isEmpty
        let trainees = identity.trainees(in: modelContext)
        let traineeIds = trainees.map(\.id)
        let workoutsByIdentity =
            BatchTraversal.workoutsByIdentity(
                identityIds: traineeIds,
                in: modelContext
            )

        let active = trainees.flatMap { trainee in
            (workoutsByIdentity[trainee.id] ?? [])
                .filter {
                    !$0.isCompleted(
                        in: modelContext
                    ) && !$0.isTemplate
                }
                .map {
                    (
                        identity: trainee,
                        workout: $0
                    )
                }
        }.sorted {
            $0.workout.date < $1.workout.date
        }

        let subgraph: WorkoutSubgraph = {
            let activeWorkoutIds = active.map(\.workout.id)
            guard !activeWorkoutIds.isEmpty else {
                return WorkoutSubgraph(
                    groupsByWorkout: [:],
                    setsByGroup: [:],
                    exerciseBySet: [:],
                    completedSetIds: [],
                    completedWorkoutIds: []
                )
            }
            return BatchTraversal.workoutSubgraph(
                workoutIds: activeWorkoutIds,
                in: modelContext
            )
        }()

        List {
            if !active.isEmpty {
                Section {
                    ForEach(active, id: \.workout.id) { pair in
                        NavigationLink {
                            ActiveWorkoutsContainerView(
                                trainer: identity,
                                initialWorkoutId:
                                    pair.workout.id
                            )
                        } label: {
                            ActiveWorkoutRow(
                                identity: pair.identity,
                                workout: pair.workout,
                                exerciseCount: subgraph
                                    .exerciseCount(
                                        for: pair.workout.id
                                    )
                            )
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
                        MascotView(
                            pose: .thinking,
                            color: GymColors.secondaryText
                        )
                            .frame(height: GymMetrics.mascotInline)
                        Text("\(count) Template\(count == 1 ? "" : "s")")
                    }
                }
            } header: {
                Text("Templates")
            }

            Section("Trainees") {
                let sortedTrainees = trainees
                    .sorted(by: { $0.name < $1.name })
                ForEach(sortedTrainees) { trainee in
                    let traineeWorkouts =
                        workoutsByIdentity[
                            trainee.id
                        ] ?? []
                    let completed =
                        traineeWorkouts.filter {
                            $0.isCompleted(
                                in: modelContext
                            ) && !$0.isTemplate
                        }
                    let hasActive =
                        traineeWorkouts.contains {
                            !$0.isCompleted(
                                in: modelContext
                            ) && !$0.isTemplate
                        }
                    NavigationLink {
                        ProfileView(identity: trainee)
                    } label: {
                        TraineeRow(
                            identity: trainee,
                            completedCount: completed.count,
                            hasActiveWorkout: hasActive
                        )
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if !hasActive {
                            Button("Start") { startWorkout(for: trainee) }
                                .tint(GymColors.power)
                            if hasTemplates {
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
                    deleteTrainees(from: sortedTrainees, at: offsets)
                }
            }

            if trainees.isEmpty {
                Section {
                    VStack(spacing: GymMetrics.space16) {
                        AnimatedMascotView(
                            pose: .waving,
                            animation: .pulse,
                            color: GymColors.secondaryText
                        )
                            .frame(height: GymMetrics.mascotMedium)
                        Text("Add your first trainee")
                            .font(GymFont.body)
                            .foregroundStyle(GymColors.secondaryText)
                        Button("Add Trainee") { showingAddTrainee = true }
                            .buttonStyle(.gymPrimary)
                            .padding(.horizontal, GymMetrics.actionPadding)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, GymMetrics.space16)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { showingSync = true } label: {
                    Image(systemName: "person.2.wave.2")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button { showingAddTrainee = true } label: {
                    Image(systemName: "person.badge.plus")
                }
            }
        }
        .sheet(isPresented: $showingAddTrainee) {
            AddTraineeView(trainer: identity)
        }
        .sheet(isPresented: $showingSync) {
            SyncView(identity: identity)
        }
        .sheet(isPresented: $showingTemplateStart) {
            if let trainee = selectedTrainee {
                StartFromTemplateView(
                    trainer: identity,
                    trainee: trainee,
                    onStart: { _ in }
                )
            }
        }
        .navigationDestination(item: $newWorkout) { workout in
            ActiveWorkoutsContainerView(
                trainer: identity,
                initialWorkoutId: workout.id
            )
        }
    }

    // MARK: - Actions

    private func startWorkout(for trainee: IdentityEntity) {
        if let workout = modelContext.startWorkout(for: trainee) {
            newWorkoutTrainee = trainee
            newWorkout = workout
        }
    }

    private func deleteTrainees(
        from sorted: [IdentityEntity],
        at offsets: IndexSet
    ) {
        for index in offsets {
            modelContext.deleteIdentity(sorted[index])
        }
        SyncTrigger.structureChanged()
    }
}

// MARK: - Row Views

private struct ActiveWorkoutRow: View {
    let identity: IdentityEntity
    let workout: WorkoutEntity
    let exerciseCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: GymMetrics.space4) {
            HStack {
                Circle()
                    .fill(GymColors.activeIndicator)
                    .frame(
                        width: GymMetrics.completionDotSize,
                        height: GymMetrics.completionDotSize
                    )
                Text(identity.name)
                    .font(GymFont.heading3)
            }
            Text(timeAgo(workout.date))
                .font(GymFont.caption)
                .foregroundStyle(GymColors.secondaryText)
            if exerciseCount > 0 {
                Text(
                    "\(exerciseCount)"
                        + " exercise\(exerciseCount == 1 ? "" : "s")"
                )
                    .font(GymFont.caption)
                    .foregroundStyle(GymColors.secondaryText)
            }
        }
        .padding(.vertical, GymMetrics.space2)
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
    let identity: IdentityEntity
    let completedCount: Int
    let hasActiveWorkout: Bool

    var body: some View {
        HStack {
            ZStack {
                Circle()
                    .fill(GymColors.steel)
                    .frame(
                        width: GymMetrics.avatarSize,
                        height: GymMetrics.avatarSize
                    )
                Text(String(identity.name.prefix(1)).uppercased())
                    .font(GymFont.bodyStrong)
                    .foregroundStyle(GymColors.chalk)
            }
            VStack(alignment: .leading, spacing: GymMetrics.space2) {
                Text(identity.name)
                    .font(GymFont.body)
                if completedCount > 0 {
                    Text(
                        "\(completedCount)"
                            + " workout\(completedCount == 1 ? "" : "s")"
                    )
                        .font(GymFont.caption)
                        .foregroundStyle(GymColors.secondaryText)
                }
            }
            Spacer()
            if !hasActiveWorkout {
                Text("Start")
                    .gymPill(GymColors.steel)
            } else {
                Text("In Workout")
                    .gymPill(GymColors.power)
            }
        }
    }
}
