import XCTest
import SwiftData
@testable import Gymplicity

final class HistoryTests: XCTestCase {

    func testLastSetReturnsNilForNewExercise() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        let bench = ctx.makeExercise(name: "Bench", trainer: trainer)
        let trainee = ctx.makeTrainee(trainer: trainer)

        XCTAssertNil(trainee.lastSet(for: bench, in: ctx))
    }

    func testLastSetReturnsMostRecentCompleted() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        let bench = ctx.makeExercise(name: "Bench", trainer: trainer)
        let trainee = ctx.makeTrainee(trainer: trainer)

        // Older workout
        let w1 = ctx.makeWorkout(for: trainee, date: .now.addingTimeInterval(-86400 * 2), isComplete: true)
        let ss1 = ctx.makeSuperset(in: w1, order: 0)
        ctx.makeSet(in: ss1, exercise: bench, order: 0, weight: 135, reps: 10, isCompleted: true)

        // Newer workout
        let w2 = ctx.makeWorkout(for: trainee, date: .now.addingTimeInterval(-86400), isComplete: true)
        let ss2 = ctx.makeSuperset(in: w2, order: 0)
        ctx.makeSet(in: ss2, exercise: bench, order: 0, weight: 155, reps: 8, isCompleted: true)

        let last = trainee.lastSet(for: bench, in: ctx)
        XCTAssertNotNil(last)
        XCTAssertEqual(last?.weight, 155)
        XCTAssertEqual(last?.reps, 8)
    }

    func testHistoryReturnsChronologicalOrder() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        let bench = ctx.makeExercise(name: "Bench", trainer: trainer)
        let trainee = ctx.makeTrainee(trainer: trainer)

        let day1 = Date.now.addingTimeInterval(-86400 * 3)
        let day2 = Date.now.addingTimeInterval(-86400 * 2)
        let day3 = Date.now.addingTimeInterval(-86400)

        let w1 = ctx.makeWorkout(for: trainee, date: day1, isComplete: true)
        let ss1 = ctx.makeSuperset(in: w1, order: 0)
        ctx.makeSet(in: ss1, exercise: bench, order: 0, weight: 135, reps: 10)

        let w2 = ctx.makeWorkout(for: trainee, date: day2, isComplete: true)
        let ss2 = ctx.makeSuperset(in: w2, order: 0)
        ctx.makeSet(in: ss2, exercise: bench, order: 0, weight: 145, reps: 8)

        let w3 = ctx.makeWorkout(for: trainee, date: day3, isComplete: true)
        let ss3 = ctx.makeSuperset(in: w3, order: 0)
        ctx.makeSet(in: ss3, exercise: bench, order: 0, weight: 155, reps: 6)

        let history = trainee.history(for: bench, in: ctx)
        XCTAssertEqual(history.count, 3)
        // Oldest first
        XCTAssertEqual(history[0].set.weight, 135)
        XCTAssertEqual(history[1].set.weight, 145)
        XCTAssertEqual(history[2].set.weight, 155)
    }

    func testHistoryExcludesActiveWorkouts() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        let bench = ctx.makeExercise(name: "Bench", trainer: trainer)
        let trainee = ctx.makeTrainee(trainer: trainer)

        // Completed workout
        let completed = ctx.makeWorkout(for: trainee, date: .now.addingTimeInterval(-86400), isComplete: true)
        let ss1 = ctx.makeSuperset(in: completed, order: 0)
        ctx.makeSet(in: ss1, exercise: bench, order: 0, weight: 135, reps: 10)

        // Active workout (not complete)
        let active = ctx.makeWorkout(for: trainee)
        let ss2 = ctx.makeSuperset(in: active, order: 0)
        ctx.makeSet(in: ss2, exercise: bench, order: 0, weight: 155, reps: 8)

        let history = trainee.history(for: bench, in: ctx)
        XCTAssertEqual(history.count, 1)
        XCTAssertEqual(history[0].set.weight, 135)
    }
}
