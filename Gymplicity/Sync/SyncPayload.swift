import Foundation
import SwiftData

// MARK: - DTOs

struct IdentityDTO: Codable {
    let id: UUID
    let name: String
    let isTrainer: Bool
}

struct ExerciseDTO: Codable {
    let id: UUID
    let name: String
}

struct WorkoutDTO: Codable {
    let id: UUID
    let date: Date
    let notes: String?
    let isCompleted: Bool
    let isTemplate: Bool
    let templateName: String?
}

struct WorkoutGroupDTO: Codable {
    let id: UUID
    let order: Int
    let isSuperset: Bool
}

struct SetDTO: Codable {
    let id: UUID
    let order: Int
    let weight: Double
    let reps: Int
    let isCompleted: Bool
    let completedAt: Date?
}

struct TrainerTraineesDTO: Codable {
    let trainerId: UUID
    let traineeId: UUID
}

struct TrainerExercisesDTO: Codable {
    let trainerId: UUID
    let exerciseId: UUID
}

struct IdentityWorkoutsDTO: Codable {
    let identityId: UUID
    let workoutId: UUID
}

struct WorkoutGroupsDTO: Codable {
    let workoutId: UUID
    let groupId: UUID
}

struct GroupSetsDTO: Codable {
    let groupId: UUID
    let setId: UUID
}

struct ExerciseSetsDTO: Codable {
    let exerciseId: UUID
    let setId: UUID
}

struct TemplateInstancesDTO: Codable {
    let templateId: UUID
    let workoutId: UUID
}

// MARK: - Payload Envelope

struct SyncPayload: Codable {
    let version: Int
    let senderIdentityId: UUID

    // Entities
    let identities: [IdentityDTO]
    let exercises: [ExerciseDTO]
    let workouts: [WorkoutDTO]
    let workoutGroups: [WorkoutGroupDTO]
    let sets: [SetDTO]

    // Join tables
    let trainerTrainees: [TrainerTraineesDTO]
    let trainerExercises: [TrainerExercisesDTO]
    let identityWorkouts: [IdentityWorkoutsDTO]
    let workoutGroupJoins: [WorkoutGroupsDTO]
    let groupSetJoins: [GroupSetsDTO]
    let exerciseSetJoins: [ExerciseSetsDTO]
    let templateInstanceJoins: [TemplateInstancesDTO]

    /// Creates a delta payload containing only the specified changed entities.
    /// Empty arrays default for entity types not included in this delta.
    static func delta(
        senderIdentityId: UUID,
        identities: [IdentityDTO] = [],
        exercises: [ExerciseDTO] = [],
        workouts: [WorkoutDTO] = [],
        workoutGroups: [WorkoutGroupDTO] = [],
        sets: [SetDTO] = []
    ) -> SyncPayload {
        SyncPayload(
            version: 1,
            senderIdentityId: senderIdentityId,
            identities: identities,
            exercises: exercises,
            workouts: workouts,
            workoutGroups: workoutGroups,
            sets: sets,
            trainerTrainees: [],
            trainerExercises: [],
            identityWorkouts: [],
            workoutGroupJoins: [],
            groupSetJoins: [],
            exerciseSetJoins: [],
            templateInstanceJoins: []
        )
    }
}

// MARK: - Sync Message

enum SyncMessage: Codable {
    case pairingRequest(traineeUUID: UUID, trainerName: String)
    case pairingAccepted
    case entityUpdates(SyncPayload)
}

// MARK: - Entity → DTO Extensions

extension IdentityEntity {
    func toDTO() -> IdentityDTO {
        IdentityDTO(id: id, name: name, isTrainer: isTrainer)
    }
}

extension ExerciseEntity {
    func toDTO() -> ExerciseDTO {
        ExerciseDTO(id: id, name: name)
    }
}

extension WorkoutEntity {
    func toDTO() -> WorkoutDTO {
        WorkoutDTO(
            id: id, date: date, notes: notes, isCompleted: isCompleted,
            isTemplate: isTemplate, templateName: templateName
        )
    }
}

extension WorkoutGroupEntity {
    func toDTO() -> WorkoutGroupDTO {
        WorkoutGroupDTO(id: id, order: order, isSuperset: isSuperset)
    }
}

extension SetEntity {
    func toDTO() -> SetDTO {
        SetDTO(
            id: id, order: order, weight: weight, reps: reps,
            isCompleted: isCompleted, completedAt: completedAt
        )
    }
}

extension TrainerTrainees {
    func toDTO() -> TrainerTraineesDTO {
        TrainerTraineesDTO(trainerId: trainerId, traineeId: traineeId)
    }
}

extension TrainerExercises {
    func toDTO() -> TrainerExercisesDTO {
        TrainerExercisesDTO(trainerId: trainerId, exerciseId: exerciseId)
    }
}

extension IdentityWorkouts {
    func toDTO() -> IdentityWorkoutsDTO {
        IdentityWorkoutsDTO(identityId: identityId, workoutId: workoutId)
    }
}

extension WorkoutGroups {
    func toDTO() -> WorkoutGroupsDTO {
        WorkoutGroupsDTO(workoutId: workoutId, groupId: groupId)
    }
}

extension GroupSets {
    func toDTO() -> GroupSetsDTO {
        GroupSetsDTO(groupId: groupId, setId: setId)
    }
}

extension ExerciseSets {
    func toDTO() -> ExerciseSetsDTO {
        ExerciseSetsDTO(exerciseId: exerciseId, setId: setId)
    }
}

