import Foundation
import SwiftData

// MARK: - Entities

@Model
final class IdentityEntity {
    var id: UUID
    var name: String
    var isTrainer: Bool

    init(name: String, isTrainer: Bool = false) {
        self.id = UUID()
        self.name = name
        self.isTrainer = isTrainer
    }
}

@Model
final class ExerciseEntity {
    var id: UUID
    var name: String

    init(name: String) {
        self.id = UUID()
        self.name = name
    }
}

@Model
final class WorkoutEntity {
    var id: UUID
    var date: Date
    var notes: String?
    var isComplete: Bool
    var isTemplate: Bool
    var templateName: String?
    var templateId: UUID?

    init(date: Date = .now, isTemplate: Bool = false, templateName: String? = nil) {
        self.id = UUID()
        self.date = date
        self.notes = nil
        self.isComplete = false
        self.isTemplate = isTemplate
        self.templateName = templateName
        self.templateId = nil
    }
}

@Model
final class WorkoutGroupEntity {
    var id: UUID
    var order: Int
    var isSuperset: Bool

    init(order: Int, isSuperset: Bool = false) {
        self.id = UUID()
        self.order = order
        self.isSuperset = isSuperset
    }
}

@Model
final class SetEntity {
    var id: UUID
    var order: Int
    var weight: Double
    var reps: Int
    var isCompleted: Bool
    var completedAt: Date?

    init(order: Int, weight: Double = 0, reps: Int = 0) {
        self.id = UUID()
        self.order = order
        self.weight = weight
        self.reps = reps
        self.isCompleted = false
        self.completedAt = nil
    }

    var volume: Double {
        weight * Double(reps)
    }
}

// MARK: - Join Tables

@Model
final class TrainerTrainees {
    var trainerId: UUID
    var traineeId: UUID

    init(trainerId: UUID, traineeId: UUID) {
        self.trainerId = trainerId
        self.traineeId = traineeId
    }
}

@Model
final class TrainerExercises {
    var trainerId: UUID
    var exerciseId: UUID

    init(trainerId: UUID, exerciseId: UUID) {
        self.trainerId = trainerId
        self.exerciseId = exerciseId
    }
}

@Model
final class IdentityWorkouts {
    var identityId: UUID
    var workoutId: UUID

    init(identityId: UUID, workoutId: UUID) {
        self.identityId = identityId
        self.workoutId = workoutId
    }
}

@Model
final class WorkoutGroups {
    var workoutId: UUID
    var groupId: UUID

    init(workoutId: UUID, groupId: UUID) {
        self.workoutId = workoutId
        self.groupId = groupId
    }
}

@Model
final class GroupSets {
    var groupId: UUID
    var setId: UUID

    init(groupId: UUID, setId: UUID) {
        self.groupId = groupId
        self.setId = setId
    }
}

@Model
final class ExerciseSets {
    var exerciseId: UUID
    var setId: UUID

    init(exerciseId: UUID, setId: UUID) {
        self.exerciseId = exerciseId
        self.setId = setId
    }
}

@Model
final class PairedDevices {
    var localIdentityId: UUID
    var remoteIdentityId: UUID
    var remoteName: String
    var lastSyncDate: Date?

