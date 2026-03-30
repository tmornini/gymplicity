import Foundation
import SwiftData
import XCTest
@testable import Gymplicity

@MainActor func makeTestContext() throws -> ModelContext {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
        for: IdentityEntity.self, ExerciseEntity.self, WorkoutEntity.self,
        WorkoutGroupEntity.self, SetEntity.self, TrainerTrainees.self,
        TrainerExercises.self, IdentityWorkouts.self, WorkoutGroups.self,
        GroupSets.self, ExerciseSets.self, TemplateInstances.self,
        IdentityAliases.self, WorkoutTemplate.self, WorkoutNotes.self,
        PairedDevices.self,
        SetCompletions.self, WorkoutCompletions.self,
        DeviceSyncEvents.self,
        configurations: config
    )
    return ModelContext(container)
}

// MARK: - Factory Methods

extension ModelContext {
    @MainActor @discardableResult
    func makeTrainer(name: String = "Trainer") -> IdentityEntity {
        let trainer = IdentityEntity(name: name, isTrainer: true)
        insert(trainer)
        return trainer
    }

    @MainActor @discardableResult
    func makeTrainee(
        name: String = "Trainee",
        trainer: IdentityEntity
    ) -> IdentityEntity {
        let trainee = IdentityEntity(name: name, isTrainer: false)
        insert(trainee)
        insert(TrainerTrainees(trainerId: trainer.id, traineeId: trainee.id))
        return trainee
    }

    @MainActor @discardableResult
    func makeExercise(
        name: String,
        trainer: IdentityEntity
    ) -> ExerciseEntity {
        let exercise = ExerciseEntity(
            name: name,
            catalogId: nil
        )
        insert(exercise)
        insert(TrainerExercises(
            trainerId: trainer.id,
            exerciseId: exercise.id
        ))
        return exercise
    }

    @MainActor @discardableResult
    func makeWorkout(
        for identity: IdentityEntity,
        date: Date = .now,
        isCompleted: Bool = false
    ) -> WorkoutEntity {
        let workout = WorkoutEntity(date: date, isTemplate: false)
        insert(workout)
        insert(IdentityWorkouts(
            identityId: identity.id,
            workoutId: workout.id
        ))
        if isCompleted {
            insert(WorkoutCompletions(
                workoutId: workout.id,
                completedAt: .now
            ))
        }
        return workout
    }

    @MainActor @discardableResult
    func makeGroup(
        in workout: WorkoutEntity,
        order: Int,
        isSuperset: Bool = false
    ) -> WorkoutGroupEntity {
        let group = WorkoutGroupEntity(order: order, isSuperset: isSuperset)
        insert(group)
        insert(WorkoutGroups(workoutId: workout.id, groupId: group.id))
        return group
    }

    @MainActor @discardableResult
    func makeTemplate(
        name: String,
        for trainer: IdentityEntity
    ) -> WorkoutEntity {
        let template = WorkoutEntity(
            date: .now,
            isTemplate: true
        )
        insert(template)
        insert(WorkoutTemplate(
            workoutId: template.id,
            name: name
        ))
        insert(IdentityWorkouts(
            identityId: trainer.id,
            workoutId: template.id
        ))
        return template
    }

    @MainActor @discardableResult
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
        insert(set)
        insert(GroupSets(groupId: group.id, setId: set.id))
        insert(ExerciseSets(exerciseId: exercise.id, setId: set.id))
        if isCompleted {
            insert(SetCompletions(
                setId: set.id,
                completedAt: completedAt ?? .now
            ))
        }
        return set
    }
}

// MARK: - Payload Factory

@MainActor func makePayload(
    senderIdentityId: UUID,
    identities: [IdentityDTO] = [],
    exercises: [ExerciseDTO] = [],
    workouts: [WorkoutDTO] = [],
    workoutGroups: [WorkoutGroupDTO] = [],
    sets: [SetDTO] = [],
    workoutTemplates: [WorkoutTemplateDTO] = [],
    workoutNotes: [WorkoutNotesDTO] = [],
    trainerTrainees: [TrainerTraineesDTO] = [],
    trainerExercises: [TrainerExercisesDTO] = [],
    identityWorkouts: [IdentityWorkoutsDTO] = [],
    workoutGroupJoins: [WorkoutGroupsDTO] = [],
    groupSetJoins: [GroupSetsDTO] = [],
    exerciseSetJoins: [ExerciseSetsDTO] = [],
    templateInstanceJoins: [TemplateInstancesDTO] = [],
    identityAliases: [IdentityAliasesDTO] = [],
    setCompletions: [SetCompletionDTO] = [],
    workoutCompletions: [WorkoutCompletionDTO] = [],
    deviceSyncEvents: [DeviceSyncEventDTO] = []
) -> SyncPayload {
    SyncPayload(
        version: 1,
        senderIdentityId: senderIdentityId,
        identities: identities,
        exercises: exercises,
        workouts: workouts,
        workoutGroups: workoutGroups,
        sets: sets,
        workoutTemplates: workoutTemplates,
        workoutNotes: workoutNotes,
        trainerTrainees: trainerTrainees,
        trainerExercises: trainerExercises,
        identityWorkouts: identityWorkouts,
        workoutGroupJoins: workoutGroupJoins,
        groupSetJoins: groupSetJoins,
        exerciseSetJoins: exerciseSetJoins,
        templateInstanceJoins: templateInstanceJoins,
        identityAliases: identityAliases,
        setCompletions: setCompletions,
        workoutCompletions: workoutCompletions,
        deviceSyncEvents: deviceSyncEvents
    )
}
