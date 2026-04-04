import Foundation
import SwiftData

// MARK: - DTOs

struct IdentityDTO: Codable, Sendable {
    let id: UUID
    let name: String
    let isTrainer: Bool
}

struct ExerciseDTO: Codable, Sendable {
    let id: UUID
    let name: String
    let catalogId: String?
}

struct WorkoutDTO: Codable, Sendable {
    let id: UUID
    let date: Date
    let isTemplate: Bool
}

struct WorkoutTemplateDTO: Codable, Sendable {
    let workoutId: UUID
    let name: String
}

struct WorkoutNotesDTO: Codable, Sendable {
    let workoutId: UUID
    let notes: String
}

struct WorkoutGroupDTO: Codable, Sendable {
    let id: UUID
    let order: Int
    let isSuperset: Bool
}

struct SetDTO: Codable, Sendable {
    let id: UUID
    let order: Int
    let weight: Double
    let reps: Int
}

struct TrainerTraineesDTO: Codable, Sendable {
    let trainerId: UUID
    let traineeId: UUID
}

struct TrainerExercisesDTO: Codable, Sendable {
    let trainerId: UUID
    let exerciseId: UUID
}

struct IdentityWorkoutsDTO: Codable, Sendable {
    let identityId: UUID
    let workoutId: UUID
}

struct WorkoutGroupsDTO: Codable, Sendable {
    let workoutId: UUID
    let groupId: UUID
}

struct GroupSetsDTO: Codable, Sendable {
    let groupId: UUID
    let setId: UUID
}

struct ExerciseSetsDTO: Codable, Sendable {
    let exerciseId: UUID
    let setId: UUID
}

struct TemplateInstancesDTO: Codable, Sendable {
    let templateId: UUID
    let workoutId: UUID
}

struct IdentityAliasesDTO: Codable, Sendable {
    let identityId1: UUID
    let identityId2: UUID
}

struct SetCompletionDTO: Codable, Sendable {
    let setId: UUID
    let completedAt: Date
}

struct WorkoutCompletionDTO:
    Codable, Sendable
{
    let workoutId: UUID
    let completedAt: Date
}

struct DeviceSyncEventDTO:
    Codable, Sendable
{
    let localIdentityId: UUID
    let remoteIdentityId: UUID
    let syncedAt: Date
}

// MARK: - Payload Envelope

struct SyncPayload: Codable, Sendable {
    static let currentVersion = 1
    let version: Int
    let senderIdentityId: UUID

    // Entities
    let identities: [IdentityDTO]
    let exercises: [ExerciseDTO]
    let workouts: [WorkoutDTO]
    let workoutGroups: [WorkoutGroupDTO]
    let sets: [SetDTO]

    // Relationship tables
    let workoutTemplates: [WorkoutTemplateDTO]
    let workoutNotes: [WorkoutNotesDTO]

    // Join tables
    let trainerTrainees: [TrainerTraineesDTO]
    let trainerExercises: [TrainerExercisesDTO]
    let identityWorkouts: [IdentityWorkoutsDTO]
    let workoutGroupJoins: [WorkoutGroupsDTO]
    let groupSetJoins: [GroupSetsDTO]
    let exerciseSetJoins: [ExerciseSetsDTO]
    let templateInstanceJoins:
        [TemplateInstancesDTO]
    let identityAliases: [IdentityAliasesDTO]

    // Event tables
    let setCompletions: [SetCompletionDTO]
    let workoutCompletions:
        [WorkoutCompletionDTO]
    let deviceSyncEvents:
        [DeviceSyncEventDTO]

    /// Creates a delta payload containing
    /// only the specified changed entities.
    /// Empty arrays default for entity types
    /// not included in this delta.
    static func delta(
        senderIdentityId: UUID,
        identities: [IdentityDTO],
        exercises: [ExerciseDTO],
        workouts: [WorkoutDTO],
        workoutGroups: [WorkoutGroupDTO],
        sets: [SetDTO],
        setCompletions: [SetCompletionDTO],
        workoutCompletions:
            [WorkoutCompletionDTO],
        deviceSyncEvents:
            [DeviceSyncEventDTO]
    ) -> SyncPayload {
        SyncPayload(
            version: SyncPayload.currentVersion,
            senderIdentityId: senderIdentityId,
            identities: identities,
            exercises: exercises,
            workouts: workouts,
            workoutGroups: workoutGroups,
            sets: sets,
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
            setCompletions: setCompletions,
            workoutCompletions:
                workoutCompletions,
            deviceSyncEvents: deviceSyncEvents
        )
    }
}

