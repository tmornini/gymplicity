import XCTest
import SwiftData
@testable import Gymplicity

final class RelationshipTests: XCTestCase {

    // MARK: - Trainer / Trainee

    func testTrainerToTrainees() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        let alex = ctx.makeTrainee(name: "Alex", trainer: trainer)
        let jamie = ctx.makeTrainee(name: "Jamie", trainer: trainer)

        let trainees = trainer.trainees(in: ctx)
        XCTAssertEqual(trainees.count, 2)
        let ids = Set(trainees.map(\.id))
        XCTAssert(ids.contains(alex.id))
        XCTAssert(ids.contains(jamie.id))
    }

    func testTraineeToTrainer() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        let trainee = ctx.makeTrainee(trainer: trainer)

        XCTAssertEqual(trainee.trainer(in: ctx)?.id, trainer.id)
    }

    func testStandaloneIdentityHasNoTrainer() throws {
        let ctx = try makeTestContext()
        let standalone = IdentityEntity(name: "Solo", isTrainer: false)
        ctx.insert(standalone)

        XCTAssertNil(standalone.trainer(in: ctx))
        XCTAssert(standalone.trainees(in: ctx).isEmpty)
    }

    // MARK: - Trainer / Exercises

    func testTrainerExercises() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        ctx.makeExercise(name: "Bench", trainer: trainer)
        ctx.makeExercise(name: "Squat", trainer: trainer)
        ctx.makeExercise(name: "Deadlift", trainer: trainer)

        XCTAssertEqual(trainer.exercises(in: ctx).count, 3)
    }

    func testTrainerWithNoExercises() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()

        XCTAssert(trainer.exercises(in: ctx).isEmpty)
    }

    // MARK: - Identity / Workouts

    func testIdentityWorkouts() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        let trainee = ctx.makeTrainee(trainer: trainer)
        ctx.makeWorkout(for: trainee)
        ctx.makeWorkout(for: trainee)

        XCTAssertEqual(trainee.workouts(in: ctx).count, 2)
        XCTAssert(trainer.workouts(in: ctx).isEmpty)
    }

    func testActiveAndCompletedWorkouts() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        let trainee = ctx.makeTrainee(trainer: trainer)
        let day1 = Date.now.addingTimeInterval(-86400 * 2)
        let day2 = Date.now.addingTimeInterval(-86400)

        ctx.makeWorkout(for: trainee, date: day1, isComplete: true)
        ctx.makeWorkout(for: trainee, date: day2, isComplete: true)
        ctx.makeWorkout(for: trainee)

        XCTAssertEqual(trainee.activeWorkouts(in: ctx).count, 1)

        let completed = trainee.completedWorkouts(in: ctx)
        XCTAssertEqual(completed.count, 2)
        // Sorted newest first
        XCTAssert(completed[0].date > completed[1].date)
    }

    // MARK: - Workout / Owner

    func testWorkoutOwner() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        let trainee = ctx.makeTrainee(trainer: trainer)
        let workout = ctx.makeWorkout(for: trainee)

        XCTAssertEqual(workout.owner(in: ctx)?.id, trainee.id)
    }

    // MARK: - Workout / Supersets / Sets ordering

    func testSortedSupersets() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        let trainee = ctx.makeTrainee(trainer: trainer)
        let workout = ctx.makeWorkout(for: trainee)
        ctx.makeSuperset(in: workout, order: 2)
        ctx.makeSuperset(in: workout, order: 0)
        ctx.makeSuperset(in: workout, order: 1)

        let sorted = workout.sortedSupersets(in: ctx)
        XCTAssertEqual(sorted.count, 3)
        XCTAssertEqual(sorted.map(\.order), [0, 1, 2])
    }

    func testSortedSets() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        let bench = ctx.makeExercise(name: "Bench", trainer: trainer)
        let trainee = ctx.makeTrainee(trainer: trainer)
        let workout = ctx.makeWorkout(for: trainee)
        let superset = ctx.makeSuperset(in: workout, order: 0)
        ctx.makeSet(in: superset, exercise: bench, order: 2, weight: 155, reps: 6)
        ctx.makeSet(in: superset, exercise: bench, order: 0, weight: 135, reps: 10)
        ctx.makeSet(in: superset, exercise: bench, order: 1, weight: 145, reps: 8)

        let sorted = superset.sortedSets(in: ctx)
        XCTAssertEqual(sorted.count, 3)
        XCTAssertEqual(sorted.map(\.order), [0, 1, 2])
    }

    // MARK: - Set reverse lookups

    func testSetExerciseAndSuperset() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        let bench = ctx.makeExercise(name: "Bench", trainer: trainer)
        let trainee = ctx.makeTrainee(trainer: trainer)
        let workout = ctx.makeWorkout(for: trainee)
        let superset = ctx.makeSuperset(in: workout, order: 0)
        let set = ctx.makeSet(in: superset, exercise: bench, order: 0, weight: 135, reps: 10)

        XCTAssertEqual(set.exercise(in: ctx)?.id, bench.id)
        XCTAssertEqual(set.superset(in: ctx)?.id, superset.id)
    }
}
