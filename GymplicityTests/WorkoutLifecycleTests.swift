import XCTest
import SwiftData
@testable import Gymplicity

final class WorkoutLifecycleTests: XCTestCase {

    func testStartWorkoutAppearsInActiveWorkouts() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        let trainee = ctx.makeTrainee(trainer: trainer)
        let workout = ctx.makeWorkout(for: trainee)

        XCTAssertFalse(workout.isComplete)
        XCTAssertEqual(trainee.activeWorkouts(in: ctx).count, 1)
        XCTAssert(trainee.completedWorkouts(in: ctx).isEmpty)
    }

    func testAddSupersetToWorkout() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        let trainee = ctx.makeTrainee(trainer: trainer)
        let workout = ctx.makeWorkout(for: trainee)

        XCTAssertEqual(workout.nextSupersetOrder(in: ctx), 0)

        ctx.makeSuperset(in: workout, order: workout.nextSupersetOrder(in: ctx))
        XCTAssertEqual(workout.supersets(in: ctx).count, 1)
        XCTAssertEqual(workout.nextSupersetOrder(in: ctx), 1)

        ctx.makeSuperset(in: workout, order: workout.nextSupersetOrder(in: ctx))
        XCTAssertEqual(workout.supersets(in: ctx).count, 2)
        XCTAssertEqual(workout.nextSupersetOrder(in: ctx), 2)
    }

    func testAddSetToSuperset() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        let bench = ctx.makeExercise(name: "Bench", trainer: trainer)
        let trainee = ctx.makeTrainee(trainer: trainer)
        let workout = ctx.makeWorkout(for: trainee)
        let superset = ctx.makeSuperset(in: workout, order: 0)

        XCTAssertEqual(superset.nextSetOrder(in: ctx), 0)

        let set = ctx.makeSet(in: superset, exercise: bench, order: 0, weight: 135, reps: 10)
        XCTAssertEqual(superset.sets(in: ctx).count, 1)
        XCTAssertEqual(superset.nextSetOrder(in: ctx), 1)
        XCTAssertEqual(set.exercise(in: ctx)?.id, bench.id)
    }

    func testToggleSetCompletion() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        let bench = ctx.makeExercise(name: "Bench", trainer: trainer)
        let trainee = ctx.makeTrainee(trainer: trainer)
        let workout = ctx.makeWorkout(for: trainee)
        let superset = ctx.makeSuperset(in: workout, order: 0)
        let set = ctx.makeSet(in: superset, exercise: bench, order: 0, weight: 135, reps: 10)

        XCTAssertFalse(set.isCompleted)
        XCTAssertNil(set.completedAt)

        // Complete it
        set.isCompleted = true
        set.completedAt = .now

        XCTAssertTrue(set.isCompleted)
        XCTAssertNotNil(set.completedAt)

        // Uncomplete it
        set.isCompleted = false
        set.completedAt = nil

        XCTAssertFalse(set.isCompleted)
        XCTAssertNil(set.completedAt)
    }

    func testEndWorkout() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        let trainee = ctx.makeTrainee(trainer: trainer)
        let workout = ctx.makeWorkout(for: trainee)

        XCTAssertEqual(trainee.activeWorkouts(in: ctx).count, 1)

        workout.isComplete = true

        XCTAssert(trainee.activeWorkouts(in: ctx).isEmpty)
        XCTAssertEqual(trainee.completedWorkouts(in: ctx).count, 1)
    }

    func testSetVolume() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        let bench = ctx.makeExercise(name: "Bench", trainer: trainer)
        let trainee = ctx.makeTrainee(trainer: trainer)
        let workout = ctx.makeWorkout(for: trainee)
        let superset = ctx.makeSuperset(in: workout, order: 0)
        let set = ctx.makeSet(in: superset, exercise: bench, order: 0, weight: 135, reps: 10)

        XCTAssertEqual(set.volume, 1350)
    }

    func testSupersetAndWorkoutVolume() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        let bench = ctx.makeExercise(name: "Bench", trainer: trainer)
        let squat = ctx.makeExercise(name: "Squat", trainer: trainer)
        let trainee = ctx.makeTrainee(trainer: trainer)
        let workout = ctx.makeWorkout(for: trainee)

        let ss1 = ctx.makeSuperset(in: workout, order: 0)
        ctx.makeSet(in: ss1, exercise: bench, order: 0, weight: 135, reps: 10) // 1350
        ctx.makeSet(in: ss1, exercise: bench, order: 1, weight: 155, reps: 8)  // 1240

        let ss2 = ctx.makeSuperset(in: workout, order: 1)
        ctx.makeSet(in: ss2, exercise: squat, order: 0, weight: 225, reps: 5)  // 1125

        XCTAssertEqual(ss1.totalVolume(in: ctx), 2590)
        XCTAssertEqual(ss2.totalVolume(in: ctx), 1125)
        XCTAssertEqual(workout.totalVolume(in: ctx), 3715)
    }

    func testExerciseCountDeduplicates() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        let bench = ctx.makeExercise(name: "Bench", trainer: trainer)
        let squat = ctx.makeExercise(name: "Squat", trainer: trainer)
        let trainee = ctx.makeTrainee(trainer: trainer)
        let workout = ctx.makeWorkout(for: trainee)

        let ss1 = ctx.makeSuperset(in: workout, order: 0)
        ctx.makeSet(in: ss1, exercise: bench, order: 0, weight: 135, reps: 10)
        ctx.makeSet(in: ss1, exercise: bench, order: 1, weight: 155, reps: 8)

        let ss2 = ctx.makeSuperset(in: workout, order: 1)
        ctx.makeSet(in: ss2, exercise: squat, order: 0, weight: 225, reps: 5)
        ctx.makeSet(in: ss2, exercise: bench, order: 1, weight: 165, reps: 6)

        // 2 unique exercises (Bench + Squat), not 4 sets
        XCTAssertEqual(workout.exerciseCount(in: ctx), 2)
    }
}
