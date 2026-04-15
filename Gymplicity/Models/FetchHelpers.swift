import Foundation
import SwiftData

extension ModelContext {
    @MainActor func fetchOrDie<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        file: String = #file,
        line: Int = #line
    ) -> [T] {
        do {
            return try fetch(descriptor)
        } catch {
            assertionFailure(
                "[FetchError] \(error)"
                    + " at \(file):\(line)"
            )
            return []
        }
    }

    @MainActor func fetchFirst<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        file: String = #file,
        line: Int = #line
    ) -> T? {
        fetchOrDie(
            descriptor,
            file: file,
            line: line
        ).first
    }
}
