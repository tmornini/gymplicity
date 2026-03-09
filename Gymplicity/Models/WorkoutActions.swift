import Foundation
import SwiftData

// MARK: - Domain Operations

extension ModelContext {
    /// Adds a set to a group, seeding weight/reps from the owner's last set for this exercise.
    /// Data operation — does NOT trigger sync; caller owns sync timing.
    @MainActor @discardableResult
    func addSet(to group: WorkoutGroupEntity, exercise: ExerciseEntity, seedingFrom owner: IdentityEntity?) -> SetEntity {
        var weight: Double = 0
        var reps: Int = 0
        if let owner, let lastSet = owner.lastSet(for: exercise, in: self) {
            weight = lastSet.weight
            reps = lastSet.reps
        }
        let set = SetEntity(order: group.nextSetOrder(in: self), weight: weight, reps: reps)
        insert(set)
        insert(GroupSets(groupId: group.id, setId: set.id))
        insert(ExerciseSets(exerciseId: exercise.id, setId: set.id))
        return set
    }

    /// Deletes sets from a group at the given offsets.
    /// Data operation — does NOT trigger sync; caller owns sync timing.
    @MainActor func deleteSets(from group: WorkoutGroupEntity, at offsets: IndexSet) {
        let sorted = group.sortedSets(in: self)
        for index in offsets {
            deleteSet(sorted[index])
        }
    }

    /// Starts a new workout for the given identity if none is already active.
    /// Domain operation — includes sync trigger.
    @MainActor @discardableResult
    func startWorkout(for identity: IdentityEntity) -> WorkoutEntity? {
        guard identity.activeWorkouts(in: self).isEmpty else { return nil }
        let workout = WorkoutEntity()
        insert(workout)
        insert(IdentityWorkouts(identityId: identity.id, workoutId: workout.id))
        SyncTrigger.structureChanged()
        return workout
    }
}

// MARK: - Template Instantiation

extension ModelContext {
    @MainActor @discardableResult
    func instantiateTemplate(_ template: WorkoutEntity, for identity: IdentityEntity) -> WorkoutEntity {
        let workout = WorkoutEntity()
        insert(workout)
        insert(IdentityWorkouts(identityId: identity.id, workoutId: workout.id))
        insert(TemplateInstances(templateId: template.id, workoutId: workout.id))

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
    @MainActor func deleteIdentity(_ identity: IdentityEntity) {
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

    @MainActor func deleteExercise(_ exercise: ExerciseEntity) {
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

    @MainActor func deleteWorkout(_ workout: WorkoutEntity) {
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
        if let joins = try? fetch(FetchDescriptor<TemplateInstances>(
            predicate: #Predicate { $0.templateId == id || $0.workoutId == id }
        )) { joins.forEach { delete($0) } }
        delete(workout)
    }

    @MainActor func deleteGroup(_ group: WorkoutGroupEntity) {
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

    @MainActor func deleteSet(_ set: SetEntity) {
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