// MARK: - Sync Message

enum SyncMessage: Codable, Sendable {
    case pairingOffer(
        senderUUID: UUID,
        senderName: String,
        senderIsTrainer: Bool,
        linkedIdentityUUID: UUID?,
        linkedIdentityName: String?
    )
    case pairingAccepted(
        responderUUID: UUID,
        responderName: String,
        responderIsTrainer: Bool,
        linkedIdentityUUID: UUID?,
        linkedIdentityName: String?
    )
    case pairingDeclined
    case entityUpdates(SyncPayload)
}

// MARK: - Entity -> DTO Extensions

extension IdentityEntity {
    @MainActor func toDTO() -> IdentityDTO {
        IdentityDTO(id: id, name: name, isTrainer: isTrainer)
    }
}

extension ExerciseEntity {
    @MainActor func toDTO() -> ExerciseDTO {
        ExerciseDTO(id: id, name: name, catalogId: catalogId)
    }
}

extension WorkoutEntity {
    @MainActor func toDTO() -> WorkoutDTO {
        WorkoutDTO(
            id: id,
            date: date,
            isTemplate: isTemplate
        )
    }
}

extension WorkoutTemplate {
    @MainActor func toDTO()
        -> WorkoutTemplateDTO
    {
        WorkoutTemplateDTO(
            workoutId: workoutId,
            name: name
        )
    }
}

extension WorkoutNotes {
    @MainActor func toDTO()
        -> WorkoutNotesDTO
    {
        WorkoutNotesDTO(
            workoutId: workoutId,
            notes: notes
        )
    }
}

extension WorkoutGroupEntity {
    @MainActor func toDTO() -> WorkoutGroupDTO {
        WorkoutGroupDTO(id: id, order: order, isSuperset: isSuperset)
    }
}

extension SetEntity {
    @MainActor func toDTO() -> SetDTO {
        SetDTO(
            id: id,
            order: order,
            weight: weight,
            reps: reps
        )
    }
}

extension TrainerTrainees {
    @MainActor func toDTO() -> TrainerTraineesDTO {
        TrainerTraineesDTO(trainerId: trainerId, traineeId: traineeId)
    }
}

extension TrainerExercises {
    @MainActor func toDTO() -> TrainerExercisesDTO {
        TrainerExercisesDTO(trainerId: trainerId, exerciseId: exerciseId)
    }
}

extension IdentityWorkouts {
    @MainActor func toDTO() -> IdentityWorkoutsDTO {
        IdentityWorkoutsDTO(identityId: identityId, workoutId: workoutId)
    }
}

extension WorkoutGroups {
    @MainActor func toDTO() -> WorkoutGroupsDTO {
        WorkoutGroupsDTO(workoutId: workoutId, groupId: groupId)
    }
}

extension GroupSets {
    @MainActor func toDTO() -> GroupSetsDTO {
        GroupSetsDTO(groupId: groupId, setId: setId)
    }
}

extension ExerciseSets {
    @MainActor func toDTO() -> ExerciseSetsDTO {
        ExerciseSetsDTO(exerciseId: exerciseId, setId: setId)
    }
}

extension TemplateInstances {
    @MainActor func toDTO() -> TemplateInstancesDTO {
        TemplateInstancesDTO(templateId: templateId, workoutId: workoutId)
    }
}

extension IdentityAliases {
    @MainActor func toDTO()
        -> IdentityAliasesDTO
    {
        IdentityAliasesDTO(
            identityId1: identityId1,
            identityId2: identityId2
        )
    }
}

extension SetCompletions {
    @MainActor func toDTO()
        -> SetCompletionDTO
    {
        SetCompletionDTO(
            setId: setId,
            completedAt: completedAt
        )
    }
}

