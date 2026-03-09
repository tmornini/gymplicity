import XCTest
import SwiftData
@testable import Gymplicity

@MainActor final class DomainOperationTests: XCTestCase {

    // MARK: - startWorkout(for:)

    func testStartWorkoutCreatesWorkout() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        let trainee = ctx.makeTrainee(trainer: trainer)

        let workout = ctx.startWorkout(for: trainee)

        XCTAssertNotNil(workout)
        XCTAssertFalse(workout!.isCompleted)
        XCTAssertFalse(workout!.isTemplate)
    }

    func testStartWorkoutReturnsNilWhenActiveWorkoutExists() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        let trainee = ctx.makeTrainee(trainer: trainer)
        ctx.makeWorkout(for: trainee) // active (not completed)

        let second = ctx.startWorkout(for: trainee)

        XCTAssertNil(second)
    }

    func testCreatedWorkoutAppearsInActiveWorkouts() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        let trainee = ctx.makeTrainee(trainer: trainer)

        let workout = ctx.startWorkout(for: trainee)

        let active = trainee.activeWorkouts(in: ctx)
        XCTAssertEqual(active.count, 1)
        XCTAssertEqual(active.first?.id, workout?.id)
    }

    // MARK: - markCompleted()

    func testMarkCompletedSetsIsCompleted() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        let trainee = ctx.makeTrainee(trainer: trainer)
        let workout = ctx.makeWorkout(for: trainee)

        workout.markCompleted()

        XCTAssertTrue(workout.isCompleted)
    }

    func testCompletedWorkoutMovesToCompletedWorkouts() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        let trainee = ctx.makeTrainee(trainer: trainer)
        let workout = ctx.makeWorkout(for: trainee)

        XCTAssertEqual(trainee.activeWorkouts(in: ctx).count, 1)
        XCTAssertEqual(trainee.completedWorkouts(in: ctx).count, 0)

        workout.markCompleted()

        XCTAssertEqual(trainee.activeWorkouts(in: ctx).count, 0)
        XCTAssertEqual(trainee.completedWorkouts(in: ctx).count, 1)
    }

    // MARK: - addSet(to:exercise:seedingFrom:)

    func testAddSetCreatesSetWithJoins() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        let bench = ctx.makeExercise(name: "Bench", trainer: trainer)
        let trainee = ctx.makeTrainee(trainer: trainer)
        let workout = ctx.makeWorkout(for: trainee)
        let group = ctx.makeGroup(in: workout, order: 0)

        let set = ctx.addSet(to: group, exercise: bench, seedingFrom: trainee)

        XCTAssertNotNil(set)
        // Verify GroupSets join exists
        let groupId = group.id
        let gsJoins = try ctx.fetch(FetchDescriptor<GroupSets>(
            predicate: #Predicate { $0.groupId == groupId }
        ))
        XCTAssert(gsJoins.contains { $0.setId == set.id })
        // Verify ExerciseSets join exists
        let exerciseId = bench.id
        let esJoins = try ctx.fetch(FetchDescriptor<ExerciseSets>(
            predicate: #Predicate { $0.exerciseId == exerciseId }
        ))
        XCTAssert(esJoins.contains { $0.setId == set.id })
    }

    func testAddSetSeedsFromLastCompletedSet() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        let bench = ctx.makeExercise(name: "Bench", trainer: trainer)
        let trainee = ctx.makeTrainee(trainer: trainer)

        // Create a completed workout with a bench set
        let past = ctx.makeWorkout(for: trainee, date: .now.addingTimeInterval(-86400), isCompleted: true)
        let pastGroup = ctx.makeGroup(in: past, order: 0)
        ctx.makeSet(in: pastGroup, exercise: bench, order: 0, weight: 185, reps: 5, isCompleted: true)

        // New workout
        let workout = ctx.makeWorkout(for: trainee)
        let group = ctx.makeGroup(in: workout, order: 0)

        let set = ctx.addSet(to: group, exercise: bench, seedingFrom: trainee)

        XCTAssertEqual(set.weight, 185)
        XCTAssertEqual(set.reps, 5)
    }

    func testAddSetNoPriorCompletedSetsDefaultsToZero() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        let bench = ctx.makeExercise(name: "Bench", trainer: trainer)
        let trainee = ctx.makeTrainee(trainer: trainer)
        let workout = ctx.makeWorkout(for: trainee)
        let group = ctx.makeGroup(in: workout, order: 0)

        let set = ctx.addSet(to: group, exercise: bench, seedingFrom: trainee)

        XCTAssertEqual(set.weight, 0)
        XCTAssertEqual(set.reps, 0)
    }

    func testAddSetOwnerNilDefaultsToZero() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        let bench = ctx.makeExercise(name: "Bench", trainer: trainer)
        let trainee = ctx.makeTrainee(trainer: trainer)
        let workout = ctx.makeWorkout(for: trainee)
        let group = ctx.makeGroup(in: workout, order: 0)

        let set = ctx.addSet(to: group, exercise: bench, seedingFrom: nil)

        XCTAssertEqual(set.weight, 0)
        XCTAssertEqual(set.reps, 0)
    }

    func testAddSetOrderIncrementsViaNextSetOrder() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        let bench = ctx.makeExercise(name: "Bench", trainer: trainer)
        let trainee = ctx.makeTrainee(trainer: trainer)
        let workout = ctx.makeWorkout(for: trainee)
        let group = ctx.makeGroup(in: workout, order: 0)

        let set1 = ctx.addSet(to: group, exercise: bench, seedingFrom: nil)
        let set2 = ctx.addSet(to: group, exercise: bench, seedingFrom: nil)
        let set3 = ctx.addSet(to: group, exercise: bench, seedingFrom: nil)

        XCTAssertEqual(set1.order, 0)
        XCTAssertEqual(set2.order, 1)
        XCTAssertEqual(set3.order, 2)
    }

    // MARK: - deleteSets(from:at:)

    func testDeleteSetsAtOffsets() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        let bench = ctx.makeExercise(name: "Bench", trainer: trainer)
        let trainee = ctx.makeTrainee(trainer: trainer)
        let workout = ctx.makeWorkout(for: trainee)
        let group = ctx.makeGroup(in: workout, order: 0)
        ctx.makeSet(in: group, exercise: bench, order: 0, weight: 100, reps: 10)
        let set1 = ctx.makeSet(in: group, exercise: bench, order: 1, weight: 110, reps: 8)
        ctx.makeSet(in: group, exercise: bench, order: 2, weight: 120, reps: 6)

        ctx.deleteSets(from: group, at: IndexSet(integer: 1)) // delete middle set

        let remaining = group.sortedSets(in: ctx)
        XCTAssertEqual(remaining.count, 2)
        XCTAssertFalse(remaining.contains { $0.id == set1.id })
    }

    func testDeleteSetsRemovesJoinRows() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        let bench = ctx.makeExercise(name: "Bench", trainer: trainer)
        let trainee = ctx.makeTrainee(trainer: trainer)
        let workout = ctx.makeWorkout(for: trainee)
        let group = ctx.makeGroup(in: workout, order: 0)
        let set = ctx.makeSet(in: group, exercise: bench, order: 0, weight: 100, reps: 10)
        let setId = set.id

        ctx.deleteSets(from: group, at: IndexSet(integer: 0))

        let gsJoins = try ctx.fetch(FetchDescriptor<GroupSets>(
            predicate: #Predicate { $0.setId == setId }
        ))
        let esJoins = try ctx.fetch(FetchDescriptor<ExerciseSets>(
            predicate: #Predicate { $0.setId == setId }
        ))
        XCTAssert(gsJoins.isEmpty)
        XCTAssert(esJoins.isEmpty)
    }

    // MARK: - exerciseNames(in:) on WorkoutEntity

    func testExerciseNamesReturnsCommaSeparated() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        let bench = ctx.makeExercise(name: "Bench", trainer: trainer)
        let squat = ctx.makeExercise(name: "Squat", trainer: trainer)
        let trainee = ctx.makeTrainee(trainer: trainer)
        let workout = ctx.makeWorkout(for: trainee)
        let g1 = ctx.makeGroup(in: workout, order: 0)
        ctx.makeSet(in: g1, exercise: bench, order: 0, weight: 135, reps: 10)
        let g2 = ctx.makeGroup(in: workout, order: 1)
        ctx.makeSet(in: g2, exercise: squat, order: 0, weight: 225, reps: 5)

        let names = workout.exerciseNames(in: ctx)

        XCTAssertEqual(names, "Bench, Squat")
    }

    func testExerciseNamesDeduplicates() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        let bench = ctx.makeExercise(name: "Bench", trainer: trainer)
        let trainee = ctx.makeTrainee(trainer: trainer)
        let workout = ctx.makeWorkout(for: trainee)
        let g1 = ctx.makeGroup(in: workout, order: 0)
        ctx.makeSet(in: g1, exercise: bench, order: 0, weight: 135, reps: 10)
        ctx.makeSet(in: g1, exercise: bench, order: 1, weight: 155, reps: 8)

        let names = workout.exerciseNames(in: ctx)

        XCTAssertEqual(names, "Bench")
    }

    func testExerciseNamesEmptyWorkout() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        let trainee = ctx.makeTrainee(trainer: trainer)
        let workout = ctx.makeWorkout(for: trainee)

        let names = workout.exerciseNames(in: ctx)

        XCTAssertEqual(names, "")
    }

    // MARK: - exerciseName(in:) on WorkoutGroupEntity

    func testGroupExerciseNameReturnsFirstSetsExercise() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        let bench = ctx.makeExercise(name: "Bench", trainer: trainer)
        let trainee = ctx.makeTrainee(trainer: trainer)
        let workout = ctx.makeWorkout(for: trainee)
        let group = ctx.makeGroup(in: workout, order: 0)
        ctx.makeSet(in: group, exercise: bench, order: 0, weight: 135, reps: 10)

        XCTAssertEqual(group.exerciseName(in: ctx), "Bench")
    }

    func testGroupExerciseNameEmptyGroupReturnsFallback() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        let trainee = ctx.makeTrainee(trainer: trainer)
        let workout = ctx.makeWorkout(for: trainee)
        let group = ctx.makeGroup(in: workout, order: 0)

        XCTAssertEqual(group.exerciseName(in: ctx), "Exercise")
    }

    // MARK: - template(in:) on WorkoutEntity

    func testTemplateReturnsSourceTemplate() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        let trainee = ctx.makeTrainee(trainer: trainer)
        let template = ctx.makeTemplate(name: "Push", for: trainer)
        let workout = ctx.instantiateTemplate(template, for: trainee)

        let found = workout.template(in: ctx)

        XCTAssertEqual(found?.id, template.id)
    }

    func testTemplateReturnsNilForNonInstantiatedWorkout() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        let trainee = ctx.makeTrainee(trainer: trainer)
        let workout = ctx.makeWorkout(for: trainee)

        XCTAssertNil(workout.template(in: ctx))
    }
}
