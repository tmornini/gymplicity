import XCTest
import SwiftData
@testable import Gymplicity

@MainActor final class WorkoutLifecycleTests: XCTestCase {

    func testStartWorkoutAppearsInActiveWorkouts() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        let trainee = ctx.makeTrainee(trainer: trainer)
        let workout = ctx.makeWorkout(for: trainee)

        XCTAssertFalse(workout.isCompleted(in: ctx))
        XCTAssertEqual(trainee.activeWorkouts(in: ctx).count, 1)
        XCTAssert(trainee.completedWorkouts(in: ctx).isEmpty)
    }

    func testAddGroupToWorkout() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        let trainee = ctx.makeTrainee(trainer: trainer)
        let workout = ctx.makeWorkout(for: trainee)

        XCTAssertEqual(workout.nextGroupOrder(in: ctx), 0)

        ctx.makeGroup(in: workout, order: workout.nextGroupOrder(in: ctx))
        XCTAssertEqual(workout.groups(in: ctx).count, 1)
        XCTAssertEqual(workout.nextGroupOrder(in: ctx), 1)

        ctx.makeGroup(in: workout, order: workout.nextGroupOrder(in: ctx))
        XCTAssertEqual(workout.groups(in: ctx).count, 2)
        XCTAssertEqual(workout.nextGroupOrder(in: ctx), 2)
    }

    func testAddSetToGroup() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        let bench = ctx.makeExercise(name: "Bench", trainer: trainer)
        let trainee = ctx.makeTrainee(trainer: trainer)
        let workout = ctx.makeWorkout(for: trainee)
        let group = ctx.makeGroup(in: workout, order: 0)

        XCTAssertEqual(group.nextSetOrder(in: ctx), 0)

        let set = ctx.makeSet(
            in: group,
            exercise: bench,
            order: 0,
            weight: 135,
            reps: 10
        )
        XCTAssertEqual(group.sets(in: ctx).count, 1)
        XCTAssertEqual(group.nextSetOrder(in: ctx), 1)
        XCTAssertEqual(set.exercise(in: ctx)?.id, bench.id)
    }

    func testToggleSetCompletion() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        let bench = ctx.makeExercise(name: "Bench", trainer: trainer)
        let trainee = ctx.makeTrainee(trainer: trainer)
        let workout = ctx.makeWorkout(for: trainee)
        let group = ctx.makeGroup(in: workout, order: 0)
        let set = ctx.makeSet(
            in: group,
            exercise: bench,
            order: 0,
            weight: 135,
            reps: 10
        )

        XCTAssertFalse(set.isCompleted(in: ctx))
        XCTAssertNil(set.completedAt(in: ctx))

        // Complete it
        ctx.insert(SetCompletions(setId: set.id, completedAt: .now))

        XCTAssertTrue(set.isCompleted(in: ctx))
        XCTAssertNotNil(set.completedAt(in: ctx))

        // Uncomplete it
        let setId = set.id
        let completions = try ctx.fetch(FetchDescriptor<SetCompletions>(
            predicate: #Predicate { $0.setId == setId }
        ))
        for completion in completions { ctx.delete(completion) }

        XCTAssertFalse(set.isCompleted(in: ctx))
        XCTAssertNil(set.completedAt(in: ctx))
    }

    func testEndWorkout() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        let trainee = ctx.makeTrainee(trainer: trainer)
        let workout = ctx.makeWorkout(for: trainee)

        XCTAssertEqual(trainee.activeWorkouts(in: ctx).count, 1)

        ctx.insert(WorkoutCompletions(
            workoutId: workout.id,
            completedAt: .now
        ))

        XCTAssert(trainee.activeWorkouts(in: ctx).isEmpty)
        XCTAssertEqual(trainee.completedWorkouts(in: ctx).count, 1)
    }

    func testSetVolume() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        let bench = ctx.makeExercise(name: "Bench", trainer: trainer)
        let trainee = ctx.makeTrainee(trainer: trainer)
        let workout = ctx.makeWorkout(for: trainee)
        let group = ctx.makeGroup(in: workout, order: 0)
        let set = ctx.makeSet(
            in: group,
            exercise: bench,
            order: 0,
            weight: 135,
            reps: 10
        )

        XCTAssertEqual(set.volume, 1350)
    }

    func testGroupAndWorkoutVolume() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        let bench = ctx.makeExercise(name: "Bench", trainer: trainer)
        let squat = ctx.makeExercise(name: "Squat", trainer: trainer)
        let trainee = ctx.makeTrainee(trainer: trainer)
        let workout = ctx.makeWorkout(for: trainee)

        let g1 = ctx.makeGroup(in: workout, order: 0)
        ctx.makeSet( // 1350
            in: g1,
            exercise: bench,
            order: 0,
            weight: 135,
            reps: 10
        )
        ctx.makeSet( // 1240
            in: g1,
            exercise: bench,
            order: 1,
            weight: 155,
            reps: 8
        )

        let g2 = ctx.makeGroup(in: workout, order: 1)
        ctx.makeSet( // 1125
            in: g2,
            exercise: squat,
            order: 0,
            weight: 225,
            reps: 5
        )

        XCTAssertEqual(g1.totalVolume(in: ctx), 2590)
        XCTAssertEqual(g2.totalVolume(in: ctx), 1125)
        XCTAssertEqual(workout.totalVolume(in: ctx), 3715)
    }

    func testExerciseCountDeduplicates() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        let bench = ctx.makeExercise(name: "Bench", trainer: trainer)
        let squat = ctx.makeExercise(name: "Squat", trainer: trainer)
        let trainee = ctx.makeTrainee(trainer: trainer)
        let workout = ctx.makeWorkout(for: trainee)

        let g1 = ctx.makeGroup(in: workout, order: 0)
        ctx.makeSet(in: g1, exercise: bench, order: 0, weight: 135, reps: 10)
        ctx.makeSet(in: g1, exercise: bench, order: 1, weight: 155, reps: 8)

        let g2 = ctx.makeGroup(in: workout, order: 1)
        ctx.makeSet(in: g2, exercise: squat, order: 0, weight: 225, reps: 5)
        ctx.makeSet(in: g2, exercise: bench, order: 1, weight: 165, reps: 6)

        // 2 unique exercises (Bench + Squat), not 4 sets
        XCTAssertEqual(workout.exerciseCount(in: ctx), 2)
    }
}