    init(localIdentityId: UUID, remoteIdentityId: UUID, remoteName: String) {
        self.localIdentityId = localIdentityId
        self.remoteIdentityId = remoteIdentityId
        self.remoteName = remoteName
        self.lastSyncDate = nil
    }
}

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
        let id = self.id
        let joins = (try? context.fetch(FetchDescriptor<IdentityWorkouts>(
            predicate: #Predicate { $0.identityId == id }
        ))) ?? []
        let ids = joins.map(\.workoutId)
        return (try? context.fetch(FetchDescriptor<WorkoutEntity>(
            predicate: #Predicate { ids.contains($0.id) }
        ))) ?? []
    }

    func activeWorkouts(in context: ModelContext) -> [WorkoutEntity] {
        workouts(in: context).filter { !$0.isComplete && !$0.isTemplate }
    }

    func completedWorkouts(in context: ModelContext) -> [WorkoutEntity] {
        workouts(in: context)
            .filter { $0.isComplete && !$0.isTemplate }
            .sorted { $0.date > $1.date }
    }

    func templates(in context: ModelContext) -> [WorkoutEntity] {
        workouts(in: context)
            .filter { $0.isTemplate }
            .sorted { ($0.templateName ?? "") < ($1.templateName ?? "") }
    }

    func allExercises(in context: ModelContext) -> [ExerciseEntity] {
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

// MARK: - Template Instantiation

extension ModelContext {
    @discardableResult
    func instantiateTemplate(_ template: WorkoutEntity, for identity: IdentityEntity) -> WorkoutEntity {
        let workout = WorkoutEntity()
        workout.templateId = template.id
        insert(workout)
        insert(IdentityWorkouts(identityId: identity.id, workoutId: workout.id))

        for templateGroup in template.sortedGroups(in: self) {
            let group = WorkoutGroupEntity(order: templateGroup.order, isSuperset: templateGroup.isSuperset)
            insert(group)
            insert(WorkoutGroups(workoutId: workout.id, groupId: group.id))

            for templateSet in templateGroup.sortedSets(in: self) {
                let set = SetEntity(order: templateSet.order, weight: templateSet.weight, reps: templateSet.reps)
                insert(set)
                insert(GroupSets(groupId: group.id, setId: set.id))
                if let exercise = templateSet.exercise(in: self) {
                    insert(ExerciseSets(exerciseId: exercise.id, setId: set.id))
                }
            }
        }
        return workout
    }
}

// MARK: - Cascade Delete Helpers

extension ModelContext {
    func deleteIdentity(_ identity: IdentityEntity) {
        // Delete trainees and their data
        for trainee in identity.trainees(in: self) {
            deleteIdentity(trainee)
        }
        // Delete owned exercises
        for exercise in identity.exercises(in: self) {
            deleteExercise(exercise)
        }
        // Delete workouts
        for workout in identity.workouts(in: self) {
            deleteWorkout(workout)
        }
        // Delete join rows referencing this identity
        let id = identity.id
        if let joins = try? fetch(FetchDescriptor<TrainerTrainees>(
            predicate: #Predicate { $0.trainerId == id || $0.traineeId == id }
        )) { joins.forEach { delete($0) } }
        if let joins = try? fetch(FetchDescriptor<IdentityWorkouts>(
            predicate: #Predicate { $0.identityId == id }
        )) { joins.forEach { delete($0) } }
        delete(identity)
    }

    func deleteExercise(_ exercise: ExerciseEntity) {
        let id = exercise.id
        // Nullify: remove ExerciseSets join rows but leave sets
        if let joins = try? fetch(FetchDescriptor<ExerciseSets>(
            predicate: #Predicate { $0.exerciseId == id }
        )) { joins.forEach { delete($0) } }
        if let joins = try? fetch(FetchDescriptor<TrainerExercises>(
            predicate: #Predicate { $0.exerciseId == id }
        )) { joins.forEach { delete($0) } }
        delete(exercise)
    }

    func deleteWorkout(_ workout: WorkoutEntity) {
        for group in workout.groups(in: self) {
            deleteGroup(group)
        }
        let id = workout.id
        if let joins = try? fetch(FetchDescriptor<IdentityWorkouts>(
            predicate: #Predicate { $0.workoutId == id }
        )) { joins.forEach { delete($0) } }
        if let joins = try? fetch(FetchDescriptor<WorkoutGroups>(
            predicate: #Predicate { $0.workoutId == id }
        )) { joins.forEach { delete($0) } }
        delete(workout)
    }

    func deleteGroup(_ group: WorkoutGroupEntity) {
        for set in group.sets(in: self) {
            deleteSet(set)
        }
        let id = group.id
        if let joins = try? fetch(FetchDescriptor<WorkoutGroups>(
            predicate: #Predicate { $0.groupId == id }
        )) { joins.forEach { delete($0) } }
        if let joins = try? fetch(FetchDescriptor<GroupSets>(
            predicate: #Predicate { $0.groupId == id }
        )) { joins.forEach { delete($0) } }
        delete(group)
    }

    func deleteSet(_ set: SetEntity) {
        let id = set.id
        if let joins = try? fetch(FetchDescriptor<GroupSets>(
            predicate: #Predicate { $0.setId == id }
        )) { joins.forEach { delete($0) } }
        if let joins = try? fetch(FetchDescriptor<ExerciseSets>(
            predicate: #Predicate { $0.setId == id }
        )) { joins.forEach { delete($0) } }
        delete(set)
    }
}
