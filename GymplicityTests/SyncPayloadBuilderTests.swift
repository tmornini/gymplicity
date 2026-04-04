import XCTest
import SwiftData
@testable import Gymplicity

@MainActor final class SyncPayloadBuilderTests: XCTestCase {

    func testPayloadIncludesBothIdentities() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer(name: "Coach")
        let trainee = ctx.makeTrainee(name: "Alex", trainer: trainer)

        let payload = SyncPayloadBuilder.build(
            localIdentity: trainer,
            pairedIdentity: trainee,
            context: ctx
        )

        XCTAssertEqual(payload.identities.count, 2)
        let ids = Set(payload.identities.map(\.id))
        XCTAssert(ids.contains(trainer.id))
        XCTAssert(ids.contains(trainee.id))
    }

    func testPayloadIncludesTrainerExercises() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer(name: "Trainer")
        let trainee = ctx.makeTrainee(
            name: "Trainee",
            trainer: trainer
        )
        ctx.makeExercise(name: "Bench", trainer: trainer)
        ctx.makeExercise(name: "Squat", trainer: trainer)

        let payload = SyncPayloadBuilder.build(
            localIdentity: trainer,
            pairedIdentity: trainee,
            context: ctx
        )

        XCTAssertEqual(payload.exercises.count, 2)
        let names = Set(payload.exercises.map(\.name))
        XCTAssert(names.contains("Bench"))
        XCTAssert(names.contains("Squat"))
    }

    func testPayloadIncludesAllTraineeWorkouts() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer(name: "Trainer")
        let trainee = ctx.makeTrainee(
            name: "Trainee",
            trainer: trainer
        )
        ctx.makeWorkout(                              // active
            for: trainee,
            date: .now,
            isCompleted: false
        )
        ctx.makeWorkout(                           // completed
            for: trainee,
            date: .now,
            isCompleted: true
        )

        let payload = SyncPayloadBuilder.build(
            localIdentity: trainee,
            pairedIdentity: trainer,
            context: ctx
        )

        XCTAssertEqual(payload.workouts.count, 2)
    }

    func testPayloadIncludesTrainerTemplatesOnly() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer(name: "Trainer")
        let trainee = ctx.makeTrainee(
            name: "Trainee",
            trainer: trainer
        )
        ctx.makeTemplate(name: "Push Day", for: trainer)
        // trainer's personal workout -- should be excluded
        ctx.makeWorkout(
            for: trainer,
            date: .now,
            isCompleted: false
        )

        let payload = SyncPayloadBuilder.build(
            localIdentity: trainer,
            pairedIdentity: trainee,
            context: ctx
        )

        // Only trainee's 0 workouts + trainer's 1 template
        let templateWorkouts = payload.workouts.filter(\.isTemplate)
        let nonTemplateWorkouts = payload.workouts.filter { !$0.isTemplate }
        XCTAssertEqual(templateWorkouts.count, 1)
        XCTAssertEqual(nonTemplateWorkouts.count, 0)
    }

    func testPayloadIncludesTemplateInstancesJoins() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer(name: "Trainer")
        let trainee = ctx.makeTrainee(
            name: "Trainee",
            trainer: trainer
        )
        let template = ctx.makeTemplate(name: "Push", for: trainer)
        let workout = ctx.instantiateTemplate(template, for: trainee)

        let payload = SyncPayloadBuilder.build(
            localIdentity: trainer,
            pairedIdentity: trainee,
            context: ctx
        )

        XCTAssertFalse(payload.templateInstanceJoins.isEmpty)
        let tiJoin = payload.templateInstanceJoins.first {
            $0.templateId == template.id && $0.workoutId == workout.id
        }
        XCTAssertNotNil(tiJoin)
    }

    func testPayloadIncludesGroupsSetsAndExerciseLinks() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer(name: "Trainer")
        let trainee = ctx.makeTrainee(
            name: "Trainee",
            trainer: trainer
        )
        let bench = ctx.makeExercise(
            name: "Bench",
            trainer: trainer
        )
        let workout = ctx.makeWorkout(
            for: trainee,
            date: .now,
            isCompleted: false
        )
        let group = ctx.makeGroup(
            in: workout,
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

        let payload = SyncPayloadBuilder.build(
            localIdentity: trainer,
            pairedIdentity: trainee,
            context: ctx
        )

        XCTAssertEqual(payload.workoutGroups.count, 1)
        XCTAssertEqual(payload.sets.count, 1)
        XCTAssertEqual(payload.exerciseSetJoins.count, 1)
        XCTAssertEqual(payload.groupSetJoins.count, 1)
        XCTAssertEqual(payload.workoutGroupJoins.count, 1)
    }

    func testIdentityWorkoutsIncludesTraineeAndTrainerTemplateJoins() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer(name: "Trainer")
        let trainee = ctx.makeTrainee(
            name: "Trainee",
            trainer: trainer
        )
        ctx.makeWorkout(
            for: trainee,
            date: .now,
            isCompleted: false
        )
        ctx.makeTemplate(name: "Pull Day", for: trainer)
        // trainer's personal -- its IW join excluded
        ctx.makeWorkout(
            for: trainer,
            date: .now,
            isCompleted: false
        )

        let payload = SyncPayloadBuilder.build(
            localIdentity: trainer,
            pairedIdentity: trainee,
            context: ctx
        )

        // 1 trainee workout join + 1 trainer template join = 2
        XCTAssertEqual(payload.identityWorkouts.count, 2)
    }

    func testPayloadIncludesAliasedTraineeWorkouts() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer(name: "Trainer")
        let traineeA = ctx.makeTrainee(
            name: "Alex-A",
            trainer: trainer
        )
        let traineeB = IdentityEntity(
            name: "Alex-B",
            isTrainer: false
        )
        ctx.insert(traineeB)

        // Both identities have workouts
        ctx.makeWorkout(
            for: traineeA,
            date: .now,
            isCompleted: true
        )
        ctx.makeWorkout(
            for: traineeB,
            date: .now,
            isCompleted: true
        )

        // Create alias
        IdentityReconciliation.createAlias(
            id1: traineeA.id,
            id2: traineeB.id,
            in: ctx
        )

        let payload = SyncPayloadBuilder.build(
            localIdentity: trainer,
            pairedIdentity: traineeA,
            context: ctx
        )

        // Should include workouts from both aliased identities
        XCTAssertEqual(payload.workouts.count, 2)
        XCTAssertFalse(payload.identityAliases.isEmpty)
    }

    func testPayloadIncludesIdentityAliasRows() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer(name: "Trainer")
        let trainee = ctx.makeTrainee(
            name: "Trainee",
            trainer: trainer
        )
        let aliasId = UUID()

        IdentityReconciliation.createAlias(
            id1: trainee.id,
            id2: aliasId,
            in: ctx
        )

        let payload = SyncPayloadBuilder.build(
            localIdentity: trainer,
            pairedIdentity: trainee,
            context: ctx
        )

        XCTAssertEqual(payload.identityAliases.count, 1)
        let alias = payload.identityAliases.first!
        XCTAssert(
            (alias.identityId1 == trainee.id
                && alias.identityId2 == aliasId) ||
            (alias.identityId1 == aliasId && alias.identityId2 == trainee.id)
        )
    }

    func testDeltaProducesEmptyJoinArrays() throws {
        let senderId = UUID()
        let payload = SyncPayload.delta(
            senderIdentityId: senderId,
            identities: [
                IdentityDTO(
                    id: senderId,
                    name: "Test",
                    isTrainer: true
                )
            ],
            exercises: [],
            workouts: [],
            workoutGroups: [],
            sets: [],
            setCompletions: [],
            workoutCompletions: [],
            deviceSyncEvents: []
        )

        XCTAssertEqual(payload.identities.count, 1)
        XCTAssert(payload.trainerTrainees.isEmpty)
        XCTAssert(payload.trainerExercises.isEmpty)
        XCTAssert(payload.identityWorkouts.isEmpty)
        XCTAssert(payload.workoutGroupJoins.isEmpty)
        XCTAssert(payload.groupSetJoins.isEmpty)
        XCTAssert(payload.exerciseSetJoins.isEmpty)
        XCTAssert(payload.templateInstanceJoins.isEmpty)
        XCTAssert(payload.identityAliases.isEmpty)
    }
}