extension WorkoutCompletions {
    @MainActor func toDTO()
        -> WorkoutCompletionDTO
    {
        WorkoutCompletionDTO(
            workoutId: workoutId,
            completedAt: completedAt
        )
    }
}

extension DeviceSyncEvents {
    @MainActor func toDTO()
        -> DeviceSyncEventDTO
    {
        DeviceSyncEventDTO(
            localIdentityId: localIdentityId,
            remoteIdentityId: remoteIdentityId,
            syncedAt: syncedAt
        )
    }
}

// MARK: - Payload Builder

struct SyncPayloadBuilder {
    /// Builds a complete sync payload for the trainer-trainee pair.
    /// Both sides send everything relevant to their relationship.
    @MainActor static func build(
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
        let ttJoins = context.fetchOrEmpty(
            FetchDescriptor<TrainerTrainees>(
                predicate: #Predicate {
                    $0.trainerId == trainerId
                        && $0.traineeId == traineeId
                }
            )
        )

        // 3. All exercises via TrainerExercises for the trainer
        let teJoins = context.fetchOrEmpty(
            FetchDescriptor<TrainerExercises>(
                predicate: #Predicate {
                    $0.trainerId == trainerId
                }
            )
        )
        let exerciseIds = teJoins.map(\.exerciseId)
        let exercises = context.fetchOrEmpty(
            FetchDescriptor<ExerciseEntity>(
                predicate: #Predicate {
                    exerciseIds.contains($0.id)
                }
            )
        )

        // 4. Resolve alias group for the trainee to get full workout history
        let traineeAliasGroup =
            IdentityReconciliation.aliasGroup(
                for: traineeId,
                in: context
            )
        let traineeAliasIds = Array(traineeAliasGroup)

        // 5. Trainee's workouts
        //    (all aliases -- completed, active, templates)
        let iwJoinsTrainee = context.fetchOrEmpty(
            FetchDescriptor<IdentityWorkouts>(
                predicate: #Predicate {
                    traineeAliasIds.contains($0.identityId)
                }
            )
        )

        // 6. Trainer's templates
        let iwJoinsTrainer = context.fetchOrEmpty(
            FetchDescriptor<IdentityWorkouts>(
                predicate: #Predicate {
                    $0.identityId == trainerId
                }
            )
        )

        // Collect all workout IDs
        var allWorkoutIds = Set(iwJoinsTrainee.map(\.workoutId))
        let trainerWorkoutIds = Set(iwJoinsTrainer.map(\.workoutId))

        // Fetch all trainer workouts to filter templates
        let trainerWIds = Array(trainerWorkoutIds)
        let trainerWorkouts = context.fetchOrEmpty(
            FetchDescriptor<WorkoutEntity>(
                predicate: #Predicate {
                    trainerWIds.contains($0.id)
                }
            )
        )
        let templateIds = Set(trainerWorkouts.filter(\.isTemplate).map(\.id))
        allWorkoutIds.formUnion(templateIds)

        // Fetch all workouts
        let allWIds = Array(allWorkoutIds)
        let workouts = context.fetchOrEmpty(
            FetchDescriptor<WorkoutEntity>(
                predicate: #Predicate {
                    allWIds.contains($0.id)
                }
            )
        )

        // IdentityWorkouts joins to include (trainee's + trainer's templates)
        var iwJoins = iwJoinsTrainee
        iwJoins.append(
            contentsOf: iwJoinsTrainer.filter {
                templateIds.contains($0.workoutId)
            }
        )

        // 7. WorkoutTemplates for template workouts
        let wtRows = context.fetchOrEmpty(
            FetchDescriptor<WorkoutTemplate>(
                predicate: #Predicate {
                    allWIds.contains(
                        $0.workoutId
                    )
                }
            )
        )

        // 7b. WorkoutNotes for workouts in scope
        let wnRows = context.fetchOrEmpty(
            FetchDescriptor<WorkoutNotes>(
                predicate: #Predicate {
                    allWIds.contains(
                        $0.workoutId
                    )
                }
            )
        )

        // 8. TemplateInstances for workouts in scope
        let allWIdsForTI = Array(allWorkoutIds)
        let tiJoins = context.fetchOrEmpty(
            FetchDescriptor<TemplateInstances>(
                predicate: #Predicate {
                    allWIdsForTI.contains($0.workoutId)
                        || allWIdsForTI.contains(
                            $0.templateId
                        )
                }
            )
        )

        // 9. Batch fetch groups, sets, exercise links
        //    O(5) queries instead of O(w*g*s)
        let wgJoins = context.fetchOrEmpty(
            FetchDescriptor<WorkoutGroups>(
                predicate: #Predicate {
                    allWIds.contains($0.workoutId)
                }
            )
        )
        let groupIds = wgJoins.map(\.groupId)
        let allGroups = context.fetchOrEmpty(
            FetchDescriptor<WorkoutGroupEntity>(
                predicate: #Predicate {
                    groupIds.contains($0.id)
                }
            )
        )

        let gsJoins = context.fetchOrEmpty(
            FetchDescriptor<GroupSets>(
                predicate: #Predicate {
                    groupIds.contains($0.groupId)
                }
            )
        )
        let setIds = gsJoins.map(\.setId)
        let allSets = context.fetchOrEmpty(
            FetchDescriptor<SetEntity>(
                predicate: #Predicate {
                    setIds.contains($0.id)
                }
            )
        )

        let esJoins = context.fetchOrEmpty(
            FetchDescriptor<ExerciseSets>(
                predicate: #Predicate {
                    setIds.contains($0.setId)
                }
            )
        )

        // 10. IdentityAliases for identities in scope
        let allIdentityIds = Array(traineeAliasGroup.union([trainerId]))
        let aliasRows = context.fetchOrEmpty(
            FetchDescriptor<IdentityAliases>(
                predicate: #Predicate {
                    allIdentityIds.contains(
                        $0.identityId1
                    )
                        || allIdentityIds.contains(
                            $0.identityId2
                        )
                }
            )
        )

        // 11. SetCompletions for sets in scope
        let scRows = context.fetchOrEmpty(
            FetchDescriptor<SetCompletions>(
                predicate: #Predicate {
                    setIds.contains($0.setId)
                }
            )
        )

        // 12. WorkoutCompletions for workouts
        //     in scope
        let wcRows = context.fetchOrEmpty(
            FetchDescriptor<WorkoutCompletions>(
                predicate: #Predicate {
                    allWIds.contains(
                        $0.workoutId
                    )
                }
            )
        )

        // 13. DeviceSyncEvents for identities
        //     in scope
        let dseRows = context.fetchOrEmpty(
            FetchDescriptor<DeviceSyncEvents>(
                predicate: #Predicate {
                    allIdentityIds.contains(
                        $0.localIdentityId
                    )
                }
            )
        )

        // 14. Package into SyncPayload
        return SyncPayload(
            version: SyncPayload.currentVersion,
            senderIdentityId: localIdentity.id,
            identities: identities,
            exercises:
                exercises.map { $0.toDTO() },
            workouts:
                workouts.map { $0.toDTO() },
            workoutGroups:
                allGroups.map { $0.toDTO() },
            sets:
                allSets.map { $0.toDTO() },
            workoutTemplates:
                wtRows.map { $0.toDTO() },
            workoutNotes:
                wnRows.map { $0.toDTO() },
            trainerTrainees:
                ttJoins.map { $0.toDTO() },
            trainerExercises:
                teJoins.map { $0.toDTO() },
            identityWorkouts:
                iwJoins.map { $0.toDTO() },
            workoutGroupJoins:
                wgJoins.map { $0.toDTO() },
            groupSetJoins:
                gsJoins.map { $0.toDTO() },
            exerciseSetJoins:
                esJoins.map { $0.toDTO() },
            templateInstanceJoins:
                tiJoins.map { $0.toDTO() },
            identityAliases:
                aliasRows.map { $0.toDTO() },
            setCompletions:
                scRows.map { $0.toDTO() },
            workoutCompletions:
                wcRows.map { $0.toDTO() },
            deviceSyncEvents:
                dseRows.map { $0.toDTO() }
        )
    }
}
