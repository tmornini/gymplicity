import XCTest
import SwiftData
@testable import Gymplicity

final class CascadeDeleteTests: XCTestCase {

    func testDeleteSetRemovesJoinRows() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        let bench = ctx.makeExercise(name: "Bench", trainer: trainer)
        let trainee = ctx.makeTrainee(trainer: trainer)
        let workout = ctx.makeWorkout(for: trainee)
        let superset = ctx.makeSuperset(in: workout, order: 0)
        let set = ctx.makeSet(in: superset, exercise: bench, order: 0, weight: 135, reps: 10)
        let setId = set.id

        ctx.deleteSet(set)

        // Set is gone
        let sets = try ctx.fetch(FetchDescriptor<SetEntity>(
            predicate: #Predicate { $0.id == setId }
        ))
        XCTAssert(sets.isEmpty)

        // Join rows cleaned up
        let supersetSets = try ctx.fetch(FetchDescriptor<SupersetSets>(
            predicate: #Predicate { $0.setId == setId }
        ))
        XCTAssert(supersetSets.isEmpty)

        let exerciseSets = try ctx.fetch(FetchDescriptor<ExerciseSets>(
            predicate: #Predicate { $0.setId == setId }
        ))
        XCTAssert(exerciseSets.isEmpty)

        // Superset and exercise still exist
        XCTAssertEqual(superset.sets(in: ctx).count, 0)
        XCTAssertNotNil(try ctx.fetch(FetchDescriptor<ExerciseEntity>(
            predicate: #Predicate { $0.name == "Bench" }
        )).first)
    }

    func testDeleteSupersetCascadesToSets() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        let bench = ctx.makeExercise(name: "Bench", trainer: trainer)
        let trainee = ctx.makeTrainee(trainer: trainer)
        let workout = ctx.makeWorkout(for: trainee)
        let superset = ctx.makeSuperset(in: workout, order: 0)
        ctx.makeSet(in: superset, exercise: bench, order: 0, weight: 135, reps: 10)
        ctx.makeSet(in: superset, exercise: bench, order: 1, weight: 155, reps: 8)
        let supersetId = superset.id

        ctx.deleteSuperset(superset)

        // Superset is gone
        let supers = try ctx.fetch(FetchDescriptor<SupersetEntity>(
            predicate: #Predicate { $0.id == supersetId }
        ))
        XCTAssert(supers.isEmpty)

        // Both sets are gone
        let allSets = try ctx.fetch(FetchDescriptor<SetEntity>())
        XCTAssert(allSets.isEmpty)

        // Workout still exists
        XCTAssertEqual(workout.supersets(in: ctx).count, 0)
    }

    func testDeleteWorkoutCascadesToSupersetsAndSets() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        let bench = ctx.makeExercise(name: "Bench", trainer: trainer)
        let trainee = ctx.makeTrainee(trainer: trainer)
        let workout = ctx.makeWorkout(for: trainee)
        let ss1 = ctx.makeSuperset(in: workout, order: 0)
        ctx.makeSet(in: ss1, exercise: bench, order: 0, weight: 135, reps: 10)
        let ss2 = ctx.makeSuperset(in: workout, order: 1)
        ctx.makeSet(in: ss2, exercise: bench, order: 0, weight: 155, reps: 8)
        let workoutId = workout.id

        ctx.deleteWorkout(workout)

        let workouts = try ctx.fetch(FetchDescriptor<WorkoutEntity>(
            predicate: #Predicate { $0.id == workoutId }
        ))
        XCTAssert(workouts.isEmpty)
        XCTAssert(try ctx.fetch(FetchDescriptor<SupersetEntity>()).isEmpty)
        XCTAssert(try ctx.fetch(FetchDescriptor<SetEntity>()).isEmpty)

        // Identity and exercise survive
        XCTAssert(trainee.workouts(in: ctx).isEmpty)
        XCTAssertEqual(trainer.exercises(in: ctx).count, 1)
    }

    func testDeleteExerciseNullifiesSets() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        let bench = ctx.makeExercise(name: "Bench", trainer: trainer)
        let trainee = ctx.makeTrainee(trainer: trainer)
        let workout = ctx.makeWorkout(for: trainee)
        let superset = ctx.makeSuperset(in: workout, order: 0)
        let set1 = ctx.makeSet(in: superset, exercise: bench, order: 0, weight: 135, reps: 10)
        let set2 = ctx.makeSet(in: superset, exercise: bench, order: 1, weight: 155, reps: 8)

        ctx.deleteExercise(bench)

        // Exercise is gone
        XCTAssert(try ctx.fetch(FetchDescriptor<ExerciseEntity>(
            predicate: #Predicate { $0.name == "Bench" }
        )).isEmpty)

        // ExerciseSets joins are gone
        XCTAssert(try ctx.fetch(FetchDescriptor<ExerciseSets>()).isEmpty)

        // But the sets survive (nullify, not cascade)
        XCTAssertEqual(superset.sets(in: ctx).count, 2)
        XCTAssertNil(set1.exercise(in: ctx))
        XCTAssertNil(set2.exercise(in: ctx))
    }

    func testDeleteIdentityCascadesCompletely() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        let bench = ctx.makeExercise(name: "Bench", trainer: trainer)
        let trainee = ctx.makeTrainee(trainer: trainer)
        let workout = ctx.makeWorkout(for: trainee)
        let superset = ctx.makeSuperset(in: workout, order: 0)
        ctx.makeSet(in: superset, exercise: bench, order: 0, weight: 135, reps: 10)

        ctx.deleteIdentity(trainer)

        // Everything is gone
        XCTAssert(try ctx.fetch(FetchDescriptor<IdentityEntity>()).isEmpty)
        XCTAssert(try ctx.fetch(FetchDescriptor<ExerciseEntity>()).isEmpty)
        XCTAssert(try ctx.fetch(FetchDescriptor<WorkoutEntity>()).isEmpty)
        XCTAssert(try ctx.fetch(FetchDescriptor<SupersetEntity>()).isEmpty)
        XCTAssert(try ctx.fetch(FetchDescriptor<SetEntity>()).isEmpty)
        XCTAssert(try ctx.fetch(FetchDescriptor<TrainerTrainees>()).isEmpty)
        XCTAssert(try ctx.fetch(FetchDescriptor<TrainerExercises>()).isEmpty)
        XCTAssert(try ctx.fetch(FetchDescriptor<IdentityWorkouts>()).isEmpty)
        XCTAssert(try ctx.fetch(FetchDescriptor<WorkoutSupersets>()).isEmpty)
        XCTAssert(try ctx.fetch(FetchDescriptor<SupersetSets>()).isEmpty)
        XCTAssert(try ctx.fetch(FetchDescriptor<ExerciseSets>()).isEmpty)
    }
}
