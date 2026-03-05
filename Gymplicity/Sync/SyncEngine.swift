import Foundation
import SwiftData

// MARK: - Merge Result

struct MergeResult {
    var identitiesInserted = 0
    var identitiesUpdated = 0
    var exercisesInserted = 0
    var exercisesUpdated = 0
    var workoutsInserted = 0
    var workoutsUpdated = 0
    var workoutGroupsInserted = 0
    var workoutGroupsUpdated = 0
    var setsInserted = 0
    var setsUpdated = 0
    var trainerTraineesInserted = 0
    var trainerExercisesInserted = 0
    var identityWorkoutsInserted = 0
    var workoutGroupJoinsInserted = 0
    var groupSetJoinsInserted = 0
    var exerciseSetJoinsInserted = 0
    var templateInstanceJoinsInserted = 0
    var identityAliasesInserted = 0

    var totalInserted: Int {
        identitiesInserted + exercisesInserted + workoutsInserted +
        workoutGroupsInserted + setsInserted + trainerTraineesInserted +
        trainerExercisesInserted + identityWorkoutsInserted +
        workoutGroupJoinsInserted + groupSetJoinsInserted + exerciseSetJoinsInserted +
        templateInstanceJoinsInserted + identityAliasesInserted
    }

    var totalUpdated: Int {
        identitiesUpdated + exercisesUpdated + workoutsUpdated +
        workoutGroupsUpdated + setsUpdated
    }

    var summary: String {
        if totalInserted == 0 && totalUpdated == 0 { return "Already up to date" }
        var parts: [String] = []
        let iCount = identitiesInserted + identitiesUpdated
        if iCount > 0 { parts.append("\(iCount) identit\(iCount == 1 ? "y" : "ies")") }
        let eCount = exercisesInserted + exercisesUpdated
        if eCount > 0 { parts.append("\(eCount) exercise\(eCount == 1 ? "" : "s")") }
        let wCount = workoutsInserted + workoutsUpdated
        if wCount > 0 { parts.append("\(wCount) workout\(wCount == 1 ? "" : "s")") }
        let gCount = workoutGroupsInserted + workoutGroupsUpdated
        if gCount > 0 { parts.append("\(gCount) group\(gCount == 1 ? "" : "s")") }
        let sCount = setsInserted + setsUpdated
        if sCount > 0 { parts.append("\(sCount) set\(sCount == 1 ? "" : "s")") }
        return "Synced \(parts.joined(separator: ", "))"
    }
}

// MARK: - Sync Engine

