import XCTest
import SwiftData
@testable import Gymplicity

@MainActor final class SyncEngineTests: XCTestCase {

    // MARK: - Identity Authority

    func testSenderUpdatesOwnIdentityName() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer(name: "Old Name")

        let payload = makePayload(
            senderIdentityId: trainer.id,
            identities: [
                IdentityDTO(
                    id: trainer.id,
                    name: "New Name",
                    isTrainer: true
                )
            ],
            exercises: [],
            workouts: [],
            workoutGroups: [],
            sets: [],
            workoutTemplates: [],
            workoutNotes: [],
            trainerTrainees: [],
            trainerExercises: [],
            identityWorkouts: [],
            workoutGroupJoins: [],
            groupSetJoins: [],
            exerciseSetJoins: [],
            templateInstanceJoins: [],
            identityAliases: [],
            setCompletions: [],
            workoutCompletions: [],
            deviceSyncEvents: []
        )
        let result = SyncEngine.merge(payload, into: ctx)

        XCTAssertEqual(trainer.name, "New Name")
        XCTAssertEqual(result.identitiesUpdated, 1)
    }

    func testSenderCannotUpdateOtherIdentityName() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer(name: "Trainer")
        let trainee = ctx.makeTrainee(name: "Original", trainer: trainer)

        // Trainer sends payload with trainee identity changed
        let payload = makePayload(
            senderIdentityId: trainer.id,
            identities: [
                IdentityDTO(
                    id: trainer.id,
                    name: "Trainer",
                    isTrainer: true
                ),
                IdentityDTO(
                    id: trainee.id,
                    name: "Changed",
                    isTrainer: false
                )
            ],
            exercises: [],
            workouts: [],
            workoutGroups: [],
            sets: [],
            workoutTemplates: [],
            workoutNotes: [],
            trainerTrainees: [],
            trainerExercises: [],
            identityWorkouts: [],
            workoutGroupJoins: [],
            groupSetJoins: [],
            exerciseSetJoins: [],
            templateInstanceJoins: [],
            identityAliases: [],
            setCompletions: [],
            workoutCompletions: [],
            deviceSyncEvents: []
        )
        let result = SyncEngine.merge(payload, into: ctx)

        XCTAssertEqual(trainee.name, "Original")
        // only sender's own
        XCTAssertEqual(result.identitiesUpdated, 1)
    }

    func testNewIdentityInsertedFromPayload() throws {
        let ctx = try makeTestContext()
        let senderId = UUID()
        let newId = UUID()

        let payload = makePayload(
            senderIdentityId: senderId,
            identities: [
                IdentityDTO(
                    id: senderId,
                    name: "Sender",
                    isTrainer: true
                ),
                IdentityDTO(
                    id: newId,
                    name: "New Person",
                    isTrainer: false
                )
            ],
            exercises: [],
            workouts: [],
            workoutGroups: [],
            sets: [],
            workoutTemplates: [],
            workoutNotes: [],
            trainerTrainees: [],
            trainerExercises: [],
            identityWorkouts: [],
            workoutGroupJoins: [],
            groupSetJoins: [],
            exerciseSetJoins: [],
            templateInstanceJoins: [],
            identityAliases: [],
            setCompletions: [],
            workoutCompletions: [],
            deviceSyncEvents: []
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
        let trainer = ctx.makeTrainer(name: "Trainer")
        let bench = ctx.makeExercise(name: "Bnech", trainer: trainer)

        let payload = makePayload(
            senderIdentityId: trainer.id,
            identities: [
                IdentityDTO(
                    id: trainer.id,
                    name: "Trainer",
                    isTrainer: true
                )
            ],
            exercises: [
                ExerciseDTO(
                    id: bench.id,
                    name: "Bench",
                    catalogId: nil
                )
            ],
            workouts: [],
            workoutGroups: [],
            sets: [],
            workoutTemplates: [],
            workoutNotes: [],
            trainerTrainees: [],
            trainerExercises: [],
            identityWorkouts: [],
            workoutGroupJoins: [],
            groupSetJoins: [],
            exerciseSetJoins: [],
            templateInstanceJoins: [],
            identityAliases: [],
            setCompletions: [],
            workoutCompletions: [],
            deviceSyncEvents: []
        )
        let result = SyncEngine.merge(payload, into: ctx)

        XCTAssertEqual(bench.name, "Bench")
        XCTAssertEqual(result.exercisesUpdated, 1)
    }

    func testTraineeSenderCannotUpdateExerciseName() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer(name: "Trainer")
        let trainee = ctx.makeTrainee(
            name: "Trainee",
            trainer: trainer
        )
        let bench = ctx.makeExercise(name: "Bench", trainer: trainer)

        let payload = makePayload(
            senderIdentityId: trainee.id,
            identities: [
                IdentityDTO(
                    id: trainee.id,
                    name: "Trainee",
                    isTrainer: false
                )
            ],
            exercises: [
                ExerciseDTO(
                    id: bench.id,
                    name: "Renamed",
                    catalogId: nil
                )
            ],
            workouts: [],
            workoutGroups: [],
            sets: [],
            workoutTemplates: [],
            workoutNotes: [],
            trainerTrainees: [],
            trainerExercises: [],
            identityWorkouts: [],
            workoutGroupJoins: [],
            groupSetJoins: [],
            exerciseSetJoins: [],
            templateInstanceJoins: [],
            identityAliases: [],
            setCompletions: [],
            workoutCompletions: [],
            deviceSyncEvents: []
        )
        let result = SyncEngine.merge(payload, into: ctx)

        XCTAssertEqual(bench.name, "Bench")
        XCTAssertEqual(result.exercisesUpdated, 0)
    }

    func testNewExerciseInsertedRegardlessOfSenderRole() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer(name: "Trainer")
        let trainee = ctx.makeTrainee(
            name: "T",
            trainer: trainer
        )
        let newId = UUID()

        let payload = makePayload(
            senderIdentityId: trainee.id,
            identities: [
                IdentityDTO(
                    id: trainee.id,
                    name: "T",
                    isTrainer: false
                )
            ],
            exercises: [
                ExerciseDTO(
                    id: newId,
                    name: "New Exercise",
                    catalogId: nil
                )
            ],
            workouts: [],
            workoutGroups: [],
            sets: [],
            workoutTemplates: [],
            workoutNotes: [],
            trainerTrainees: [],
            trainerExercises: [],
            identityWorkouts: [],
            workoutGroupJoins: [],
            groupSetJoins: [],
            exerciseSetJoins: [],
            templateInstanceJoins: [],
            identityAliases: [],
            setCompletions: [],
            workoutCompletions: [],
            deviceSyncEvents: []
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

        // Trainee sends update
        let payload = makePayload(
            senderIdentityId: trainee.id,
            identities: [
                IdentityDTO(
                    id: trainee.id,
                    name: "Trainee",
                    isTrainer: false
                )
            ],
            exercises: [],
            workouts: [
                WorkoutDTO(
                    id: workout.id,
                    date: workout.date,
                    isTemplate: false
                )
            ],
            workoutGroups: [],
            sets: [],
            workoutTemplates: [],
            workoutNotes: [
                WorkoutNotesDTO(
                    workoutId: workout.id,
                    notes: "Great session"
                )
            ],
            trainerTrainees: [],
            trainerExercises: [],
            identityWorkouts: [],
            workoutGroupJoins: [],
            groupSetJoins: [],
            exerciseSetJoins: [],
            templateInstanceJoins: [],
            identityAliases: [],
            setCompletions: [],
            workoutCompletions: [
                WorkoutCompletionDTO(
                    workoutId: workout.id,
                    completedAt: .now
                )
            ],
            deviceSyncEvents: []
        )
        let result = SyncEngine.merge(payload, into: ctx)

        XCTAssertEqual(
            workout.notes(in: ctx),
            "Great session"
        )
        XCTAssertTrue(workout.isCompleted(in: ctx))
        XCTAssertEqual(result.workoutsUpdated, 1)
    }

    func testTrainerUpdatesTemplateWorkout() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer(name: "Trainer")
        let template = ctx.makeTemplate(name: "Push Day", for: trainer)

        let payload = makePayload(
            senderIdentityId: trainer.id,
            identities: [
                IdentityDTO(
                    id: trainer.id,
                    name: "Trainer",
                    isTrainer: true
                )
            ],
            exercises: [],
            workouts: [],
            workoutGroups: [],
            sets: [],
            workoutTemplates: [
                WorkoutTemplateDTO(
                    workoutId: template.id,
                    name: "Push A"
                )
            ],
            workoutNotes: [],
            trainerTrainees: [],
            trainerExercises: [],
            identityWorkouts: [],
            workoutGroupJoins: [],
            groupSetJoins: [],
            exerciseSetJoins: [],
            templateInstanceJoins: [],
            identityAliases: [],
            setCompletions: [],
            workoutCompletions: [],
            deviceSyncEvents: []
        )
        let result = SyncEngine.merge(payload, into: ctx)

        XCTAssertEqual(
            template.templateName(in: ctx),
            "Push A"
        )
        XCTAssertEqual(result.workoutsUpdated, 1)
    }

    func testTraineeCannotUpdateTemplateWorkout() throws {
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

        let payload = makePayload(
            senderIdentityId: trainee.id,
            identities: [
                IdentityDTO(
                    id: trainee.id,
                    name: "Trainee",
                    isTrainer: false
                )
            ],
            exercises: [],
            workouts: [],
            workoutGroups: [],
            sets: [],
            workoutTemplates: [
                WorkoutTemplateDTO(
                    workoutId: template.id,
                    name: "Hacked"
                )
            ],
            workoutNotes: [],
            trainerTrainees: [],
            trainerExercises: [],
            identityWorkouts: [],
            workoutGroupJoins: [],
            groupSetJoins: [],
            exerciseSetJoins: [],
            templateInstanceJoins: [],
            identityAliases: [],
            setCompletions: [],
            workoutCompletions: [],
            deviceSyncEvents: []
        )
        let result = SyncEngine.merge(payload, into: ctx)

        XCTAssertEqual(
            template.templateName(in: ctx),
            "Push Day"
        )
        XCTAssertEqual(result.workoutsUpdated, 0)
    }

    func testNewWorkoutInsertedFromPayload() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer(name: "Trainer")
        let trainee = ctx.makeTrainee(
            name: "T",
            trainer: trainer
        )
        let newId = UUID()

        let payload = makePayload(
            senderIdentityId: trainee.id,
            identities: [
                IdentityDTO(
                    id: trainee.id,
                    name: "T",
                    isTrainer: false
                )
            ],
            exercises: [],
            workouts: [
                WorkoutDTO(
                    id: newId,
                    date: .now,
                    isTemplate: false
                )
            ],
            workoutGroups: [],
            sets: [],
            workoutTemplates: [],
            workoutNotes: [
                WorkoutNotesDTO(
                    workoutId: newId,
                    notes: "New workout"
                )
            ],
            trainerTrainees: [],
            trainerExercises: [],
            identityWorkouts: [],
            workoutGroupJoins: [],
            groupSetJoins: [],
            exerciseSetJoins: [],
            templateInstanceJoins: [],
            identityAliases: [],
            setCompletions: [],
            workoutCompletions: [],
            deviceSyncEvents: []
        )
        let result = SyncEngine.merge(payload, into: ctx)

        XCTAssertEqual(result.workoutsInserted, 2)
        let fetched = try ctx.fetch(
            FetchDescriptor<WorkoutEntity>(
                predicate: #Predicate {
                    $0.id == newId
                }
            )
        )
        XCTAssertEqual(
            fetched.first?.notes(in: ctx),
            "New workout"
        )
    }

    // MARK: - WorkoutGroup Authority

    func testTrainerUpdatesGroupOrder() throws {
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
        let group = ctx.makeGroup(
            in: workout,
            order: 0,
            isSuperset: false
        )

        let payload = makePayload(
            senderIdentityId: trainer.id,
            identities: [
                IdentityDTO(
                    id: trainer.id,
                    name: "Trainer",
                    isTrainer: true
                )
            ],
            exercises: [],
            workouts: [],
            workoutGroups: [
                WorkoutGroupDTO(
                    id: group.id,
                    order: 2,
                    isSuperset: true
                )
            ],
            sets: [],
            workoutTemplates: [],
            workoutNotes: [],
            trainerTrainees: [],
            trainerExercises: [],
            identityWorkouts: [],
            workoutGroupJoins: [],
            groupSetJoins: [],
            exerciseSetJoins: [],
            templateInstanceJoins: [],
            identityAliases: [],
            setCompletions: [],
            workoutCompletions: [],
            deviceSyncEvents: []
        )
        let result = SyncEngine.merge(payload, into: ctx)

        XCTAssertEqual(group.order, 2)
        XCTAssertTrue(group.isSuperset)
        XCTAssertEqual(result.workoutGroupsUpdated, 1)
    }

    func testTraineeCannotUpdateGroup() throws {
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
        let group = ctx.makeGroup(
            in: workout,
            order: 0,
            isSuperset: false
        )

        let payload = makePayload(
            senderIdentityId: trainee.id,
            identities: [
                IdentityDTO(
                    id: trainee.id,
                    name: "Trainee",
                    isTrainer: false
                )
            ],
            exercises: [],
            workouts: [],
            workoutGroups: [
                WorkoutGroupDTO(
                    id: group.id,
                    order: 5,
                    isSuperset: true
                )
            ],
            sets: [],
            workoutTemplates: [],
            workoutNotes: [],
            trainerTrainees: [],
            trainerExercises: [],
            identityWorkouts: [],
            workoutGroupJoins: [],
            groupSetJoins: [],
            exerciseSetJoins: [],
            templateInstanceJoins: [],
            identityAliases: [],
            setCompletions: [],
            workoutCompletions: [],
            deviceSyncEvents: []
        )
        let result = SyncEngine.merge(payload, into: ctx)

        XCTAssertEqual(group.order, 0)
        XCTAssertFalse(group.isSuperset)
        XCTAssertEqual(result.workoutGroupsUpdated, 0)
    }

    // MARK: - Set Authority

    func testEitherSideUpdatesSet() throws {
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
        let set = ctx.makeSet(
            in: group,
            exercise: bench,
            order: 0,
            weight: 100,
            reps: 8,
            isCompleted: false,
            completedAt: nil
        )
        let now = Date.now

        // Trainer sends set update
        let payload = makePayload(
            senderIdentityId: trainer.id,
            identities: [
                IdentityDTO(
                    id: trainer.id,
                    name: "Trainer",
                    isTrainer: true
                )
            ],
            exercises: [],
            workouts: [],
            workoutGroups: [],
            sets: [
                SetDTO(
                    id: set.id,
                    order: 0,
                    weight: 135,
                    reps: 10
                )
            ],
            workoutTemplates: [],
            workoutNotes: [],
            trainerTrainees: [],
            trainerExercises: [],
            identityWorkouts: [],
            workoutGroupJoins: [],
            groupSetJoins: [],
            exerciseSetJoins: [],
            templateInstanceJoins: [],
            identityAliases: [],
            setCompletions: [
                SetCompletionDTO(
                    setId: set.id,
                    completedAt: now
                )
            ],
            workoutCompletions: [],
            deviceSyncEvents: []
        )
        let result = SyncEngine.merge(payload, into: ctx)

        XCTAssertEqual(set.weight, 135)
        XCTAssertEqual(set.reps, 10)
        XCTAssertTrue(set.isCompleted(in: ctx))
        XCTAssertEqual(result.setsUpdated, 1)
    }

    // MARK: - Join Tables

    func testNewJoinRowInserted() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer(name: "Trainer")
        let trainee = ctx.makeTrainee(
            name: "Trainee",
            trainer: trainer
        )
        let newWorkoutId = UUID()

        let payload = makePayload(
            senderIdentityId: trainer.id,
            identities: [
                IdentityDTO(
                    id: trainer.id,
                    name: "Trainer",
                    isTrainer: true
                )
            ],
            exercises: [],
            workouts: [],
            workoutGroups: [],
            sets: [],
            workoutTemplates: [],
            workoutNotes: [],
            trainerTrainees: [],
            trainerExercises: [],
            identityWorkouts: [
                IdentityWorkoutsDTO(
                    identityId: trainee.id,
                    workoutId: newWorkoutId
                )
            ],
            workoutGroupJoins: [],
            groupSetJoins: [],
            exerciseSetJoins: [],
            templateInstanceJoins: [],
            identityAliases: [],
            setCompletions: [],
            workoutCompletions: [],
            deviceSyncEvents: []
        )
        let result = SyncEngine.merge(payload, into: ctx)

        XCTAssertEqual(result.identityWorkoutsInserted, 1)
    }

    func testDuplicateJoinRowSkipped() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer(name: "Trainer")
        let trainee = ctx.makeTrainee(
            name: "Trainee",
            trainer: trainer
        )

        // TrainerTrainees join already exists from makeTrainee
        let payload = makePayload(
            senderIdentityId: trainer.id,
            identities: [
                IdentityDTO(
                    id: trainer.id,
                    name: "Trainer",
                    isTrainer: true
                )
            ],
            exercises: [],
            workouts: [],
            workoutGroups: [],
            sets: [],
            workoutTemplates: [],
            workoutNotes: [],
            trainerTrainees: [
                TrainerTraineesDTO(
                    trainerId: trainer.id,
                    traineeId: trainee.id
                )
            ],
            trainerExercises: [],
            identityWorkouts: [],
            workoutGroupJoins: [],
            groupSetJoins: [],
            exerciseSetJoins: [],
            templateInstanceJoins: [],
            identityAliases: [],
            setCompletions: [],
            workoutCompletions: [],
            deviceSyncEvents: []
        )
        let result = SyncEngine.merge(payload, into: ctx)

        XCTAssertEqual(result.trainerTraineesInserted, 0)
    }

    func testTemplateInstancesJoinInsertedAndDeduplicated() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer(name: "Trainer")
        let template = ctx.makeTemplate(name: "Push", for: trainer)
        let workoutId = UUID()

        let payload = makePayload(
            senderIdentityId: trainer.id,
            identities: [
                IdentityDTO(
                    id: trainer.id,
                    name: "Trainer",
                    isTrainer: true
                )
            ],
            exercises: [],
            workouts: [],
            workoutGroups: [],
            sets: [],
            workoutTemplates: [],
            workoutNotes: [],
            trainerTrainees: [],
            trainerExercises: [],
            identityWorkouts: [],
            workoutGroupJoins: [],
            groupSetJoins: [],
            exerciseSetJoins: [],
            templateInstanceJoins: [
                TemplateInstancesDTO(
                    templateId: template.id,
                    workoutId: workoutId
                ),
                // duplicate
                TemplateInstancesDTO(
                    templateId: template.id,
                    workoutId: workoutId
                )
            ],
            identityAliases: [],
            setCompletions: [],
            workoutCompletions: [],
            deviceSyncEvents: []
        )
        let result = SyncEngine.merge(payload, into: ctx)

        // First inserts, second is deduplicated
        XCTAssertEqual(
            result.templateInstanceJoinsInserted,
            1
        )
    }

    // MARK: - MergeResult

    func testEmptyResultSummary() {
        let result = MergeResult(
            identitiesInserted: 0,
            identitiesUpdated: 0,
            exercisesInserted: 0,
            exercisesUpdated: 0,
            workoutsInserted: 0,
            workoutsUpdated: 0,
            workoutGroupsInserted: 0,
            workoutGroupsUpdated: 0,
            setsInserted: 0,
            setsUpdated: 0,
            trainerTraineesInserted: 0,
            trainerExercisesInserted: 0,
            identityWorkoutsInserted: 0,
            workoutGroupJoinsInserted: 0,
            groupSetJoinsInserted: 0,
            exerciseSetJoinsInserted: 0,
            templateInstanceJoinsInserted: 0,
            identityAliasesInserted: 0,
            setCompletionsInserted: 0,
            workoutCompletionsInserted: 0,
            deviceSyncEventsInserted: 0
        )

        XCTAssertEqual(result.summary, "Already up to date")
        XCTAssertEqual(result.totalInserted, 0)
        XCTAssertEqual(result.totalUpdated, 0)
    }

    // MARK: - IdentityAliases

    func testIdentityAliasesInsertedFromPayload() throws {
        let ctx = try makeTestContext()
        let senderId = UUID()
        let id1 = UUID()
        let id2 = UUID()

        let payload = makePayload(
            senderIdentityId: senderId,
            identities: [
                IdentityDTO(
                    id: senderId,
                    name: "Sender",
                    isTrainer: false
                )
            ],
            exercises: [],
            workouts: [],
            workoutGroups: [],
            sets: [],
            workoutTemplates: [],
            workoutNotes: [],
            trainerTrainees: [],
            trainerExercises: [],
            identityWorkouts: [],
            workoutGroupJoins: [],
            groupSetJoins: [],
            exerciseSetJoins: [],
            templateInstanceJoins: [],
            identityAliases: [
                IdentityAliasesDTO(
                    identityId1: id1,
                    identityId2: id2
                )
            ],
            setCompletions: [],
            workoutCompletions: [],
            deviceSyncEvents: []
        )
        let result = SyncEngine.merge(payload, into: ctx)

        XCTAssertEqual(result.identityAliasesInserted, 1)
        let rows = try ctx.fetch(
            FetchDescriptor<IdentityAliases>()
        )
        XCTAssertEqual(rows.count, 1)
    }

    func testDuplicateIdentityAliasSkipped() throws {
        let ctx = try makeTestContext()
        let senderId = UUID()
        let id1 = UUID()
        let id2 = UUID()

        // Insert first
        ctx.insert(IdentityAliases(identityId1: id1, identityId2: id2))

        let payload = makePayload(
            senderIdentityId: senderId,
            identities: [
                IdentityDTO(
                    id: senderId,
                    name: "Sender",
                    isTrainer: false
                )
            ],
            exercises: [],
            workouts: [],
            workoutGroups: [],
            sets: [],
            workoutTemplates: [],
            workoutNotes: [],
            trainerTrainees: [],
            trainerExercises: [],
            identityWorkouts: [],
            workoutGroupJoins: [],
            groupSetJoins: [],
            exerciseSetJoins: [],
            templateInstanceJoins: [],
            identityAliases: [
                IdentityAliasesDTO(
                    identityId1: id1,
                    identityId2: id2
                )
            ],
            setCompletions: [],
            workoutCompletions: [],
            deviceSyncEvents: []
        )
        let result = SyncEngine.merge(payload, into: ctx)

        XCTAssertEqual(result.identityAliasesInserted, 0)
    }

    func testReverseOrderAliasSkipped() throws {
        let ctx = try makeTestContext()
        let senderId = UUID()
        let id1 = UUID()
        let id2 = UUID()

        // Insert in one order
        ctx.insert(IdentityAliases(identityId1: id1, identityId2: id2))

        // Payload has reverse order
        let payload = makePayload(
            senderIdentityId: senderId,
            identities: [
                IdentityDTO(
                    id: senderId,
                    name: "Sender",
                    isTrainer: false
                )
            ],
            exercises: [],
            workouts: [],
            workoutGroups: [],
            sets: [],
            workoutTemplates: [],
            workoutNotes: [],
            trainerTrainees: [],
            trainerExercises: [],
            identityWorkouts: [],
            workoutGroupJoins: [],
            groupSetJoins: [],
            exerciseSetJoins: [],
            templateInstanceJoins: [],
            identityAliases: [
                IdentityAliasesDTO(
                    identityId1: id2,
                    identityId2: id1
                )
            ],
            setCompletions: [],
            workoutCompletions: [],
            deviceSyncEvents: []
        )
        let result = SyncEngine.merge(payload, into: ctx)

        XCTAssertEqual(result.identityAliasesInserted, 0)
        let rows = try ctx.fetch(
            FetchDescriptor<IdentityAliases>()
        )
        XCTAssertEqual(rows.count, 1)
    }

    // MARK: - MergeResult

    func testMixedInsertsAndUpdatesSummary() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer(name: "Trainer")
        let bench = ctx.makeExercise(name: "Bnech", trainer: trainer)
        let newExerciseId = UUID()

        let payload = makePayload(
            senderIdentityId: trainer.id,
            identities: [
                IdentityDTO(
                    id: trainer.id,
                    name: "Trainer",
                    isTrainer: true
                )
            ],
            exercises: [
                // update
                ExerciseDTO(
                    id: bench.id,
                    name: "Bench",
                    catalogId: nil
                ),
                // insert
                ExerciseDTO(
                    id: newExerciseId,
                    name: "Squat",
                    catalogId: nil
                )
            ],
            workouts: [],
            workoutGroups: [],
            sets: [],
            workoutTemplates: [],
            workoutNotes: [],
            trainerTrainees: [],
            trainerExercises: [],
            identityWorkouts: [],
            workoutGroupJoins: [],
            groupSetJoins: [],
            exerciseSetJoins: [],
            templateInstanceJoins: [],
            identityAliases: [],
            setCompletions: [],
            workoutCompletions: [],
            deviceSyncEvents: []
        )
        let result = SyncEngine.merge(payload, into: ctx)

        XCTAssertEqual(result.exercisesUpdated, 1)
        XCTAssertEqual(result.exercisesInserted, 1)
        XCTAssertEqual(result.totalInserted, 1)
        // 1 identity update + 1 exercise update
        XCTAssertEqual(result.totalUpdated, 2)
        XCTAssert(
            result.summary.contains("2 exercises")
        )
    }
}
