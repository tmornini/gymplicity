import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    let identity: IdentityEntity
    @State private var showingAddTrainee = false
    @State private var showingTemplateStart = false
    @State private var selectedTrainee: IdentityEntity?
    @State private var showingSync = false

    var body: some View {
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
                        AnimatedMascotView(pose: .waving, animation: .pulse, color: GymColors.secondaryText)
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
                StartFromTemplateView(trainer: identity, trainee: trainee)
            }
        }
    }

    // MARK: - Actions

    private func startWorkout(for identity: IdentityEntity) {
        modelContext.startWorkout(for: identity)
    }

    private func deleteTrainees(from sorted: [IdentityEntity], at offsets: IndexSet) {
        for index in offsets {
            modelContext.deleteIdentity(sorted[index])
        }
        SyncTrigger.structureChanged()
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
                Text("Start")
                    .gymPill(GymColors.steel)
            } else {
                Text("In Workout")
                    .gymPill(GymColors.power)
            }
        }
    }
}
