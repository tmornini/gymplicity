import XCTest
import SwiftData
@testable import Gymplicity

@MainActor final class GuidedWorkoutTests: XCTestCase {

    func testAllSetsFlattenedReturnsCorrectOrder() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer(name: "Trainer")
        let bench = ctx.makeExercise(
            name: "Bench",
            trainer: trainer
        )
        let squat = ctx.makeExercise(
            name: "Squat",
            trainer: trainer
        )
        let trainee = ctx.makeTrainee(
            name: "Trainee",
            trainer: trainer
        )
        let workout = ctx.makeWorkout(
            for: trainee,
            date: .now,
            isCompleted: false
        )

        let g1 = ctx.makeGroup(
            in: workout,
            order: 0,
            isSuperset: false
        )
        let set1 = ctx.makeSet(
            in: g1,
            exercise: bench,
            order: 0,
            weight: 135,
            reps: 10,
            isCompleted: false,
            completedAt: nil
        )
        let set2 = ctx.makeSet(
            in: g1,
            exercise: bench,
            order: 1,
            weight: 155,
            reps: 8,
            isCompleted: false,
            completedAt: nil
        )

        let g2 = ctx.makeGroup(
            in: workout,
            order: 1,
            isSuperset: false
        )
        let set3 = ctx.makeSet(
            in: g2,
            exercise: squat,
            order: 0,
            weight: 225,
            reps: 5,
            isCompleted: false,
            completedAt: nil
        )

