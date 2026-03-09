import Foundation

enum SyncEntityType: String, Sendable {
    case set = "SetEntity"
    case workout = "WorkoutEntity"
    case identity = "IdentityEntity"
    case exercise = "ExerciseEntity"
    case workoutGroup = "WorkoutGroupEntity"
}

enum SyncTrigger {
    static let entityUpdatedNotification = Notification.Name("SyncTriggerEntityUpdated")
    static let structureChangedNotification = Notification.Name("SyncTriggerStructureChanged")

    static func entityUpdated(_ type: SyncEntityType, id: UUID) {
        NotificationCenter.default.post(
            name: entityUpdatedNotification,
            object: nil,
            userInfo: ["type": type.rawValue, "id": id]
        )
    }

    static func structureChanged() {
        NotificationCenter.default.post(
            name: structureChangedNotification,
            object: nil
        )
    }
}
