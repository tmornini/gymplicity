import Foundation
import SwiftData

// MARK: - Merge Result

struct MergeResult {
    var identitiesInserted = 0
    var exercisesInserted = 0
    var workoutsInserted = 0
    var workoutGroupsInserted = 0
    var setsInserted = 0
    var trainerTraineesInserted = 0
    var trainerExercisesInserted = 0
    var identityWorkoutsInserted = 0
    var workoutGroupJoinsInserted = 0
    var groupSetJoinsInserted = 0
    var exerciseSetJoinsInserted = 0

    var totalInserted: Int {
        identitiesInserted + exercisesInserted + workoutsInserted +
        workoutGroupsInserted + setsInserted + trainerTraineesInserted +
        trainerExercisesInserted + identityWorkoutsInserted +
        workoutGroupJoinsInserted + groupSetJoinsInserted + exerciseSetJoinsInserted
    }

    var summary: String {
        if totalInserted == 0 { return "Already up to date" }
        var parts: [String] = []
        if identitiesInserted > 0 { parts.append("\(identitiesInserted) identit\(identitiesInserted == 1 ? "y" : "ies")") }
        if exercisesInserted > 0 { parts.append("\(exercisesInserted) exercise\(exercisesInserted == 1 ? "" : "s")") }
        if workoutsInserted > 0 { parts.append("\(workoutsInserted) workout\(workoutsInserted == 1 ? "" : "s")") }
        if workoutGroupsInserted > 0 { parts.append("\(workoutGroupsInserted) group\(workoutGroupsInserted == 1 ? "" : "s")") }
        if setsInserted > 0 { parts.append("\(setsInserted) set\(setsInserted == 1 ? "" : "s")") }
        return "Synced \(parts.joined(separator: ", "))"
    }
}

// MARK: - Sync Engine

struct SyncEngine {
    /// Idempotent PUT merge — inserts records that don't already exist.
    /// Merge order: entities before joins, parents before children.
    static func put(_ payload: SyncPayload, into context: ModelContext) -> MergeResult {
        var result = MergeResult()

        // 1. Identities
        for dto in payload.identities {
            let id = dto.id
            let existing = (try? context.fetch(FetchDescriptor<IdentityEntity>(
                predicate: #Predicate { $0.id == id }
            )))?.first
            if existing == nil {
                let entity = IdentityEntity(name: dto.name, isTrainer: dto.isTrainer)
                entity.id = dto.id
                context.insert(entity)
                result.identitiesInserted += 1
            }
        }

        // 2. Exercises
        for dto in payload.exercises {
            let id = dto.id
            let existing = (try? context.fetch(FetchDescriptor<ExerciseEntity>(
                predicate: #Predicate { $0.id == id }
            )))?.first
            if existing == nil {
                let entity = ExerciseEntity(name: dto.name)
                entity.id = dto.id
                context.insert(entity)
                result.exercisesInserted += 1
            }
        }

        // 3. Workouts
        for dto in payload.workouts {
            let id = dto.id
            let existing = (try? context.fetch(FetchDescriptor<WorkoutEntity>(
                predicate: #Predicate { $0.id == id }
            )))?.first
            if existing == nil {
                let entity = WorkoutEntity(
                    date: dto.date,
                    isTemplate: dto.isTemplate,
                    templateName: dto.templateName
                )
                entity.id = dto.id
                entity.notes = dto.notes
                entity.isComplete = dto.isComplete
                entity.templateId = dto.templateId
                context.insert(entity)
                result.workoutsInserted += 1
            }
        }

        // 4. WorkoutGroups
        for dto in payload.workoutGroups {
            let id = dto.id
            let existing = (try? context.fetch(FetchDescriptor<WorkoutGroupEntity>(
                predicate: #Predicate { $0.id == id }
            )))?.first
            if existing == nil {
                let entity = WorkoutGroupEntity(order: dto.order, isSuperset: dto.isSuperset)
                entity.id = dto.id
                context.insert(entity)
                result.workoutGroupsInserted += 1
            }
        }

        // 5. Sets
        for dto in payload.sets {
            let id = dto.id
            let existing = (try? context.fetch(FetchDescriptor<SetEntity>(
                predicate: #Predicate { $0.id == id }
            )))?.first
            if existing == nil {
                let entity = SetEntity(order: dto.order, weight: dto.weight, reps: dto.reps)
                entity.id = dto.id
                entity.isCompleted = dto.isCompleted
                entity.completedAt = dto.completedAt
                context.insert(entity)
                result.setsInserted += 1
            }
        }

        // 6. Join tables — TrainerTrainees
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

        return result
    }
}
