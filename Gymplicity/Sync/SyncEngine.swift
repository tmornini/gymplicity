import Foundation
import SwiftData

// MARK: - Merge Result

struct MergeResult: Sendable {
    var identitiesInserted: Int
    var identitiesUpdated: Int
    var exercisesInserted: Int
    var exercisesUpdated: Int
    var workoutsInserted: Int
    var workoutsUpdated: Int
    var workoutGroupsInserted: Int
    var workoutGroupsUpdated: Int
    var setsInserted: Int
    var setsUpdated: Int
    var trainerTraineesInserted: Int
    var trainerExercisesInserted: Int
    var identityWorkoutsInserted: Int
    var workoutGroupJoinsInserted: Int
    var groupSetJoinsInserted: Int
    var exerciseSetJoinsInserted: Int
    var templateInstanceJoinsInserted: Int
    var identityAliasesInserted: Int
    var setCompletionsInserted: Int
    var workoutCompletionsInserted: Int
    var deviceSyncEventsInserted: Int
    var catalogExercisesInserted: Int

    var totalInserted: Int {
        identitiesInserted
            + exercisesInserted
            + workoutsInserted
            + workoutGroupsInserted
            + setsInserted
            + trainerTraineesInserted
            + trainerExercisesInserted
            + identityWorkoutsInserted
            + workoutGroupJoinsInserted
            + groupSetJoinsInserted
            + exerciseSetJoinsInserted
            + templateInstanceJoinsInserted
            + identityAliasesInserted
            + setCompletionsInserted
            + workoutCompletionsInserted
            + deviceSyncEventsInserted
            + catalogExercisesInserted
    }

    var totalUpdated: Int {
        identitiesUpdated + exercisesUpdated + workoutsUpdated +
        workoutGroupsUpdated + setsUpdated
    }

    var summary: String {
        if totalInserted == 0 && totalUpdated == 0 {
            return "Already up to date"
        }
        var parts: [String] = []
        let iCount = identitiesInserted + identitiesUpdated
        if iCount > 0 {
            parts.append(
                "\(iCount) identit\(iCount == 1 ? "y" : "ies")"
            )
        }
        let eCount = exercisesInserted + exercisesUpdated
        if eCount > 0 {
            parts.append(
                "\(eCount) exercise\(eCount == 1 ? "" : "s")"
            )
        }
        let wCount = workoutsInserted + workoutsUpdated
        if wCount > 0 {
            parts.append(
                "\(wCount) workout\(wCount == 1 ? "" : "s")"
            )
        }
        let gCount = workoutGroupsInserted + workoutGroupsUpdated
        if gCount > 0 {
            parts.append(
                "\(gCount) group\(gCount == 1 ? "" : "s")"
            )
        }
        let sCount = setsInserted + setsUpdated
        if sCount > 0 {
            parts.append(
                "\(sCount) set\(sCount == 1 ? "" : "s")"
            )
        }
        return "Synced \(parts.joined(separator: ", "))"
    }
}

// MARK: - Sync Engine

struct SyncEngine {
    /// Role-based PUT merge — inserts new records and updates existing ones
    /// when the sender has authority over the entity type.
    /// Merge order: entities before joins, parents before children.
    @MainActor static func merge(
        _ payload: SyncPayload,
        into context: ModelContext
    ) -> MergeResult {
        var result = MergeResult(
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
            deviceSyncEventsInserted: 0,
            catalogExercisesInserted: 0
        )

        // Determine sender role from payload identities
        guard let sender = payload.identities
            .first(where: {
                $0.id == payload.senderIdentityId
            })
        else {
            fatalError(
                "sender \(payload.senderIdentityId)"
                + " missing from payload identities"
            )
        }
        let senderIsTrainer = sender.isTrainer

        // 1. Identities — sender can only update their own identity
        for dto in payload.identities {
            let id = dto.id
            let existing = context.fetchFirst(
                FetchDescriptor<IdentityEntity>(
                    predicate: #Predicate {
                        $0.id == id
                    }
                )
            )
            if let existing {
                // Only the sender updates their own identity
                if dto.id == payload.senderIdentityId {
                    existing.name = dto.name
                    result.identitiesUpdated += 1
                }
            } else {
                let entity = IdentityEntity(
                    name: dto.name,
                    isTrainer: dto.isTrainer
                )
                entity.id = dto.id
                context.insert(entity)
                result.identitiesInserted += 1
            }
        }

