import XCTest
import SwiftData
@testable import Gymplicity

final class SyncEngineTests: XCTestCase {

    // MARK: - Identity Authority

    func testSenderUpdatesOwnIdentityName() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer(name: "Old Name")

        let payload = makePayload(
            senderIdentityId: trainer.id,
            identities: [IdentityDTO(id: trainer.id, name: "New Name", isTrainer: true)]
        )
        let result = SyncEngine.merge(payload, into: ctx)

        XCTAssertEqual(trainer.name, "New Name")
        XCTAssertEqual(result.identitiesUpdated, 1)
    }

    func testSenderCannotUpdateOtherIdentityName() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer(name: "Trainer")
        let trainee = ctx.makeTrainee(name: "Original", trainer: trainer)

        // Trainer sends payload containing trainee identity with changed name
        let payload = makePayload(
            senderIdentityId: trainer.id,
            identities: [
                IdentityDTO(id: trainer.id, name: "Trainer", isTrainer: true),
                IdentityDTO(id: trainee.id, name: "Changed", isTrainer: false)
            ]
        )
        let result = SyncEngine.merge(payload, into: ctx)

        XCTAssertEqual(trainee.name, "Original")
        XCTAssertEqual(result.identitiesUpdated, 1) // only sender's own
    }

    func testNewIdentityInsertedFromPayload() throws {
        let ctx = try makeTestContext()
        let senderId = UUID()
        let newId = UUID()

        let payload = makePayload(
            senderIdentityId: senderId,
            identities: [
                IdentityDTO(id: senderId, name: "Sender", isTrainer: true),
                IdentityDTO(id: newId, name: "New Person", isTrainer: false)
            ]
        )
        let result = SyncEngine.merge(payload, into: ctx)

        XCTAssertEqual(result.identitiesInserted, 2)
        let fetched = try ctx.fetch(FetchDescriptor<IdentityEntity>(
            predicate: #Predicate { $0.id == newId }
        ))
        XCTAssertEqual(fetched.first?.name, "New Person")
    }

    // MARK: - Exercise Authority

    func testTrainerSenderUpdatesExerciseName() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        let bench = ctx.makeExercise(name: "Bnech", trainer: trainer)

        let payload = makePayload(
            senderIdentityId: trainer.id,
            identities: [IdentityDTO(id: trainer.id, name: "Trainer", isTrainer: true)],
            exercises: [ExerciseDTO(id: bench.id, name: "Bench")]
        )
        let result = SyncEngine.merge(payload, into: ctx)

        XCTAssertEqual(bench.name, "Bench")
        XCTAssertEqual(result.exercisesUpdated, 1)
    }

    func testTraineeSenderCannotUpdateExerciseName() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        let trainee = ctx.makeTrainee(trainer: trainer)
        let bench = ctx.makeExercise(name: "Bench", trainer: trainer)

        let payload = makePayload(
            senderIdentityId: trainee.id,
            identities: [IdentityDTO(id: trainee.id, name: "Trainee", isTrainer: false)],
            exercises: [ExerciseDTO(id: bench.id, name: "Renamed")]
        )
        let result = SyncEngine.merge(payload, into: ctx)

        XCTAssertEqual(bench.name, "Bench")
        XCTAssertEqual(result.exercisesUpdated, 0)
    }

    func testNewExerciseInsertedRegardlessOfSenderRole() throws {
        let ctx = try makeTestContext()
        let trainee = ctx.makeTrainee(name: "T", trainer: ctx.makeTrainer())
        let newId = UUID()

        let payload = makePayload(
            senderIdentityId: trainee.id,
            identities: [IdentityDTO(id: trainee.id, name: "T", isTrainer: false)],
            exercises: [ExerciseDTO(id: newId, name: "New Exercise")]
        )
        let result = SyncEngine.merge(payload, into: ctx)

        XCTAssertEqual(result.exercisesInserted, 1)
        let fetched = try ctx.fetch(FetchDescriptor<ExerciseEntity>(
            predicate: #Predicate { $0.id == newId }
        ))
        XCTAssertEqual(fetched.first?.name, "New Exercise")
    }

    // MARK: - Workout Authority

    func testEitherSideUpdatesNonTemplateWorkout() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        let trainee = ctx.makeTrainee(trainer: trainer)
        let workout = ctx.makeWorkout(for: trainee)

        // Trainee sends update
        let payload = makePayload(
            senderIdentityId: trainee.id,
            identities: [IdentityDTO(id: trainee.id, name: "Trainee", isTrainer: false)],
            workouts: [WorkoutDTO(id: workout.id, date: workout.date, notes: "Great session",
                                  isCompleted: true, isTemplate: false, templateName: nil)]
        )
        let result = SyncEngine.merge(payload, into: ctx)

        XCTAssertEqual(workout.notes, "Great session")
        XCTAssertTrue(workout.isCompleted)
        XCTAssertEqual(result.workoutsUpdated, 1)
    }

    func testTrainerUpdatesTemplateWorkout() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        let template = ctx.makeTemplate(name: "Push Day", for: trainer)

        let payload = makePayload(
            senderIdentityId: trainer.id,
            identities: [IdentityDTO(id: trainer.id, name: "Trainer", isTrainer: true)],
            workouts: [WorkoutDTO(id: template.id, date: template.date, notes: nil,
                                  isCompleted: false, isTemplate: true, templateName: "Push A")]
        )
        let result = SyncEngine.merge(payload, into: ctx)

        XCTAssertEqual(template.templateName, "Push A")
        XCTAssertEqual(result.workoutsUpdated, 1)
    }

    func testTraineeCannotUpdateTemplateWorkout() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        let trainee = ctx.makeTrainee(trainer: trainer)
        let template = ctx.makeTemplate(name: "Push Day", for: trainer)

        let payload = makePayload(
            senderIdentityId: trainee.id,
            identities: [IdentityDTO(id: trainee.id, name: "Trainee", isTrainer: false)],
            workouts: [WorkoutDTO(id: template.id, date: template.date, notes: nil,
                                  isCompleted: false, isTemplate: true, templateName: "Hacked")]
        )
        let result = SyncEngine.merge(payload, into: ctx)

        XCTAssertEqual(template.templateName, "Push Day")
        XCTAssertEqual(result.workoutsUpdated, 0)
    }

    func testNewWorkoutInsertedFromPayload() throws {
        let ctx = try makeTestContext()
        let trainee = ctx.makeTrainee(name: "T", trainer: ctx.makeTrainer())
        let newId = UUID()

        let payload = makePayload(
            senderIdentityId: trainee.id,
            identities: [IdentityDTO(id: trainee.id, name: "T", isTrainer: false)],
            workouts: [WorkoutDTO(id: newId, date: .now, notes: "New workout",
                                  isCompleted: false, isTemplate: false, templateName: nil)]
        )
        let result = SyncEngine.merge(payload, into: ctx)

        XCTAssertEqual(result.workoutsInserted, 1)
        let fetched = try ctx.fetch(FetchDescriptor<WorkoutEntity>(
            predicate: #Predicate { $0.id == newId }
        ))
        XCTAssertEqual(fetched.first?.notes, "New workout")
    }

    // MARK: - WorkoutGroup Authority

    func testTrainerUpdatesGroupOrder() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        let trainee = ctx.makeTrainee(trainer: trainer)
        let workout = ctx.makeWorkout(for: trainee)
        let group = ctx.makeGroup(in: workout, order: 0)

        let payload = makePayload(
            senderIdentityId: trainer.id,
            identities: [IdentityDTO(id: trainer.id, name: "Trainer", isTrainer: true)],
            workoutGroups: [WorkoutGroupDTO(id: group.id, order: 2, isSuperset: true)]
        )
        let result = SyncEngine.merge(payload, into: ctx)

        XCTAssertEqual(group.order, 2)
        XCTAssertTrue(group.isSuperset)
        XCTAssertEqual(result.workoutGroupsUpdated, 1)
    }

    func testTraineeCannotUpdateGroup() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        let trainee = ctx.makeTrainee(trainer: trainer)
        let workout = ctx.makeWorkout(for: trainee)
        let group = ctx.makeGroup(in: workout, order: 0)

        let payload = makePayload(
            senderIdentityId: trainee.id,
            identities: [IdentityDTO(id: trainee.id, name: "Trainee", isTrainer: false)],
            workoutGroups: [WorkoutGroupDTO(id: group.id, order: 5, isSuperset: true)]
        )
        let result = SyncEngine.merge(payload, into: ctx)

        XCTAssertEqual(group.order, 0)
        XCTAssertFalse(group.isSuperset)
        XCTAssertEqual(result.workoutGroupsUpdated, 0)
    }

    // MARK: - Set Authority

    func testEitherSideUpdatesSet() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        let trainee = ctx.makeTrainee(trainer: trainer)
        let bench = ctx.makeExercise(name: "Bench", trainer: trainer)
        let workout = ctx.makeWorkout(for: trainee)
        let group = ctx.makeGroup(in: workout, order: 0)
        let set = ctx.makeSet(in: group, exercise: bench, order: 0, weight: 100, reps: 8)
        let now = Date.now

        // Trainer sends set update
        let payload = makePayload(
            senderIdentityId: trainer.id,
            identities: [IdentityDTO(id: trainer.id, name: "Trainer", isTrainer: true)],
            sets: [SetDTO(id: set.id, order: 0, weight: 135, reps: 10, isCompleted: true, completedAt: now)]
        )
        let result = SyncEngine.merge(payload, into: ctx)

        XCTAssertEqual(set.weight, 135)
        XCTAssertEqual(set.reps, 10)
        XCTAssertTrue(set.isCompleted)
        XCTAssertEqual(result.setsUpdated, 1)
    }

    // MARK: - Join Tables

    func testNewJoinRowInserted() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        let trainee = ctx.makeTrainee(trainer: trainer)
        let newWorkoutId = UUID()

        let payload = makePayload(
            senderIdentityId: trainer.id,
            identities: [IdentityDTO(id: trainer.id, name: "Trainer", isTrainer: true)],
            identityWorkouts: [IdentityWorkoutsDTO(identityId: trainee.id, workoutId: newWorkoutId)]
        )
        let result = SyncEngine.merge(payload, into: ctx)

        XCTAssertEqual(result.identityWorkoutsInserted, 1)
    }

    func testDuplicateJoinRowSkipped() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        let trainee = ctx.makeTrainee(trainer: trainer)

        // TrainerTrainees join already exists from makeTrainee
        let payload = makePayload(
            senderIdentityId: trainer.id,
            identities: [IdentityDTO(id: trainer.id, name: "Trainer", isTrainer: true)],
            trainerTrainees: [TrainerTraineesDTO(trainerId: trainer.id, traineeId: trainee.id)]
        )
        let result = SyncEngine.merge(payload, into: ctx)

        XCTAssertEqual(result.trainerTraineesInserted, 0)
    }

    func testTemplateInstancesJoinInsertedAndDeduplicated() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        let template = ctx.makeTemplate(name: "Push", for: trainer)
        let workoutId = UUID()

        let payload = makePayload(
            senderIdentityId: trainer.id,
            identities: [IdentityDTO(id: trainer.id, name: "Trainer", isTrainer: true)],
            templateInstanceJoins: [
                TemplateInstancesDTO(templateId: template.id, workoutId: workoutId),
                TemplateInstancesDTO(templateId: template.id, workoutId: workoutId) // duplicate
            ]
        )
        let result = SyncEngine.merge(payload, into: ctx)

        // First one inserts, second one is deduplicated
        XCTAssertEqual(result.templateInstanceJoinsInserted, 1)
    }

    // MARK: - MergeResult

    func testEmptyPayloadSummary() throws {
        let ctx = try makeTestContext()
        let senderId = UUID()

        let payload = makePayload(senderIdentityId: senderId)
        let result = SyncEngine.merge(payload, into: ctx)

        XCTAssertEqual(result.summary, "Already up to date")
        XCTAssertEqual(result.totalInserted, 0)
        XCTAssertEqual(result.totalUpdated, 0)
    }

    func testMixedInsertsAndUpdatesSummary() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        let bench = ctx.makeExercise(name: "Bnech", trainer: trainer)
        let newExerciseId = UUID()

        let payload = makePayload(
            senderIdentityId: trainer.id,
            identities: [IdentityDTO(id: trainer.id, name: "Trainer", isTrainer: true)],
            exercises: [
                ExerciseDTO(id: bench.id, name: "Bench"),        // update
                ExerciseDTO(id: newExerciseId, name: "Squat")    // insert
            ]
        )
        let result = SyncEngine.merge(payload, into: ctx)

        XCTAssertEqual(result.exercisesUpdated, 1)
        XCTAssertEqual(result.exercisesInserted, 1)
        XCTAssertEqual(result.totalInserted, 1)
        XCTAssertEqual(result.totalUpdated, 2) // 1 identity update + 1 exercise update
        XCTAssert(result.summary.contains("2 exercises"))
    }
}
