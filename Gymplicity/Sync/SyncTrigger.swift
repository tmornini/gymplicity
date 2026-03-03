import Foundation

enum SyncTrigger {
    static let entityUpdatedNotification = Notification.Name("SyncTriggerEntityUpdated")
    static let structureChangedNotification = Notification.Name("SyncTriggerStructureChanged")

    static func entityUpdated(_ type: String, id: UUID) {
        NotificationCenter.default.post(
            name: entityUpdatedNotification,
            object: nil,
            userInfo: ["type": type, "id": id]
        )
    }

    static func structureChanged() {
        NotificationCenter.default.post(
            name: structureChangedNotification,
            object: nil
        )
    }
}