struct SyncEngine {
    /// Role-based PUT merge — inserts new records and updates existing ones
    /// when the sender has authority over the entity type.
    /// Merge order: entities before joins, parents before children.
    static func merge(_ payload: SyncPayload, into context: ModelContext) -> MergeResult {
        var result = MergeResult()

        // Determine sender role from payload identities
        let senderIsTrainer = payload.identities.first(where: { $0.id == payload.senderIdentityId })?.isTrainer ?? false

        // 1. Identities — sender can only update their own identity
        for dto in payload.identities {
            let id = dto.id
            let existing = (try? context.fetch(FetchDescriptor<IdentityEntity>(
                predicate: #Predicate { $0.id == id }
            )))?.first
            if let existing {
                // Only the sender updates their own identity
                if dto.id == payload.senderIdentityId {
                    existing.name = dto.name
                    result.identitiesUpdated += 1
                }
            } else {
                let entity = IdentityEntity(name: dto.name, isTrainer: dto.isTrainer)
                entity.id = dto.id
                context.insert(entity)
                result.identitiesInserted += 1
            }
        }

        // 2. Exercises — trainer has authority
        for dto in payload.exercises {
            let id = dto.id
            let existing = (try? context.fetch(FetchDescriptor<ExerciseEntity>(
                predicate: #Predicate { $0.id == id }
            )))?.first
            if let existing {
                if senderIsTrainer {
                    existing.name = dto.name
                    existing.catalogId = dto.catalogId
                    result.exercisesUpdated += 1
                }
            } else {
                let entity = ExerciseEntity(name: dto.name, catalogId: dto.catalogId)
                entity.id = dto.id
                context.insert(entity)
                result.exercisesInserted += 1
            }
        }

        // 3. Workouts — either side can update non-template workouts (trainer-first app),
        //               trainer has authority for template workouts
        for dto in payload.workouts {
            let id = dto.id
            let existing = (try? context.fetch(FetchDescriptor<WorkoutEntity>(
                predicate: #Predicate { $0.id == id }
            )))?.first
            if let existing {
                let senderHasAuthority = dto.isTemplate ? senderIsTrainer : true
                if senderHasAuthority {
                    existing.notes = dto.notes
                    existing.isCompleted = dto.isCompleted
                    existing.templateName = dto.templateName
                    result.workoutsUpdated += 1
                }
            } else {
                let entity = WorkoutEntity(
                    date: dto.date,
                    isTemplate: dto.isTemplate,
                    templateName: dto.templateName
                )
                entity.id = dto.id
                entity.notes = dto.notes
                entity.isCompleted = dto.isCompleted
                context.insert(entity)
                result.workoutsInserted += 1
            }
        }

        // 4. WorkoutGroups — trainer has authority
        for dto in payload.workoutGroups {
            let id = dto.id
            let existing = (try? context.fetch(FetchDescriptor<WorkoutGroupEntity>(
                predicate: #Predicate { $0.id == id }
            )))?.first
            if let existing {
                if senderIsTrainer {
                    existing.order = dto.order
                    existing.isSuperset = dto.isSuperset
                    result.workoutGroupsUpdated += 1
                }
            } else {
                let entity = WorkoutGroupEntity(order: dto.order, isSuperset: dto.isSuperset)
                entity.id = dto.id
                context.insert(entity)
                result.workoutGroupsInserted += 1
            }
        }

        // 5. Sets — either side can update (trainer records on behalf of trainee)
        for dto in payload.sets {
            let id = dto.id
            let existing = (try? context.fetch(FetchDescriptor<SetEntity>(
                predicate: #Predicate { $0.id == id }
            )))?.first
            if let existing {
                existing.weight = dto.weight
                existing.reps = dto.reps
                existing.isCompleted = dto.isCompleted
                existing.completedAt = dto.completedAt
                result.setsUpdated += 1
            } else {
                let entity = SetEntity(order: dto.order, weight: dto.weight, reps: dto.reps)
                entity.id = dto.id
                entity.isCompleted = dto.isCompleted
                entity.completedAt = dto.completedAt
                context.insert(entity)
                result.setsInserted += 1
            }
        }

        // 6. Join tables — INSERT IF NOT EXISTS only (immutable UUID pairs)

        // TrainerTrainees
        for dto in payload.trainerTrainees {
            let trainerId = dto.trainerId
            let traineeId = dto.traineeId
            let existing = (try? context.fetch(FetchDescriptor<TrainerTrainees>(
                predicate: #Predicate { $0.trainerId == trainerId && $0.traineeId == traineeId }
            )))?.first
            if existing == nil {
                context.insert(TrainerTrainees(trainerId: trainerId, traineeId: traineeId))
                result.trainerTraineesInserted += 1
            }
        }

        // TrainerExercises
        for dto in payload.trainerExercises {
            let trainerId = dto.trainerId
            let exerciseId = dto.exerciseId
            let existing = (try? context.fetch(FetchDescriptor<TrainerExercises>(
                predicate: #Predicate { $0.trainerId == trainerId && $0.exerciseId == exerciseId }
            )))?.first
            if existing == nil {
                context.insert(TrainerExercises(trainerId: trainerId, exerciseId: exerciseId))
                result.trainerExercisesInserted += 1
            }
        }

        // IdentityWorkouts
        for dto in payload.identityWorkouts {
            let identityId = dto.identityId
            let workoutId = dto.workoutId
            let existing = (try? context.fetch(FetchDescriptor<IdentityWorkouts>(
                predicate: #Predicate { $0.identityId == identityId && $0.workoutId == workoutId }
            )))?.first
            if existing == nil {
                context.insert(IdentityWorkouts(identityId: identityId, workoutId: workoutId))
                result.identityWorkoutsInserted += 1
            }
        }

        // WorkoutGroups joins
        for dto in payload.workoutGroupJoins {
            let workoutId = dto.workoutId
            let groupId = dto.groupId
            let existing = (try? context.fetch(FetchDescriptor<WorkoutGroups>(
                predicate: #Predicate { $0.workoutId == workoutId && $0.groupId == groupId }
            )))?.first
            if existing == nil {
                context.insert(WorkoutGroups(workoutId: workoutId, groupId: groupId))
                result.workoutGroupJoinsInserted += 1
            }
        }

        // GroupSets joins
        for dto in payload.groupSetJoins {
            let groupId = dto.groupId
            let setId = dto.setId
            let existing = (try? context.fetch(FetchDescriptor<GroupSets>(
                predicate: #Predicate { $0.groupId == groupId && $0.setId == setId }
            )))?.first
            if existing == nil {
                context.insert(GroupSets(groupId: groupId, setId: setId))
                result.groupSetJoinsInserted += 1
            }
        }

        // ExerciseSets joins
        for dto in payload.exerciseSetJoins {
            let exerciseId = dto.exerciseId
            let setId = dto.setId
            let existing = (try? context.fetch(FetchDescriptor<ExerciseSets>(
                predicate: #Predicate { $0.exerciseId == exerciseId && $0.setId == setId }
            )))?.first
            if existing == nil {
                context.insert(ExerciseSets(exerciseId: exerciseId, setId: setId))
                result.exerciseSetJoinsInserted += 1
            }
        }

        // TemplateInstances joins
        for dto in payload.templateInstanceJoins {
            let templateId = dto.templateId
            let workoutId = dto.workoutId
            let existing = (try? context.fetch(FetchDescriptor<TemplateInstances>(
                predicate: #Predicate { $0.templateId == templateId && $0.workoutId == workoutId }
            )))?.first
            if existing == nil {
                context.insert(TemplateInstances(templateId: templateId, workoutId: workoutId))
                result.templateInstanceJoinsInserted += 1
            }
        }

        // IdentityAliases joins
        for dto in payload.identityAliases {
            let id1 = dto.identityId1
            let id2 = dto.identityId2
            let existing = (try? context.fetch(FetchDescriptor<IdentityAliases>(
                predicate: #Predicate {
                    ($0.identityId1 == id1 && $0.identityId2 == id2) ||
                    ($0.identityId1 == id2 && $0.identityId2 == id1)
                }
            )))?.first
            if existing == nil {
                context.insert(IdentityAliases(identityId1: id1, identityId2: id2))
                result.identityAliasesInserted += 1
            }
        }

        return result
    }

}
