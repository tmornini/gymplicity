import Foundation
import SwiftData

extension ModelContext {
    @MainActor func fetchOrDie<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        file: StaticString = #file,
        line: UInt = #line
    ) -> [T] {
        do {
            return try fetch(descriptor)
        } catch {
            fatalError(
                "fetch failed: \(error)",
                file: file,
                line: line
            )
        }
    }

    @MainActor func fetchFirst<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        file: StaticString = #file,
        line: UInt = #line
    ) -> T? {
        fetchOrDie(
            descriptor,
            file: file,
            line: line
        ).first
    }
}
