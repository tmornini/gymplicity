import XCTest
import SwiftData
@testable import Gymplicity

@MainActor final class CascadeDeleteTests: XCTestCase {

    func testDeleteSetRemovesJoinRows() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        let bench = ctx.makeExercise(name: "Bench", trainer: trainer)
        let trainee = ctx.makeTrainee(trainer: trainer)
        let workout = ctx.makeWorkout(for: trainee)
        let group = ctx.makeGroup(in: workout, order: 0)
        let set = ctx.makeSet(in: group, exercise: bench, order: 0, weight: 135, reps: 10)
        let setId = set.id

        ctx.deleteSet(set)

        // Set is gone
        let sets = try ctx.fetch(FetchDescriptor<SetEntity>(
            predicate: #Predicate { $0.id == setId }
        ))
        XCTAssert(sets.isEmpty)

        // Join rows cleaned up
        let groupSets = try ctx.fetch(FetchDescriptor<GroupSets>(
            predicate: #Predicate { $0.setId == setId }
        ))
        XCTAssert(groupSets.isEmpty)

        let exerciseSets = try ctx.fetch(FetchDescriptor<ExerciseSets>(
            predicate: #Predicate { $0.setId == setId }
        ))
        XCTAssert(exerciseSets.isEmpty)

        // Group and exercise still exist
        XCTAssertEqual(group.sets(in: ctx).count, 0)
        XCTAssertNotNil(try ctx.fetch(FetchDescriptor<ExerciseEntity>(
            predicate: #Predicate { $0.name == "Bench" }
        )).first)
    }

    func testDeleteGroupCascadesToSets() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        let bench = ctx.makeExercise(name: "Bench", trainer: trainer)
        let trainee = ctx.makeTrainee(trainer: trainer)
        let workout = ctx.makeWorkout(for: trainee)
        let group = ctx.makeGroup(in: workout, order: 0)
        ctx.makeSet(in: group, exercise: bench, order: 0, weight: 135, reps: 10)
        ctx.makeSet(in: group, exercise: bench, order: 1, weight: 155, reps: 8)
        let groupId = group.id

        ctx.deleteGroup(group)

        // Group is gone
        let groups = try ctx.fetch(FetchDescriptor<WorkoutGroupEntity>(
            predicate: #Predicate { $0.id == groupId }
        ))
        XCTAssert(groups.isEmpty)

        // Both sets are gone
        let allSets = try ctx.fetch(FetchDescriptor<SetEntity>())
        XCTAssert(allSets.isEmpty)

        // Workout still exists
        XCTAssertEqual(workout.groups(in: ctx).count, 0)
    }

    func testDeleteWorkoutCascadesToGroupsAndSets() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        let bench = ctx.makeExercise(name: "Bench", trainer: trainer)
        let trainee = ctx.makeTrainee(trainer: trainer)
        let workout = ctx.makeWorkout(for: trainee)
        let g1 = ctx.makeGroup(in: workout, order: 0)
        ctx.makeSet(in: g1, exercise: bench, order: 0, weight: 135, reps: 10)
        let g2 = ctx.makeGroup(in: workout, order: 1)
        ctx.makeSet(in: g2, exercise: bench, order: 0, weight: 155, reps: 8)
        let workoutId = workout.id

        ctx.deleteWorkout(workout)

        let workouts = try ctx.fetch(FetchDescriptor<WorkoutEntity>(
            predicate: #Predicate { $0.id == workoutId }
        ))
        XCTAssert(workouts.isEmpty)
        XCTAssert(try ctx.fetch(FetchDescriptor<WorkoutGroupEntity>()).isEmpty)
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
        let group = ctx.makeGroup(in: workout, order: 0)
        let set1 = ctx.makeSet(in: group, exercise: bench, order: 0, weight: 135, reps: 10)
        let set2 = ctx.makeSet(in: group, exercise: bench, order: 1, weight: 155, reps: 8)

        ctx.deleteExercise(bench)

        // Exercise is gone
        XCTAssert(try ctx.fetch(FetchDescriptor<ExerciseEntity>(
            predicate: #Predicate { $0.name == "Bench" }
        )).isEmpty)

        // ExerciseSets joins are gone
        XCTAssert(try ctx.fetch(FetchDescriptor<ExerciseSets>()).isEmpty)

        // But the sets survive (nullify, not cascade)
        XCTAssertEqual(group.sets(in: ctx).count, 2)
        XCTAssertNil(set1.exercise(in: ctx))
        XCTAssertNil(set2.exercise(in: ctx))
    }

    func testDeleteIdentityCascadesCompletely() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        let bench = ctx.makeExercise(name: "Bench", trainer: trainer)
        let trainee = ctx.makeTrainee(trainer: trainer)
        let workout = ctx.makeWorkout(for: trainee)
        let group = ctx.makeGroup(in: workout, order: 0)
        ctx.makeSet(in: group, exercise: bench, order: 0, weight: 135, reps: 10)

        ctx.deleteIdentity(trainer)

        // Everything is gone
        XCTAssert(try ctx.fetch(FetchDescriptor<IdentityEntity>()).isEmpty)
        XCTAssert(try ctx.fetch(FetchDescriptor<ExerciseEntity>()).isEmpty)
        XCTAssert(try ctx.fetch(FetchDescriptor<WorkoutEntity>()).isEmpty)
        XCTAssert(try ctx.fetch(FetchDescriptor<WorkoutGroupEntity>()).isEmpty)
        XCTAssert(try ctx.fetch(FetchDescriptor<SetEntity>()).isEmpty)
        XCTAssert(try ctx.fetch(FetchDescriptor<TrainerTrainees>()).isEmpty)
        XCTAssert(try ctx.fetch(FetchDescriptor<TrainerExercises>()).isEmpty)
        XCTAssert(try ctx.fetch(FetchDescriptor<IdentityWorkouts>()).isEmpty)
        XCTAssert(try ctx.fetch(FetchDescriptor<WorkoutGroups>()).isEmpty)
        XCTAssert(try ctx.fetch(FetchDescriptor<GroupSets>()).isEmpty)
        XCTAssert(try ctx.fetch(FetchDescriptor<ExerciseSets>()).isEmpty)
    }
}
