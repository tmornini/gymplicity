import XCTest
import SwiftData
@testable import Gymplicity

@MainActor final class TemplateTests: XCTestCase {

    func testCreateTemplate() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer(name: "Trainer")
        let template = ctx.makeTemplate(
            name: "Push Day",
            for: trainer
        )

        XCTAssertTrue(template.isTemplate)
        XCTAssertEqual(
            template.templateName(in: ctx),
            "Push Day"
        )
        XCTAssertFalse(template.isCompleted(in: ctx))
    }

    func testTemplatesFilteredFromActiveWorkouts() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer(name: "Trainer")
        let trainee = ctx.makeTrainee(
            name: "Trainee",
            trainer: trainer
        )
        ctx.makeTemplate(
            name: "Push Day",
            for: trainer
        )
        ctx.makeWorkout(
            for: trainee,
            date: .now,
            isCompleted: false
        )

        XCTAssertEqual(trainee.activeWorkouts(in: ctx).count, 1)
        XCTAssertTrue(
            trainee.activeWorkouts(in: ctx)
                .allSatisfy { !$0.isTemplate }
        )
    }

    func testTemplatesFilteredFromCompletedWorkouts() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer(name: "Trainer")
        ctx.makeTemplate(
            name: "Push Day",
            for: trainer
        )
        let workout = ctx.makeWorkout(
            for: trainer,
            date: .now,
            isCompleted: false
        )
        ctx.insert(WorkoutCompletions(
            workoutId: workout.id,
            completedAt: .now
        ))

        XCTAssertEqual(trainer.completedWorkouts(in: ctx).count, 1)
        XCTAssertTrue(
            trainer.completedWorkouts(in: ctx)
                .allSatisfy { !$0.isTemplate }
        )
    }

    func testTemplatesReturnsOnlyTemplates() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer(name: "Trainer")
        ctx.makeTemplate(
            name: "Push Day",
            for: trainer
        )
        ctx.makeTemplate(
            name: "Pull Day",
            for: trainer
        )
        ctx.makeWorkout(
            for: trainer,
            date: .now,
            isCompleted: false
        )

        let templates = trainer.templates(in: ctx)
        XCTAssertEqual(templates.count, 2)
        XCTAssertTrue(templates.allSatisfy { $0.isTemplate })
    }

    func testInstantiateTemplateClones() throws {
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

        let template = ctx.makeTemplate(
            name: "Push Day",
            for: trainer
        )
        let group = ctx.makeGroup(
            in: template,
            order: 0,
            isSuperset: false
        )
        ctx.makeSet(
            in: group,
            exercise: bench,
            order: 0,
            weight: 135,
            reps: 10,
            isCompleted: false,
            completedAt: nil
        )
        ctx.makeSet(
            in: group,
            exercise: bench,
            order: 1,
            weight: 155,
            reps: 8,
            isCompleted: false,
            completedAt: nil
        )

        let workout = ctx.instantiateTemplate(template, for: trainee)

        XCTAssertFalse(workout.isTemplate)
        XCTAssertFalse(workout.isCompleted(in: ctx))
        let groups = workout.sortedGroups(in: ctx)
        XCTAssertEqual(groups.count, 1)
        let sets = groups[0].sortedSets(in: ctx)
        XCTAssertEqual(sets.count, 2)
        XCTAssertEqual(sets[0].weight, 135)
        XCTAssertEqual(sets[0].reps, 10)
        XCTAssertEqual(sets[1].weight, 155)
        XCTAssertEqual(sets[1].reps, 8)
        XCTAssertEqual(sets[0].exercise(in: ctx)?.id, bench.id)
    }

    func testClonedUUIDsAreFreshAndSetsUncompleted() throws {
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

        let template = ctx.makeTemplate(
            name: "Push Day",
            for: trainer
        )
        let group = ctx.makeGroup(
            in: template,
            order: 0,
            isSuperset: false
        )
        let templateSet = ctx.makeSet(
            in: group,
            exercise: bench,
            order: 0,
            weight: 135,
            reps: 10,
            isCompleted: false,
            completedAt: nil
        )

        let workout = ctx.instantiateTemplate(template, for: trainee)

        XCTAssertNotEqual(workout.id, template.id)
        let clonedGroup = workout.groups(in: ctx).first!
        XCTAssertNotEqual(clonedGroup.id, group.id)
        let clonedSet = clonedGroup.sets(in: ctx).first!
        XCTAssertNotEqual(clonedSet.id, templateSet.id)
        XCTAssertFalse(clonedSet.isCompleted(in: ctx))
        XCTAssertNil(clonedSet.completedAt(in: ctx))
    }

    func testClonedWorkoutLinkedViaJoinTable() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer(name: "Trainer")
        let trainee = ctx.makeTrainee(
            name: "Trainee",
            trainer: trainer
        )
        let template = ctx.makeTemplate(
            name: "Push Day",
            for: trainer
        )

        let workout = ctx.instantiateTemplate(template, for: trainee)

        XCTAssertEqual(workout.template(in: ctx)?.id, template.id)
    }

    func testModifyTemplateAfterCloneDoesNotAffectClone() throws {
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

        let template = ctx.makeTemplate(
            name: "Push Day",
            for: trainer
        )
        let group = ctx.makeGroup(
            in: template,
            order: 0,
            isSuperset: false
        )
        ctx.makeSet(
            in: group,
            exercise: bench,
            order: 0,
            weight: 135,
            reps: 10,
            isCompleted: false,
            completedAt: nil
        )

        let workout = ctx.instantiateTemplate(
            template,
            for: trainee
        )

        // Modify template after clone
        ctx.makeSet(
            in: group,
            exercise: bench,
            order: 1,
            weight: 185,
            reps: 5,
            isCompleted: false,
            completedAt: nil
        )

        // Clone should be unchanged
        let clonedSets = workout.groups(in: ctx).first!.sets(in: ctx)
        XCTAssertEqual(clonedSets.count, 1)
        XCTAssertEqual(template.groups(in: ctx).first!.sets(in: ctx).count, 2)
    }

    func testDeleteTemplateDoesNotAffectInstantiatedWorkout() throws {
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

        let template = ctx.makeTemplate(
            name: "Push Day",
            for: trainer
        )
        let group = ctx.makeGroup(
            in: template,
            order: 0,
            isSuperset: false
        )
        ctx.makeSet(
            in: group,
            exercise: bench,
            order: 0,
            weight: 135,
            reps: 10,
            isCompleted: false,
            completedAt: nil
        )

        let workout = ctx.instantiateTemplate(template, for: trainee)
        let workoutId = workout.id

        ctx.deleteWorkout(template)

        // Workout should survive
        let remaining = trainee.activeWorkouts(in: ctx)
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.id, workoutId)
    }

    func testMultipleInstantiationsAreIndependent() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer(name: "Trainer")
        let bench = ctx.makeExercise(
            name: "Bench",
            trainer: trainer
        )
        let trainee1 = ctx.makeTrainee(
            name: "Alex",
            trainer: trainer
        )
        let trainee2 = ctx.makeTrainee(
            name: "Jamie",
            trainer: trainer
        )

        let template = ctx.makeTemplate(
            name: "Push Day",
            for: trainer
        )
        let group = ctx.makeGroup(
            in: template,
            order: 0,
            isSuperset: false
        )
        ctx.makeSet(
            in: group,
            exercise: bench,
            order: 0,
            weight: 135,
            reps: 10,
            isCompleted: false,
            completedAt: nil
        )

        let workout1 = ctx.instantiateTemplate(template, for: trainee1)
        let workout2 = ctx.instantiateTemplate(template, for: trainee2)

        XCTAssertNotEqual(workout1.id, workout2.id)

        // Complete a set in workout1 — workout2 unaffected
        let set1 = workout1.groups(in: ctx).first!.sets(in: ctx).first!
        ctx.insert(SetCompletions(setId: set1.id, completedAt: .now))

        let set2 = workout2.groups(in: ctx).first!.sets(in: ctx).first!
        XCTAssertFalse(set2.isCompleted(in: ctx))
    }
}