extension TemplateInstances {
    func toDTO() -> TemplateInstancesDTO {
        TemplateInstancesDTO(templateId: templateId, workoutId: workoutId)
    }
}

// MARK: - Payload Builder

struct SyncPayloadBuilder {
    /// Builds a complete sync payload for the trainer-trainee pair.
    /// Both sides send everything relevant to their relationship.
    static func build(
        localIdentity: IdentityEntity,
        pairedIdentity: IdentityEntity,
        context: ModelContext
    ) -> SyncPayload {
        let trainer: IdentityEntity
        let trainee: IdentityEntity
        if localIdentity.isTrainer {
            trainer = localIdentity
            trainee = pairedIdentity
        } else {
            trainer = pairedIdentity
            trainee = localIdentity
        }

        // 1. Both identities
        let identities = [trainer.toDTO(), trainee.toDTO()]

        // 2. TrainerTrainees join
        let trainerId = trainer.id
        let traineeId = trainee.id
        let ttJoins = (try? context.fetch(FetchDescriptor<TrainerTrainees>(
            predicate: #Predicate { $0.trainerId == trainerId && $0.traineeId == traineeId }
        ))) ?? []

        // 3. All exercises via TrainerExercises for the trainer
        let teJoins = (try? context.fetch(FetchDescriptor<TrainerExercises>(
            predicate: #Predicate { $0.trainerId == trainerId }
        ))) ?? []
        let exerciseIds = teJoins.map(\.exerciseId)
        let exercises = (try? context.fetch(FetchDescriptor<ExerciseEntity>(
            predicate: #Predicate { exerciseIds.contains($0.id) }
        ))) ?? []

        // 4. Trainee's workouts (all — completed, active, templates)
        let iwJoinsTrainee = (try? context.fetch(FetchDescriptor<IdentityWorkouts>(
            predicate: #Predicate { $0.identityId == traineeId }
        ))) ?? []

        // 5. Trainer's templates
        let iwJoinsTrainer = (try? context.fetch(FetchDescriptor<IdentityWorkouts>(
            predicate: #Predicate { $0.identityId == trainerId }
        ))) ?? []

        // Collect all workout IDs
        var allWorkoutIds = Set(iwJoinsTrainee.map(\.workoutId))
        let trainerWorkoutIds = Set(iwJoinsTrainer.map(\.workoutId))

        // Fetch all trainer workouts to filter templates
        let trainerWIds = Array(trainerWorkoutIds)
        let trainerWorkouts = (try? context.fetch(FetchDescriptor<WorkoutEntity>(
            predicate: #Predicate { trainerWIds.contains($0.id) }
        ))) ?? []
        let templateIds = Set(trainerWorkouts.filter(\.isTemplate).map(\.id))
        allWorkoutIds.formUnion(templateIds)

        // Fetch all workouts
        let allWIds = Array(allWorkoutIds)
        let workouts = (try? context.fetch(FetchDescriptor<WorkoutEntity>(
            predicate: #Predicate { allWIds.contains($0.id) }
        ))) ?? []

        // IdentityWorkouts joins to include (trainee's + trainer's templates)
        var iwJoins = iwJoinsTrainee
        iwJoins.append(contentsOf: iwJoinsTrainer.filter { templateIds.contains($0.workoutId) })

        // 6. TemplateInstances for workouts in scope
        let allWIdsForTI = Array(allWorkoutIds)
        let tiJoins = (try? context.fetch(FetchDescriptor<TemplateInstances>(
            predicate: #Predicate { allWIdsForTI.contains($0.workoutId) || allWIdsForTI.contains($0.templateId) }
        ))) ?? []

        // 7. Batch fetch groups, sets, exercise links (O(5) queries instead of O(w*g*s))
        let wgJoins = (try? context.fetch(FetchDescriptor<WorkoutGroups>(
            predicate: #Predicate { allWIds.contains($0.workoutId) }
        ))) ?? []
        let groupIds = wgJoins.map(\.groupId)
        let allGroups = (try? context.fetch(FetchDescriptor<WorkoutGroupEntity>(
            predicate: #Predicate { groupIds.contains($0.id) }
        ))) ?? []

        let gsJoins = (try? context.fetch(FetchDescriptor<GroupSets>(
            predicate: #Predicate { groupIds.contains($0.groupId) }
        ))) ?? []
        let setIds = gsJoins.map(\.setId)
        let allSets = (try? context.fetch(FetchDescriptor<SetEntity>(
            predicate: #Predicate { setIds.contains($0.id) }
        ))) ?? []

        let esJoins = (try? context.fetch(FetchDescriptor<ExerciseSets>(
            predicate: #Predicate { setIds.contains($0.setId) }
        ))) ?? []

        // 8. Package into SyncPayload
        return SyncPayload(
            version: 1,
            senderIdentityId: localIdentity.id,
            identities: identities,
            exercises: exercises.map { $0.toDTO() },
            workouts: workouts.map { $0.toDTO() },
            workoutGroups: allGroups.map { $0.toDTO() },
            sets: allSets.map { $0.toDTO() },
            trainerTrainees: ttJoins.map { $0.toDTO() },
            trainerExercises: teJoins.map { $0.toDTO() },
            identityWorkouts: iwJoins.map { $0.toDTO() },
            workoutGroupJoins: wgJoins.map { $0.toDTO() },
            groupSetJoins: gsJoins.map { $0.toDTO() },
            exerciseSetJoins: esJoins.map { $0.toDTO() },
            templateInstanceJoins: tiJoins.map { $0.toDTO() }
        )
    }
}
