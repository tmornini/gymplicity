import Foundation
import SwiftData

struct IdentityReconciliation {
    /// Inserts an IdentityAliases row linking two UUIDs if the pair doesn't already exist.
    /// No-op when id1 == id2.
    static func createAlias(id1: UUID, id2: UUID, in context: ModelContext) {
        guard id1 != id2 else { return }

        // Check both orderings
        let a = id1, b = id2
        let existing = (try? context.fetch(FetchDescriptor<IdentityAliases>(
            predicate: #Predicate {
                ($0.identityId1 == a && $0.identityId2 == b) ||
                ($0.identityId1 == b && $0.identityId2 == a)
            }
        )))?.first

        if existing == nil {
            context.insert(IdentityAliases(identityId1: id1, identityId2: id2))
        }
    }

    /// Returns the connected component of UUIDs reachable from the given UUID
    /// through IdentityAliases rows. Always includes the input UUID itself.
    static func aliasGroup(for uuid: UUID, in context: ModelContext) -> Set<UUID> {
        var visited = Set<UUID>()
        var frontier = Set<UUID>([uuid])

        while !frontier.isEmpty {
            visited.formUnion(frontier)
            var nextFrontier = Set<UUID>()

            for id in frontier {
                let rows = (try? context.fetch(FetchDescriptor<IdentityAliases>(
                    predicate: #Predicate {
                        $0.identityId1 == id || $0.identityId2 == id
                    }
                ))) ?? []

                for row in rows {
                    let other = row.identityId1 == id ? row.identityId2 : row.identityId1
                    if !visited.contains(other) {
                        nextFrontier.insert(other)
                    }
                }
            }

            frontier = nextFrontier
        }

        return visited
    }
}