        let flat = workout.allSetsFlattened(in: ctx)
        XCTAssertEqual(flat.count, 3)
        XCTAssertEqual(flat[0].set.id, set1.id)
        XCTAssertEqual(flat[0].group.id, g1.id)
        XCTAssertEqual(flat[1].set.id, set2.id)
        XCTAssertEqual(flat[2].set.id, set3.id)
        XCTAssertEqual(flat[2].group.id, g2.id)
    }

    func testFirstIncompleteSetIndexReturnsFirst() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer(name: "Trainer")
        let bench = ctx.makeExercise(
            name: "Bench",
            trainer: trainer
        )
        let trainee = ctx.makeTrainee(
            name: "Trainee",
            trainer: trainer
        )
        let workout = ctx.makeWorkout(
            for: trainee,
            date: .now,
            isCompleted: false
        )
        let ss = ctx.makeGroup(
            in: workout,
            order: 0,
            isSuperset: false
        )
        ctx.makeSet(
            in: ss,
            exercise: bench,
            order: 0,
            weight: 135,
            reps: 10,
            isCompleted: true,
            completedAt: .now
        )
        ctx.makeSet(
            in: ss,
            exercise: bench,
            order: 1,
            weight: 155,
            reps: 8,
            isCompleted: false,
            completedAt: nil
        )
        ctx.makeSet(
            in: ss,
            exercise: bench,
            order: 2,
            weight: 165,
            reps: 6,
            isCompleted: false,
            completedAt: nil
        )

        XCTAssertEqual(
            workout.firstIncompleteSetIndex(in: ctx),
            1
        )
    }

    func testFirstIncompleteSetIndexReturnsNilWhenAllComplete() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer(name: "Trainer")
        let bench = ctx.makeExercise(
            name: "Bench",
            trainer: trainer
        )
        let trainee = ctx.makeTrainee(
            name: "Trainee",
            trainer: trainer
        )
        let workout = ctx.makeWorkout(
            for: trainee,
            date: .now,
            isCompleted: false
        )
        let ss = ctx.makeGroup(
            in: workout,
            order: 0,
            isSuperset: false
        )
        ctx.makeSet(
            in: ss,
            exercise: bench,
            order: 0,
            weight: 135,
            reps: 10,
            isCompleted: true,
            completedAt: .now
        )
        ctx.makeSet(
            in: ss,
            exercise: bench,
            order: 1,
            weight: 155,
            reps: 8,
            isCompleted: true,
            completedAt: .now
        )

        XCTAssertNil(workout.firstIncompleteSetIndex(in: ctx))
    }

    func testNextIncompleteSetIndexScansForward() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer(name: "Trainer")
        let bench = ctx.makeExercise(
            name: "Bench",
            trainer: trainer
        )
        let trainee = ctx.makeTrainee(
            name: "Trainee",
            trainer: trainer
        )
        let workout = ctx.makeWorkout(
            for: trainee,
            date: .now,
            isCompleted: false
        )
        let ss = ctx.makeGroup(
            in: workout,
            order: 0,
            isSuperset: false
        )
        // index 0
        ctx.makeSet(
            in: ss,
            exercise: bench,
            order: 0,
            weight: 135,
            reps: 10,
            isCompleted: false,
            completedAt: nil
        )
        // index 1
        ctx.makeSet(
            in: ss,
            exercise: bench,
            order: 1,
            weight: 155,
            reps: 8,
            isCompleted: true,
            completedAt: .now
        )
        // index 2
        ctx.makeSet(
            in: ss,
            exercise: bench,
            order: 2,
            weight: 165,
            reps: 6,
            isCompleted: false,
            completedAt: nil
        )

        // From index 0, next incomplete is index 2
        // (skipping completed index 1)
        XCTAssertEqual(
            workout.nextIncompleteSetIndex(after: 0, in: ctx),
            2
        )
    }

    func testNextIncompleteSetIndexWrapsAround() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer(name: "Trainer")
        let bench = ctx.makeExercise(
            name: "Bench",
            trainer: trainer
        )
        let trainee = ctx.makeTrainee(
            name: "Trainee",
            trainer: trainer
        )
        let workout = ctx.makeWorkout(
            for: trainee,
            date: .now,
            isCompleted: false
        )
        let ss = ctx.makeGroup(
            in: workout,
            order: 0,
            isSuperset: false
        )
        // index 0 - incomplete
        ctx.makeSet(
            in: ss,
            exercise: bench,
            order: 0,
            weight: 135,
            reps: 10,
            isCompleted: false,
            completedAt: nil
        )
        // index 1
        ctx.makeSet(
            in: ss,
            exercise: bench,
            order: 1,
            weight: 155,
            reps: 8,
            isCompleted: true,
            completedAt: .now
        )
        // index 2
        ctx.makeSet(
            in: ss,
            exercise: bench,
            order: 2,
            weight: 165,
            reps: 6,
            isCompleted: true,
            completedAt: .now
        )

        // From index 2, only incomplete is index 0
        // (wraps around)
        XCTAssertEqual(
            workout.nextIncompleteSetIndex(after: 2, in: ctx),
            0
        )
    }

    func testCompletionProgress() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer(name: "Trainer")
        let bench = ctx.makeExercise(
            name: "Bench",
            trainer: trainer
        )
        let trainee = ctx.makeTrainee(
            name: "Trainee",
            trainer: trainer
        )
        let workout = ctx.makeWorkout(
            for: trainee,
            date: .now,
            isCompleted: false
        )
        let ss = ctx.makeGroup(
            in: workout,
            order: 0,
            isSuperset: false
        )
        ctx.makeSet(
            in: ss,
            exercise: bench,
            order: 0,
            weight: 135,
            reps: 10,
            isCompleted: false,
            completedAt: nil
        )
        ctx.makeSet(
            in: ss,
            exercise: bench,
            order: 1,
            weight: 155,
            reps: 8,
            isCompleted: false,
            completedAt: nil
        )

        // 0% complete
        XCTAssertEqual(workout.completionProgress(in: ctx), 0.0)

        // Complete one of two → 50%
        let flat = workout.allSetsFlattened(in: ctx)
        ctx.insert(SetCompletions(setId: flat[0].set.id, completedAt: .now))
        XCTAssertEqual(workout.completionProgress(in: ctx), 0.5)

        // Complete both → 100%
        ctx.insert(SetCompletions(setId: flat[1].set.id, completedAt: .now))
        XCTAssertEqual(workout.completionProgress(in: ctx), 1.0)
    }

    func testCompletionProgressEmptyWorkout() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer(name: "Trainer")
        let trainee = ctx.makeTrainee(
            name: "Trainee",
            trainer: trainer
        )
        let workout = ctx.makeWorkout(
            for: trainee,
            date: .now,
            isCompleted: false
        )

        // Empty workout → 100% (nothing to do)
        XCTAssertEqual(workout.completionProgress(in: ctx), 1.0)
    }
}
