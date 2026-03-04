import Foundation
import SwiftData
import XCTest
@testable import Gymplicity

func makeTestContext() throws -> ModelContext {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
        for: IdentityEntity.self, ExerciseEntity.self, WorkoutEntity.self,
        WorkoutGroupEntity.self, SetEntity.self, TrainerTrainees.self,
        TrainerExercises.self, IdentityWorkouts.self, WorkoutGroups.self,
        GroupSets.self, ExerciseSets.self, TemplateInstances.self, PairedDevices.self,
        configurations: config
    )
    return ModelContext(container)
}

// MARK: - Factory Methods

extension ModelContext {
    @discardableResult
    func makeTrainer(name: String = "Trainer") -> IdentityEntity {
        let trainer = IdentityEntity(name: name, isTrainer: true)
        insert(trainer)
        return trainer
    }

    @discardableResult
    func makeTrainee(name: String = "Trainee", trainer: IdentityEntity) -> IdentityEntity {
        let trainee = IdentityEntity(name: name, isTrainer: false)
        insert(trainee)
        insert(TrainerTrainees(trainerId: trainer.id, traineeId: trainee.id))
        return trainee
    }

    @discardableResult
    func makeExercise(name: String, trainer: IdentityEntity) -> ExerciseEntity {
        let exercise = ExerciseEntity(name: name)
        insert(exercise)
        insert(TrainerExercises(trainerId: trainer.id, exerciseId: exercise.id))
        return exercise
    }

    @discardableResult
    func makeWorkout(for identity: IdentityEntity, date: Date = .now, isCompleted: Bool = false) -> WorkoutEntity {
        let workout = WorkoutEntity(date: date)
        workout.isCompleted = isCompleted
        insert(workout)
        insert(IdentityWorkouts(identityId: identity.id, workoutId: workout.id))
        return workout
    }

    @discardableResult
    func makeGroup(in workout: WorkoutEntity, order: Int, isSuperset: Bool = false) -> WorkoutGroupEntity {
        let group = WorkoutGroupEntity(order: order, isSuperset: isSuperset)
        insert(group)
        insert(WorkoutGroups(workoutId: workout.id, groupId: group.id))
        return group
    }

    @discardableResult
    func makeTemplate(name: String, for trainer: IdentityEntity) -> WorkoutEntity {
        let template = WorkoutEntity(isTemplate: true, templateName: name)
        insert(template)
        insert(IdentityWorkouts(identityId: trainer.id, workoutId: template.id))
        return template
    }

    @discardableResult
    func makeSet(
        in group: WorkoutGroupEntity,
        exercise: ExerciseEntity,
        order: Int,
        weight: Double,
        reps: Int,
        isCompleted: Bool = false,
        completedAt: Date? = nil
    ) -> SetEntity {
        let set = SetEntity(order: order, weight: weight, reps: reps)
        set.isCompleted = isCompleted
        set.completedAt = completedAt
        insert(set)
        insert(GroupSets(groupId: group.id, setId: set.id))
        insert(ExerciseSets(exerciseId: exercise.id, setId: set.id))
        return set
    }
}

// MARK: - Payload Factory

func makePayload(
    senderIdentityId: UUID,
    identities: [IdentityDTO] = [],
    exercises: [ExerciseDTO] = [],
    workouts: [WorkoutDTO] = [],
    workoutGroups: [WorkoutGroupDTO] = [],
    sets: [SetDTO] = [],
    trainerTrainees: [TrainerTraineesDTO] = [],
    trainerExercises: [TrainerExercisesDTO] = [],
    identityWorkouts: [IdentityWorkoutsDTO] = [],
    workoutGroupJoins: [WorkoutGroupsDTO] = [],
    groupSetJoins: [GroupSetsDTO] = [],
    exerciseSetJoins: [ExerciseSetsDTO] = [],
    templateInstanceJoins: [TemplateInstancesDTO] = []
) -> SyncPayload {
    SyncPayload(
        version: 1,
        senderIdentityId: senderIdentityId,
        identities: identities,
        exercises: exercises,
        workouts: workouts,
        workoutGroups: workoutGroups,
        sets: sets,
        trainerTrainees: trainerTrainees,
        trainerExercises: trainerExercises,
        identityWorkouts: identityWorkouts,
        workoutGroupJoins: workoutGroupJoins,
        groupSetJoins: groupSetJoins,
        exerciseSetJoins: exerciseSetJoins,
        templateInstanceJoins: templateInstanceJoins
    )
}
