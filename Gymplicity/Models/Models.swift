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

    init(date: Date = .now) {
        self.id = UUID()
        self.date = date
        self.notes = nil
        self.isComplete = false
    }
}

@Model
final class SupersetEntity {
    var id: UUID
    var order: Int

    init(order: Int) {
        self.id = UUID()
        self.order = order
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
final class WorkoutSupersets {
    var workoutId: UUID
    var supersetId: UUID

    init(workoutId: UUID, supersetId: UUID) {
        self.workoutId = workoutId
        self.supersetId = supersetId
    }
}

@Model
final class SupersetSets {
    var supersetId: UUID
    var setId: UUID

    init(supersetId: UUID, setId: UUID) {
        self.supersetId = supersetId
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
        workouts(in: context).filter { !$0.isComplete }
    }

    func completedWorkouts(in context: ModelContext) -> [WorkoutEntity] {
        workouts(in: context)
            .filter { $0.isComplete }
            .sorted { $0.date > $1.date }
    }

    func allExercises(in context: ModelContext) -> [ExerciseEntity] {
        let sets = workouts(in: context).flatMap { $0.supersets(in: context).flatMap { $0.sets(in: context) } }
        let exercisesByID = Dictionary(
            sets.compactMap { $0.exercise(in: context) }.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        return exercisesByID.values.sorted { $0.name < $1.name }
    }

    func lastSet(for exercise: ExerciseEntity, in context: ModelContext) -> SetEntity? {
        completedWorkouts(in: context)
            .flatMap { $0.sortedSupersets(in: context).flatMap { $0.sortedSets(in: context) } }
            .first { $0.exercise(in: context)?.id == exercise.id }
    }

    func history(for exercise: ExerciseEntity, in context: ModelContext) -> [(date: Date, set: SetEntity)] {
        completedWorkouts(in: context)
            .reversed()
            .flatMap { workout in
                workout.supersets(in: context)
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

    func supersets(in context: ModelContext) -> [SupersetEntity] {
        let id = self.id
        let joins = (try? context.fetch(FetchDescriptor<WorkoutSupersets>(
            predicate: #Predicate { $0.workoutId == id }
        ))) ?? []
        let ids = joins.map(\.supersetId)
        return (try? context.fetch(FetchDescriptor<SupersetEntity>(
            predicate: #Predicate { ids.contains($0.id) }
        ))) ?? []
    }

    func sortedSupersets(in context: ModelContext) -> [SupersetEntity] {
        supersets(in: context).sorted { $0.order < $1.order }
    }

    func nextSupersetOrder(in context: ModelContext) -> Int {
        (supersets(in: context).map(\.order).max() ?? -1) + 1
    }

    func totalVolume(in context: ModelContext) -> Double {
        supersets(in: context).reduce(0) { $0 + $1.totalVolume(in: context) }
    }

    func exerciseCount(in context: ModelContext) -> Int {
        let allSets = supersets(in: context).flatMap { $0.sets(in: context) }
        let uniqueIDs = Swift.Set(allSets.compactMap { $0.exercise(in: context)?.id })
        return uniqueIDs.count
    }
}

// MARK: - SupersetEntity Traversal

extension SupersetEntity {
    func workout(in context: ModelContext) -> WorkoutEntity? {
        let id = self.id
        guard let join = (try? context.fetch(FetchDescriptor<WorkoutSupersets>(
            predicate: #Predicate { $0.supersetId == id }
        )))?.first else { return nil }
        let workoutId = join.workoutId
        return (try? context.fetch(FetchDescriptor<WorkoutEntity>(
            predicate: #Predicate { $0.id == workoutId }
        )))?.first
    }

    func sets(in context: ModelContext) -> [SetEntity] {
        let id = self.id
        let joins = (try? context.fetch(FetchDescriptor<SupersetSets>(
            predicate: #Predicate { $0.supersetId == id }
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

    func superset(in context: ModelContext) -> SupersetEntity? {
        let id = self.id
        guard let join = (try? context.fetch(FetchDescriptor<SupersetSets>(
            predicate: #Predicate { $0.setId == id }
        )))?.first else { return nil }
        let supersetId = join.supersetId
        return (try? context.fetch(FetchDescriptor<SupersetEntity>(
            predicate: #Predicate { $0.id == supersetId }
        )))?.first
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
        for superset in workout.supersets(in: self) {
            deleteSuperset(superset)
        }
        let id = workout.id
        if let joins = try? fetch(FetchDescriptor<IdentityWorkouts>(
            predicate: #Predicate { $0.workoutId == id }
        )) { joins.forEach { delete($0) } }
        if let joins = try? fetch(FetchDescriptor<WorkoutSupersets>(
            predicate: #Predicate { $0.workoutId == id }
        )) { joins.forEach { delete($0) } }
        delete(workout)
    }

    func deleteSuperset(_ superset: SupersetEntity) {
        for set in superset.sets(in: self) {
            deleteSet(set)
        }
        let id = superset.id
        if let joins = try? fetch(FetchDescriptor<WorkoutSupersets>(
            predicate: #Predicate { $0.supersetId == id }
        )) { joins.forEach { delete($0) } }
        if let joins = try? fetch(FetchDescriptor<SupersetSets>(
            predicate: #Predicate { $0.supersetId == id }
        )) { joins.forEach { delete($0) } }
        delete(superset)
    }

    func deleteSet(_ set: SetEntity) {
        let id = set.id
        if let joins = try? fetch(FetchDescriptor<SupersetSets>(
            predicate: #Predicate { $0.setId == id }
        )) { joins.forEach { delete($0) } }
        if let joins = try? fetch(FetchDescriptor<ExerciseSets>(
            predicate: #Predicate { $0.setId == id }
        )) { joins.forEach { delete($0) } }
        delete(set)
    }
}
