import Foundation
import SwiftData

struct IdentityReconciliation {
    /// Inserts an IdentityAliases row linking two UUIDs
    /// if the pair doesn't already exist.
    /// No-op when id1 == id2.
    @MainActor static func createAlias(
        id1: UUID,
        id2: UUID,
        in context: ModelContext
    ) {
        guard id1 != id2 else { return }

        // Check both orderings
        let a = id1, b = id2
        let existing = context.fetchFirst(
            FetchDescriptor<IdentityAliases>(
                predicate: #Predicate {
                    ($0.identityId1 == a
                        && $0.identityId2 == b)
                    || ($0.identityId1 == b
                        && $0.identityId2 == a)
                }
            )
        )

        if existing == nil {
            context.insert(
                IdentityAliases(
                    identityId1: id1,
                    identityId2: id2
                )
            )
        }
    }

    /// Returns the connected component of UUIDs reachable from the given UUID
    /// through IdentityAliases rows. Always includes the input UUID itself.
    /// Uses a single query to fetch all alias rows, then BFS in-memory.
    @MainActor static func aliasGroup(
        for uuid: UUID,
        in context: ModelContext
    ) -> Set<UUID> {
        // Fetch ALL alias rows in one query (table is tiny)
        let allRows = context.fetchOrEmpty(
            FetchDescriptor<IdentityAliases>()
        )

        // Build adjacency list in-memory
        var adjacency: [UUID: Set<UUID>] = [:]
        for row in allRows {
            adjacency[row.identityId1, default: []].insert(row.identityId2)
            adjacency[row.identityId2, default: []].insert(row.identityId1)
        }

        // BFS in-memory
        var visited = Set<UUID>()
        var frontier = Set<UUID>([uuid])

        while !frontier.isEmpty {
            visited.formUnion(frontier)
            var nextFrontier = Set<UUID>()
            for id in frontier {
                guard let neighbors = adjacency[id]
                else { continue }
                for neighbor in neighbors {
                    if !visited.contains(neighbor) {
                        nextFrontier.insert(neighbor)
                    }
                }
            }
            frontier = nextFrontier
        }

        return visited
    }
}
