import XCTest
import SwiftData
@testable import Gymplicity

final class ExerciseCatalogTests: XCTestCase {

    func testFindOrCreateExerciseCreatesNew() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()

        XCTAssert(trainer.exercises(in: ctx).isEmpty)

        let bench = trainer.findOrCreateExercise(named: "Bench Press", in: ctx)

        XCTAssertEqual(bench.name, "Bench Press")
        XCTAssertEqual(trainer.exercises(in: ctx).count, 1)
    }

    func testFindOrCreateExerciseFindsExisting() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        let original = ctx.makeExercise(name: "Bench Press", trainer: trainer)

        let found = trainer.findOrCreateExercise(named: "Bench Press", in: ctx)

        XCTAssertEqual(found.id, original.id)
        XCTAssertEqual(trainer.exercises(in: ctx).count, 1)
    }

    func testFindOrCreateExerciseCaseInsensitive() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        let original = ctx.makeExercise(name: "Bench Press", trainer: trainer)

        let lower = trainer.findOrCreateExercise(named: "bench press", in: ctx)
        let upper = trainer.findOrCreateExercise(named: "BENCH PRESS", in: ctx)

        XCTAssertEqual(lower.id, original.id)
        XCTAssertEqual(upper.id, original.id)
        XCTAssertEqual(trainer.exercises(in: ctx).count, 1)
    }

    func testExerciseCatalogSortedAlphabetically() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        ctx.makeExercise(name: "Squat", trainer: trainer)
        ctx.makeExercise(name: "Bench Press", trainer: trainer)
        ctx.makeExercise(name: "Deadlift", trainer: trainer)

        let catalog = trainer.exerciseCatalog(in: ctx)
        XCTAssertEqual(catalog.map(\.name), ["Bench Press", "Deadlift", "Squat"])
    }

    func testTraineeExerciseCatalogReturnsTrainerExercises() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        ctx.makeExercise(name: "Squat", trainer: trainer)
        ctx.makeExercise(name: "Bench Press", trainer: trainer)
        let trainee = ctx.makeTrainee(trainer: trainer)

        let catalog = trainee.exerciseCatalog(in: ctx)
        XCTAssertEqual(catalog.map(\.name), ["Bench Press", "Squat"])
    }

    func testTraineeWithoutTrainerHasEmptyCatalog() throws {
        let ctx = try makeTestContext()
        let standalone = IdentityEntity(name: "Solo", isTrainer: false)
        ctx.insert(standalone)

        XCTAssert(standalone.exerciseCatalog(in: ctx).isEmpty)
    }

    func testAllExercisesDeduplicatesAndSorts() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        let bench = ctx.makeExercise(name: "Bench Press", trainer: trainer)
        let squat = ctx.makeExercise(name: "Squat", trainer: trainer)
        let trainee = ctx.makeTrainee(trainer: trainer)

        // Two workouts both using Bench
        let w1 = ctx.makeWorkout(for: trainee, date: .now.addingTimeInterval(-86400), isComplete: true)
        let ss1 = ctx.makeSuperset(in: w1, order: 0)
        ctx.makeSet(in: ss1, exercise: bench, order: 0, weight: 135, reps: 10)

        let w2 = ctx.makeWorkout(for: trainee, isComplete: true)
        let ss2 = ctx.makeSuperset(in: w2, order: 0)
        ctx.makeSet(in: ss2, exercise: bench, order: 0, weight: 145, reps: 8)
        ctx.makeSet(in: ss2, exercise: squat, order: 1, weight: 225, reps: 5)

        let all = trainee.allExercises(in: ctx)
        XCTAssertEqual(all.count, 2)
        XCTAssertEqual(all.map(\.name), ["Bench Press", "Squat"])
    }
}
