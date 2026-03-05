import Foundation
import SwiftData

// MARK: - IdentityEntity Traversal

extension IdentityEntity {
    func trainees(in context: ModelContext) -> [IdentityEntity] {
        let id = self.id
        let joins = (try? context.fetch(FetchDescriptor<TrainerTrainees>(
            predicate: #Predicate { $0.trainerId == id }
        ))) ?? []
        let ids = joins.map(\.traineeId)
        return (try? context.fetch(FetchDescriptor<IdentityEntity>(
            predicate: #Predicate { ids.contains($0.id) }
        ))) ?? []
    }

    func trainer(in context: ModelContext) -> IdentityEntity? {
        let id = self.id
        guard let join = (try? context.fetch(FetchDescriptor<TrainerTrainees>(
            predicate: #Predicate { $0.traineeId == id }
        )))?.first else { return nil }
        let trainerId = join.trainerId
        return (try? context.fetch(FetchDescriptor<IdentityEntity>(
            predicate: #Predicate { $0.id == trainerId }
        )))?.first
    }

    func exercises(in context: ModelContext) -> [ExerciseEntity] {
        let id = self.id
        let joins = (try? context.fetch(FetchDescriptor<TrainerExercises>(
            predicate: #Predicate { $0.trainerId == id }
        ))) ?? []
        let ids = joins.map(\.exerciseId)
        return (try? context.fetch(FetchDescriptor<ExerciseEntity>(
            predicate: #Predicate { ids.contains($0.id) }
        ))) ?? []
    }

    func exerciseCatalog(in context: ModelContext) -> [ExerciseEntity] {
        if isTrainer {
            return exercises(in: context).sorted { $0.name < $1.name }
        }
        return trainer(in: context)?.exercises(in: context).sorted { $0.name < $1.name } ?? []
    }

    func workouts(in context: ModelContext) -> [WorkoutEntity] {
        let aliasIds = Array(IdentityReconciliation.aliasGroup(for: self.id, in: context))
        let joins = (try? context.fetch(FetchDescriptor<IdentityWorkouts>(
            predicate: #Predicate { aliasIds.contains($0.identityId) }
        ))) ?? []
        let ids = joins.map(\.workoutId)
        return (try? context.fetch(FetchDescriptor<WorkoutEntity>(
            predicate: #Predicate { ids.contains($0.id) }
        ))) ?? []
    }

    func activeWorkouts(in context: ModelContext) -> [WorkoutEntity] {
        workouts(in: context).filter { !$0.isCompleted && !$0.isTemplate }
    }

    func completedWorkouts(in context: ModelContext) -> [WorkoutEntity] {
        workouts(in: context)
            .filter { $0.isCompleted && !$0.isTemplate }
            .sorted { $0.date > $1.date }
    }

    func templates(in context: ModelContext) -> [WorkoutEntity] {
        workouts(in: context)
            .filter { $0.isTemplate }
            .sorted { ($0.templateName ?? "") < ($1.templateName ?? "") }
    }

    func exercisesUsed(in context: ModelContext) -> [ExerciseEntity] {
        let sets = workouts(in: context).flatMap { $0.groups(in: context).flatMap { $0.sets(in: context) } }
        let exercisesByID = Dictionary(
            sets.compactMap { $0.exercise(in: context) }.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        return exercisesByID.values.sorted { $0.name < $1.name }
    }

    func lastSet(for exercise: ExerciseEntity, in context: ModelContext) -> SetEntity? {
        completedWorkouts(in: context)
            .flatMap { $0.sortedGroups(in: context).flatMap { $0.sortedSets(in: context) } }
            .first { $0.exercise(in: context)?.id == exercise.id }
    }

    func history(for exercise: ExerciseEntity, in context: ModelContext) -> [(date: Date, set: SetEntity)] {
        completedWorkouts(in: context)
            .reversed()
            .flatMap { workout in
                workout.groups(in: context)
                    .flatMap { $0.sets(in: context) }
                    .filter { $0.exercise(in: context)?.id == exercise.id }
                    .map { (date: workout.date, set: $0) }
            }
    }

    func findOrCreateExercise(named name: String, in context: ModelContext) -> ExerciseEntity {
        let catalog = exercises(in: context)
        if let existing = catalog.first(where: { $0.name.lowercased() == name.lowercased() }) {
            return existing
        }
        let exercise = ExerciseEntity(name: name)
        context.insert(exercise)
        let join = TrainerExercises(trainerId: self.id, exerciseId: exercise.id)
        context.insert(join)
        return exercise
    }
}

// MARK: - WorkoutEntity Traversal

extension WorkoutEntity {
    func owner(in context: ModelContext) -> IdentityEntity? {
        let id = self.id
        guard let join = (try? context.fetch(FetchDescriptor<IdentityWorkouts>(
            predicate: #Predicate { $0.workoutId == id }
        )))?.first else { return nil }
        let identityId = join.identityId
        return (try? context.fetch(FetchDescriptor<IdentityEntity>(
            predicate: #Predicate { $0.id == identityId }
        )))?.first
    }

    func groups(in context: ModelContext) -> [WorkoutGroupEntity] {
        let id = self.id
        let joins = (try? context.fetch(FetchDescriptor<WorkoutGroups>(
            predicate: #Predicate { $0.workoutId == id }
        ))) ?? []
        let ids = joins.map(\.groupId)
        return (try? context.fetch(FetchDescriptor<WorkoutGroupEntity>(
            predicate: #Predicate { ids.contains($0.id) }
        ))) ?? []
    }

