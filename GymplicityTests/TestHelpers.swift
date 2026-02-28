import Foundation
import SwiftData
import XCTest
@testable import Gymplicity

func makeTestContext() throws -> ModelContext {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
        for: IdentityEntity.self, ExerciseEntity.self, WorkoutEntity.self,
        SupersetEntity.self, SetEntity.self, TrainerTrainees.self,
        TrainerExercises.self, IdentityWorkouts.self, WorkoutSupersets.self,
        SupersetSets.self, ExerciseSets.self,
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
    func makeWorkout(for identity: IdentityEntity, date: Date = .now, isComplete: Bool = false) -> WorkoutEntity {
        let workout = WorkoutEntity(date: date)
        workout.isComplete = isComplete
        insert(workout)
        insert(IdentityWorkouts(identityId: identity.id, workoutId: workout.id))
        return workout
    }

    @discardableResult
    func makeSuperset(in workout: WorkoutEntity, order: Int) -> SupersetEntity {
        let superset = SupersetEntity(order: order)
        insert(superset)
        insert(WorkoutSupersets(workoutId: workout.id, supersetId: superset.id))
        return superset
    }

    @discardableResult
    func makeSet(
        in superset: SupersetEntity,
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
        insert(SupersetSets(supersetId: superset.id, setId: set.id))
        insert(ExerciseSets(exerciseId: exercise.id, setId: set.id))
        return set
    }
}