        // 2. Exercises — trainer has authority
        for dto in payload.exercises {
            let id = dto.id
            let existing = context.fetchFirst(
                FetchDescriptor<ExerciseEntity>(
                    predicate: #Predicate {
                        $0.id == id
                    }
                )
            )
            if let existing {
                if senderIsTrainer {
                    existing.name = dto.name
                    result.exercisesUpdated += 1
                }
            } else {
                let entity = ExerciseEntity(name: dto.name)
                entity.id = dto.id
                context.insert(entity)
                result.exercisesInserted += 1
            }
        }

        // 3. Workouts — either side can update
        //    non-template workouts (trainer-first app),
        //    trainer has authority for template workouts
        for dto in payload.workouts {
            let id = dto.id
            let existing = context.fetchFirst(
                FetchDescriptor<WorkoutEntity>(
                    predicate: #Predicate {
                        $0.id == id
                    }
                )
            )
            if existing != nil {
                let senderHasAuthority =
                    dto.isTemplate
                        ? senderIsTrainer : true
                if senderHasAuthority {
                    result.workoutsUpdated += 1
                }
            } else {
                let entity = WorkoutEntity(
                    date: dto.date,
                    isTemplate: dto.isTemplate
                )
                entity.id = dto.id
                context.insert(entity)
                result.workoutsInserted += 1
            }
        }

        // 4. WorkoutTemplates — trainer has
        //    authority (templates are trainer-owned)
        for dto in payload.workoutTemplates {
            let wId = dto.workoutId
            let existing = context.fetchFirst(
                FetchDescriptor<WorkoutTemplate>(
                    predicate: #Predicate {
                        $0.workoutId == wId
                    }
                )
            )
            if let existing {
                if senderIsTrainer {
                    existing.name = dto.name
                    result.workoutsUpdated += 1
                }
            } else {
                context.insert(
                    WorkoutTemplate(
                        workoutId: dto.workoutId,
                        name: dto.name
                    )
                )
                result.workoutsInserted += 1
            }
        }

        // 4b. WorkoutNotes — either side can update
        for dto in payload.workoutNotes {
            let wId = dto.workoutId
            let existing = context.fetchFirst(
                FetchDescriptor<WorkoutNotes>(
                    predicate: #Predicate {
                        $0.workoutId == wId
                    }
                )
            )
            if let existing {
                existing.notes = dto.notes
                result.workoutsUpdated += 1
            } else {
                context.insert(
                    WorkoutNotes(
                        workoutId: dto.workoutId,
                        notes: dto.notes
                    )
                )
                result.workoutsInserted += 1
            }
        }

        // 4c. CatalogExercises — trainer has authority
        //     PUT semantics: insert once, never mutate
        if senderIsTrainer {
            for dto in payload.catalogExercises {
                let eId = dto.exerciseId
                let existing = context.fetchFirst(
                    FetchDescriptor<CatalogExercises>(
                        predicate: #Predicate {
                            $0.exerciseId == eId
                        }
                    )
                )
                if existing == nil {
                    context.insert(
                        CatalogExercises(
                            exerciseId: dto.exerciseId,
                            catalogId: dto.catalogId
                        )
                    )
                    result.catalogExercisesInserted += 1
                }
            }
        }

        // 5. WorkoutGroups — trainer has authority
        for dto in payload.workoutGroups {
            let id = dto.id
            let existing = context.fetchFirst(
                FetchDescriptor<WorkoutGroupEntity>(
                    predicate: #Predicate {
                        $0.id == id
                    }
                )
            )
            if let existing {
                if senderIsTrainer {
                    existing.order = dto.order
                    existing.isSuperset = dto.isSuperset
                    result.workoutGroupsUpdated += 1
                }
            } else {
                let entity = WorkoutGroupEntity(
                    order: dto.order,
                    isSuperset: dto.isSuperset
                )
                entity.id = dto.id
                context.insert(entity)
                result.workoutGroupsInserted += 1
            }
        }

        // 5. Sets — either side can update
        //    (trainer records on behalf of trainee)
        for dto in payload.sets {
            let id = dto.id
            let existing = context.fetchFirst(
                FetchDescriptor<SetEntity>(
                    predicate: #Predicate {
                        $0.id == id
                    }
                )
            )
            if let existing {
                existing.weight = dto.weight
                existing.reps = dto.reps
                result.setsUpdated += 1
            } else {
                let entity = SetEntity(
                    order: dto.order,
                    weight: dto.weight,
                    reps: dto.reps
                )
                entity.id = dto.id
                context.insert(entity)
                result.setsInserted += 1
            }
        }

        // 6. Join tables — INSERT IF NOT EXISTS only (immutable UUID pairs)

        // TrainerTrainees
        for dto in payload.trainerTrainees {
            let trainerId = dto.trainerId
            let traineeId = dto.traineeId
            let existing = context.fetchFirst(
                FetchDescriptor<TrainerTrainees>(
                    predicate: #Predicate {
                        $0.trainerId == trainerId
                            && $0.traineeId == traineeId
                    }
                )
            )
            if existing == nil {
                context.insert(TrainerTrainees(
                    trainerId: trainerId,
                    traineeId: traineeId
                ))
                result.trainerTraineesInserted += 1
            }
        }

        // TrainerExercises
        for dto in payload.trainerExercises {
            let trainerId = dto.trainerId
            let exerciseId = dto.exerciseId
            let existing = context.fetchFirst(
                FetchDescriptor<TrainerExercises>(
                    predicate: #Predicate {
                        $0.trainerId == trainerId
                            && $0.exerciseId == exerciseId
                    }
                )
            )
            if existing == nil {
                context.insert(TrainerExercises(
                    trainerId: trainerId,
                    exerciseId: exerciseId
                ))
                result.trainerExercisesInserted += 1
            }
        }

        // IdentityWorkouts
        for dto in payload.identityWorkouts {
            let identityId = dto.identityId
            let workoutId = dto.workoutId
            let existing = context.fetchFirst(
                FetchDescriptor<IdentityWorkouts>(
                    predicate: #Predicate {
                        $0.identityId == identityId
                            && $0.workoutId == workoutId
                    }
                )
            )
            if existing == nil {
                context.insert(IdentityWorkouts(
                    identityId: identityId,
                    workoutId: workoutId
                ))
                result.identityWorkoutsInserted += 1
            }
        }

        // WorkoutGroups joins
        for dto in payload.workoutGroupJoins {
            let workoutId = dto.workoutId
            let groupId = dto.groupId
            let existing = context.fetchFirst(
                FetchDescriptor<WorkoutGroups>(
                    predicate: #Predicate {
                        $0.workoutId == workoutId
                            && $0.groupId == groupId
                    }
                )
            )
            if existing == nil {
                context.insert(WorkoutGroups(
                    workoutId: workoutId,
                    groupId: groupId
                ))
                result.workoutGroupJoinsInserted += 1
            }
        }

        // GroupSets joins
        for dto in payload.groupSetJoins {
            let groupId = dto.groupId
            let setId = dto.setId
            let existing = context.fetchFirst(
                FetchDescriptor<GroupSets>(
                    predicate: #Predicate {
                        $0.groupId == groupId
                            && $0.setId == setId
                    }
                )
            )
            if existing == nil {
                context.insert(GroupSets(groupId: groupId, setId: setId))
                result.groupSetJoinsInserted += 1
            }
        }

        // ExerciseSets joins
        for dto in payload.exerciseSetJoins {
            let exerciseId = dto.exerciseId
            let setId = dto.setId
            let existing = context.fetchFirst(
                FetchDescriptor<ExerciseSets>(
                    predicate: #Predicate {
                        $0.exerciseId == exerciseId
                            && $0.setId == setId
                    }
                )
            )
            if existing == nil {
                context.insert(ExerciseSets(
                    exerciseId: exerciseId,
                    setId: setId
                ))
                result.exerciseSetJoinsInserted += 1
            }
        }

        // TemplateInstances joins
        for dto in payload.templateInstanceJoins {
            let templateId = dto.templateId
            let workoutId = dto.workoutId
            let existing = context.fetchFirst(
                FetchDescriptor<TemplateInstances>(
                    predicate: #Predicate {
                        $0.templateId == templateId
                            && $0.workoutId == workoutId
                    }
                )
            )
            if existing == nil {
                context.insert(TemplateInstances(
                    templateId: templateId,
                    workoutId: workoutId
                ))
                result.templateInstanceJoinsInserted += 1
            }
        }

        // IdentityAliases joins
        for dto in payload.identityAliases {
            let id1 = dto.identityId1
            let id2 = dto.identityId2
            let existing = context.fetchFirst(
                FetchDescriptor<IdentityAliases>(
                    predicate: #Predicate {
                        ($0.identityId1 == id1
                            && $0.identityId2
                                == id2)
                            || ($0.identityId1
                                == id2
                                && $0.identityId2
                                    == id1)
                    }
                )
            )
            if existing == nil {
                context.insert(IdentityAliases(
                    identityId1: id1,
                    identityId2: id2
                ))
                result
                    .identityAliasesInserted += 1
            }
        }

        // 7. Event tables — INSERT IF NOT EXISTS

        // SetCompletions
        for dto in payload.setCompletions {
            let setId = dto.setId
            let existing = context.fetchFirst(
                FetchDescriptor<SetCompletions>(
                    predicate: #Predicate {
                        $0.setId == setId
                    }
                )
            )
            if existing == nil {
                context.insert(SetCompletions(
                    setId: dto.setId,
                    completedAt: dto.completedAt
                ))
                result
                    .setCompletionsInserted += 1
            }
        }

        // WorkoutCompletions
        for dto in payload.workoutCompletions {
            let workoutId = dto.workoutId
            let existing = context.fetchFirst(
                FetchDescriptor<
                    WorkoutCompletions
                >(
                    predicate: #Predicate {
                        $0.workoutId == workoutId
                    }
                )
            )
            if existing == nil {
                context.insert(
                    WorkoutCompletions(
                        workoutId: dto.workoutId,
                        completedAt:
                            dto.completedAt
                    )
                )
                result
                    .workoutCompletionsInserted
                    += 1
            }
        }

        // DeviceSyncEvents
        for dto in payload.deviceSyncEvents {
            let localId = dto.localIdentityId
            let remoteId = dto.remoteIdentityId
            let syncedAt = dto.syncedAt
            let existing = context.fetchFirst(
                FetchDescriptor<DeviceSyncEvents>(
                    predicate: #Predicate {
                        $0.localIdentityId
                            == localId
                        && $0.remoteIdentityId
                            == remoteId
                        && $0.syncedAt
                            == syncedAt
                    }
                )
            )
            if existing == nil {
                context.insert(
                    DeviceSyncEvents(
                        localIdentityId:
                            dto.localIdentityId,
                        remoteIdentityId:
                            dto.remoteIdentityId,
                        syncedAt: dto.syncedAt
                    )
                )
                result
                    .deviceSyncEventsInserted
                    += 1
            }
        }

        return result
    }

}