    func sortedGroups(in context: ModelContext) -> [WorkoutGroupEntity] {
        groups(in: context).sorted { $0.order < $1.order }
    }

    func nextGroupOrder(in context: ModelContext) -> Int {
        (groups(in: context).map(\.order).max() ?? -1) + 1
    }

    func totalVolume(in context: ModelContext) -> Double {
        groups(in: context).reduce(0) { $0 + $1.totalVolume(in: context) }
    }

    func exerciseCount(in context: ModelContext) -> Int {
        let allSets = groups(in: context).flatMap { $0.sets(in: context) }
        let uniqueIDs = Swift.Set(allSets.compactMap { $0.exercise(in: context)?.id })
        return uniqueIDs.count
    }

    // MARK: - Guided Workout Helpers

    func allSetsFlattened(in context: ModelContext) -> [(group: WorkoutGroupEntity, set: SetEntity)] {
        sortedGroups(in: context).flatMap { group in
            group.sortedSets(in: context).map { (group: group, set: $0) }
        }
    }

    func firstIncompleteSetIndex(in context: ModelContext) -> Int? {
        allSetsFlattened(in: context).firstIndex { !$0.set.isCompleted }
    }

    func nextIncompleteSetIndex(after index: Int, in context: ModelContext) -> Int? {
        let all = allSetsFlattened(in: context)
        // Scan forward from current position
        if let found = all.dropFirst(index + 1).indices.first(where: { !all[$0].set.isCompleted }) {
            return found
        }
        // Wrap around to beginning
        return all.prefix(index).indices.first(where: { !all[$0].set.isCompleted })
    }

    /// Marks this workout as completed. Domain operation — includes sync trigger.
    func markCompleted() {
        isCompleted = true
        SyncTrigger.entityUpdated(.workout, id: id)
    }

    func template(in context: ModelContext) -> WorkoutEntity? {
        let id = self.id
        guard let join = (try? context.fetch(FetchDescriptor<TemplateInstances>(
            predicate: #Predicate { $0.workoutId == id }
        )))?.first else { return nil }
        let templateId = join.templateId
        return (try? context.fetch(FetchDescriptor<WorkoutEntity>(
            predicate: #Predicate { $0.id == templateId }
        )))?.first
    }

    func exerciseNames(in context: ModelContext) -> String {
        let allSets = sortedGroups(in: context).flatMap { $0.sortedSets(in: context) }
        var seen = Swift.Set<UUID>()
        var names: [String] = []
        for set in allSets {
            if let exercise = set.exercise(in: context), seen.insert(exercise.id).inserted {
                names.append(exercise.name)
            }
        }
        return names.joined(separator: ", ")
    }

    func completionProgress(in context: ModelContext) -> Double {
        let all = allSetsFlattened(in: context)
        guard !all.isEmpty else { return 1.0 }
        return Double(all.filter { $0.set.isCompleted }.count) / Double(all.count)
    }
}

// MARK: - WorkoutGroupEntity Traversal

extension WorkoutGroupEntity {
    func workout(in context: ModelContext) -> WorkoutEntity? {
        let id = self.id
        guard let join = (try? context.fetch(FetchDescriptor<WorkoutGroups>(
            predicate: #Predicate { $0.groupId == id }
        )))?.first else { return nil }
        let workoutId = join.workoutId
        return (try? context.fetch(FetchDescriptor<WorkoutEntity>(
            predicate: #Predicate { $0.id == workoutId }
        )))?.first
    }

    func sets(in context: ModelContext) -> [SetEntity] {
        let id = self.id
        let joins = (try? context.fetch(FetchDescriptor<GroupSets>(
            predicate: #Predicate { $0.groupId == id }
        ))) ?? []
        let ids = joins.map(\.setId)
        return (try? context.fetch(FetchDescriptor<SetEntity>(
            predicate: #Predicate { ids.contains($0.id) }
        ))) ?? []
    }

    func sortedSets(in context: ModelContext) -> [SetEntity] {
        sets(in: context).sorted { $0.order < $1.order }
    }

    func nextSetOrder(in context: ModelContext) -> Int {
        (sets(in: context).map(\.order).max() ?? -1) + 1
    }

    func totalVolume(in context: ModelContext) -> Double {
        sets(in: context).reduce(0) { $0 + $1.volume }
    }

    func exerciseName(in context: ModelContext) -> String {
        sortedSets(in: context).first?.exercise(in: context)?.name ?? "Exercise"
    }
}

// MARK: - SetEntity Traversal

extension SetEntity {
    func exercise(in context: ModelContext) -> ExerciseEntity? {
        let id = self.id
        guard let join = (try? context.fetch(FetchDescriptor<ExerciseSets>(
            predicate: #Predicate { $0.setId == id }
        )))?.first else { return nil }
        let exerciseId = join.exerciseId
        return (try? context.fetch(FetchDescriptor<ExerciseEntity>(
            predicate: #Predicate { $0.id == exerciseId }
        )))?.first
    }

    func group(in context: ModelContext) -> WorkoutGroupEntity? {
        let id = self.id
        guard let join = (try? context.fetch(FetchDescriptor<GroupSets>(
            predicate: #Predicate { $0.setId == id }
        )))?.first else { return nil }
        let groupId = join.groupId
        return (try? context.fetch(FetchDescriptor<WorkoutGroupEntity>(
            predicate: #Predicate { $0.id == groupId }
        )))?.first
    }
}
