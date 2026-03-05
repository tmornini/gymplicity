import Foundation
import MultipeerConnectivity
import SwiftData
import Combine

// MARK: - Connection State

enum SyncConnectionState: Equatable {
    case idle
    case searching
    case connecting
    case pairing(peerName: String)
    case waitingForResponse(peerName: String)
    case syncing(peerName: String)
    case connected(peerName: String)
    case error(String)
}

// MARK: - Discovered Peer

struct DiscoveredPeer: Identifiable {
    let peerID: MCPeerID
    let name: String
    let role: String
    var id: MCPeerID { peerID }
}

// MARK: - Sync Session Manager

class SyncSessionManager: NSObject, ObservableObject {
    private static let serviceType = "gymplicity"

    @Published var connectionState: SyncConnectionState = .idle
    @Published var discoveredPeers: [DiscoveredPeer] = []
    @Published var lastSyncResult: MergeResult?

    // Transient pairing state — no DB writes until mutual acceptance
    @Published var pendingOffer: SyncMessage?

    private var localPeerID: MCPeerID
    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?

    private var localIdentity: IdentityEntity?
    private var modelContext: ModelContext?

    // The offer WE sent (so we can process it on acceptance)
    private var sentOffer: SyncMessage?
    private var connectedPeer: MCPeerID?

    // Change-driven sync subscriptions
    private var cancellables = Set<AnyCancellable>()

    init(name: String, role: String) {
        self.localPeerID = MCPeerID(displayName: name)
        super.init()
    }

    // MARK: - Configuration

    func configure(identity: IdentityEntity, context: ModelContext) {
        self.localIdentity = identity
        self.modelContext = context
        self.localPeerID = MCPeerID(displayName: identity.name)
    }

    // MARK: - Discovery

    func startSearching() {
        guard let identity = localIdentity else { return }
        stopSearching()

        let session = MCSession(peer: localPeerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        self.session = session

        let discoveryInfo: [String: String] = [
            "name": identity.name,
            "role": identity.isTrainer ? "trainer" : "trainee"
        ]

        let advertiser = MCNearbyServiceAdvertiser(
            peer: localPeerID,
            discoveryInfo: discoveryInfo,
            serviceType: Self.serviceType
        )
        advertiser.delegate = self
        advertiser.startAdvertisingPeer()
        self.advertiser = advertiser

        let browser = MCNearbyServiceBrowser(peer: localPeerID, serviceType: Self.serviceType)
        browser.delegate = self
        browser.startBrowsingForPeers()
        self.browser = browser

        connectionState = .searching
        discoveredPeers = []
    }

    func stopSearching() {
        tearDownSyncSubscriptions()
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        session?.disconnect()
        advertiser = nil
        browser = nil
        session = nil
        connectedPeer = nil
        pendingOffer = nil
        sentOffer = nil
        connectionState = .idle
        discoveredPeers = []
    }

    // MARK: - Connection

    func connectToPeer(_ peer: DiscoveredPeer) {
        guard let session, let browser else { return }
        connectionState = .connecting
        browser.invitePeer(peer.peerID, to: session, withContext: nil, timeout: 30)
    }

    // MARK: - Symmetric Pairing

    func sendPairingOffer(linkedIdentityUUID: UUID?, linkedIdentityName: String?) {
        guard let session, let connectedPeer, let identity = localIdentity else { return }
        let offer = SyncMessage.pairingOffer(
            senderUUID: identity.id,
            senderName: identity.name,
            senderIsTrainer: identity.isTrainer,
            linkedIdentityUUID: linkedIdentityUUID,
            linkedIdentityName: linkedIdentityName
        )
        sentOffer = offer
        if let data = try? JSONEncoder().encode(offer) {
            try? session.send(data, toPeers: [connectedPeer], with: .reliable)
        }
        connectionState = .waitingForResponse(peerName: connectedPeer.displayName)
    }

    func acceptPairing(linkedIdentityUUID: UUID?, linkedIdentityName: String?) {
        guard let session, let connectedPeer, let identity = localIdentity,
              let context = modelContext else { return }

        // Build and send acceptance
        let accept = SyncMessage.pairingAccepted(
            responderUUID: identity.id,
            responderName: identity.name,
            responderIsTrainer: identity.isTrainer,
            linkedIdentityUUID: linkedIdentityUUID,
            linkedIdentityName: linkedIdentityName
        )

        // Process alias from the stored offer (responder side)
        if case .pairingOffer(let senderUUID, _, let senderIsTrainer, let linkedUUID, _) = pendingOffer {
            if let linkedUUID, linkedUUID != identity.id {
                IdentityReconciliation.createAlias(id1: linkedUUID, id2: identity.id, in: context)
            }
            // Create TrainerTrainees if this is a new relationship
            let trainerUUID = senderIsTrainer ? senderUUID : identity.id
            let traineeUUID = senderIsTrainer ? identity.id : senderUUID
            createTrainerTraineesIfNeeded(trainerUUID: trainerUUID, traineeUUID: traineeUUID, in: context)
        }

        if let data = try? JSONEncoder().encode(accept) {
            try? session.send(data, toPeers: [connectedPeer], with: .reliable)
        }

        pendingOffer = nil
        performSync()
    }

    func declinePairing() {
        guard let session, let connectedPeer else { return }
        let message = SyncMessage.pairingDeclined
        if let data = try? JSONEncoder().encode(message) {
            try? session.send(data, toPeers: [connectedPeer], with: .reliable)
        }
        pendingOffer = nil
        sentOffer = nil
        connectionState = .searching
    }

    // MARK: - Pairing Helpers

    private func createTrainerTraineesIfNeeded(trainerUUID: UUID, traineeUUID: UUID, in context: ModelContext) {
        // Check if relationship already exists (possibly via alias)
        let trainerAliases = IdentityReconciliation.aliasGroup(for: trainerUUID, in: context)
        let traineeAliases = IdentityReconciliation.aliasGroup(for: traineeUUID, in: context)
        let trainerIds = Array(trainerAliases)
        let traineeIds = Array(traineeAliases)

        let existing = (try? context.fetch(FetchDescriptor<TrainerTrainees>(
            predicate: #Predicate { trainerIds.contains($0.trainerId) && traineeIds.contains($0.traineeId) }
        )))?.first

        if existing == nil {
            context.insert(TrainerTrainees(trainerId: trainerUUID, traineeId: traineeUUID))
        }
    }

    // MARK: - Full Sync

    func performSync() {
        guard let session, let connectedPeer,
              let identity = localIdentity,
              let context = modelContext else { return }

        connectionState = .syncing(peerName: connectedPeer.displayName)

        // Find the paired identity
        let pairedIdentity = findPairedIdentity(in: context)
        guard let pairedIdentity else {
            connectionState = .error("No paired identity found")
            return
        }

        // Build payload
        let payload = SyncPayloadBuilder.build(
            localIdentity: identity,
            pairedIdentity: pairedIdentity,
            context: context
        )

        // Encode and send as resource (streaming with progress)
        guard let data = try? JSONEncoder().encode(payload) else {
            connectionState = .error("Failed to encode sync data")
            return
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("sync-\(UUID().uuidString).json")
        do {
            try data.write(to: tempURL)
            session.sendResource(at: tempURL, withName: "sync-payload", toPeer: connectedPeer) { error in
                DispatchQueue.main.async {
                    try? FileManager.default.removeItem(at: tempURL)
                    if let error {
                        self.connectionState = .error("Send failed: \(error.localizedDescription)")
                    }
                    // State will update when we receive their payload back
                }
            }
        } catch {
            connectionState = .error("Failed to write sync file")
        }
    }

    // MARK: - Delta Sync

    private func sendEntityDelta(notifications: [Notification]) {
        guard let session, let connectedPeer,
              let identity = localIdentity,
              let context = modelContext else { return }

        // Collect changed entity type+id pairs from batched notifications
        var changedSets: [UUID] = []
        var changedWorkouts: [UUID] = []
        var changedIdentities: [UUID] = []
        var changedExercises: [UUID] = []
        var changedGroups: [UUID] = []

        for notification in notifications {
            guard let type = notification.userInfo?["type"] as? String,
                  let id = notification.userInfo?["id"] as? UUID else { continue }
            switch type {
            case "SetEntity": changedSets.append(id)
            case "WorkoutEntity": changedWorkouts.append(id)
            case "IdentityEntity": changedIdentities.append(id)
            case "ExerciseEntity": changedExercises.append(id)
            case "WorkoutGroupEntity": changedGroups.append(id)
            default: break
            }
        }

        // Fetch current state of each changed entity and build delta payload
        var setDTOs: [SetDTO] = []
        for id in Set(changedSets) {
            if let entity = (try? context.fetch(FetchDescriptor<SetEntity>(
                predicate: #Predicate { $0.id == id }
            )))?.first {
                setDTOs.append(entity.toDTO())
            }
        }

        var workoutDTOs: [WorkoutDTO] = []
        for id in Set(changedWorkouts) {
            if let entity = (try? context.fetch(FetchDescriptor<WorkoutEntity>(
                predicate: #Predicate { $0.id == id }
            )))?.first {
                workoutDTOs.append(entity.toDTO())
            }
        }

        var identityDTOs: [IdentityDTO] = []
        for id in Set(changedIdentities) {
            if let entity = (try? context.fetch(FetchDescriptor<IdentityEntity>(
                predicate: #Predicate { $0.id == id }
            )))?.first {
                identityDTOs.append(entity.toDTO())
            }
        }

        var exerciseDTOs: [ExerciseDTO] = []
        for id in Set(changedExercises) {
            if let entity = (try? context.fetch(FetchDescriptor<ExerciseEntity>(
                predicate: #Predicate { $0.id == id }
            )))?.first {
                exerciseDTOs.append(entity.toDTO())
            }
        }

        var groupDTOs: [WorkoutGroupDTO] = []
        for id in Set(changedGroups) {
            if let entity = (try? context.fetch(FetchDescriptor<WorkoutGroupEntity>(
                predicate: #Predicate { $0.id == id }
            )))?.first {
                groupDTOs.append(entity.toDTO())
            }
        }

        // Skip if nothing to send
        guard !setDTOs.isEmpty || !workoutDTOs.isEmpty || !identityDTOs.isEmpty
                || !exerciseDTOs.isEmpty || !groupDTOs.isEmpty else { return }

        // Always include sender's own identity so merge() can determine senderIsTrainer
        let senderDTO = identity.toDTO()
        if !identityDTOs.contains(where: { $0.id == senderDTO.id }) {
            identityDTOs.append(senderDTO)
        }

        let payload = SyncPayload.delta(
            senderIdentityId: identity.id,
            identities: identityDTOs,
            exercises: exerciseDTOs,
            workouts: workoutDTOs,
            workoutGroups: groupDTOs,
            sets: setDTOs
        )

        let message = SyncMessage.entityUpdates(payload)
        guard let data = try? JSONEncoder().encode(message) else { return }
        try? session.send(data, toPeers: [connectedPeer], with: .reliable)
    }

    // MARK: - Change-driven sync subscriptions

    private func setupSyncSubscriptions() {
        tearDownSyncSubscriptions()

        // Entity updates: batch by 500ms, then send delta
        NotificationCenter.default.publisher(for: SyncTrigger.entityUpdatedNotification)
            .collect(.byTime(DispatchQueue.main, .milliseconds(500)))
            .sink { [weak self] notifications in
                self?.sendEntityDelta(notifications: notifications)
            }
            .store(in: &cancellables)

        // Structural changes: debounce by 1s, then full sync
        NotificationCenter.default.publisher(for: SyncTrigger.structureChangedNotification)
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.performSync()
            }
            .store(in: &cancellables)
    }

    private func tearDownSyncSubscriptions() {
        cancellables.removeAll()
    }

    private func findPairedIdentity(in context: ModelContext) -> IdentityEntity? {
        guard let identity = localIdentity else { return nil }
        if identity.isTrainer {
            // Find trainee we're connected to via PairedDevices
            let localId = identity.id
            if let pairing = (try? context.fetch(FetchDescriptor<PairedDevices>(
                predicate: #Predicate { $0.localIdentityId == localId }
            )))?.first {
                let remoteId = pairing.remoteIdentityId
                // Try direct lookup first
                if let direct = (try? context.fetch(FetchDescriptor<IdentityEntity>(
                    predicate: #Predicate { $0.id == remoteId }
                )))?.first {
                    return direct
                }
                // Fall back to alias group lookup
                let aliasIds = Array(IdentityReconciliation.aliasGroup(for: remoteId, in: context))
                return (try? context.fetch(FetchDescriptor<IdentityEntity>(
                    predicate: #Predicate { aliasIds.contains($0.id) }
                )))?.first
            }
            // Fallback: if single trainee, use them
            let trainees = identity.trainees(in: context)
            return trainees.count == 1 ? trainees.first : nil
        } else {
            // Trainee: find trainer
            return identity.trainer(in: context)
        }
    }

    // MARK: - Receive payload

    private func handleReceivedPayload(at url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let payload = try JSONDecoder().decode(SyncPayload.self, from: data)
            // Merge on main thread for SwiftData thread safety
            DispatchQueue.main.async {
                guard let context = self.modelContext else { return }
                let result = SyncEngine.merge(payload, into: context)
                self.lastSyncResult = result
                if let peer = self.connectedPeer {
                    self.connectionState = .connected(peerName: peer.displayName)
                    self.updatePairedDevices(senderIdentityId: payload.senderIdentityId)
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.connectionState = .error("Failed to process sync data")
            }
        }
        try? FileManager.default.removeItem(at: url)
    }

    private func handleReceivedDelta(_ payload: SyncPayload) {
        DispatchQueue.main.async {
            guard let context = self.modelContext else { return }
            let result = SyncEngine.merge(payload, into: context)
            self.lastSyncResult = result
        }
    }

    private func updatePairedDevices(senderIdentityId: UUID) {
        guard let context = modelContext, let identity = localIdentity else { return }
        let localId = identity.id
        let remoteId = senderIdentityId
        let existing = (try? context.fetch(FetchDescriptor<PairedDevices>(
            predicate: #Predicate { $0.localIdentityId == localId && $0.remoteIdentityId == remoteId }
        )))?.first
        if let existing {
            existing.lastSyncDate = .now
        } else {
            let pairing = PairedDevices(
                localIdentityId: localId,
                remoteIdentityId: remoteId,
                remoteName: connectedPeer?.displayName ?? "Unknown"
            )
            pairing.lastSyncDate = .now
            context.insert(pairing)
        }
    }

    // MARK: - Message handling

    private func handleMessage(_ data: Data, from peer: MCPeerID) {
        guard let message = try? JSONDecoder().decode(SyncMessage.self, from: data) else { return }
        DispatchQueue.main.async {
            switch message {
            case .pairingOffer:
                // Store offer transiently — no DB writes
                self.pendingOffer = message
                self.connectionState = .pairing(peerName: peer.displayName)

            case .pairingAccepted(let responderUUID, _, let responderIsTrainer, let linkedUUID, _):
                guard let context = self.modelContext, let identity = self.localIdentity else { return }

                // Process alias from their acceptance
                if let linkedUUID, linkedUUID != identity.id {
                    IdentityReconciliation.createAlias(id1: linkedUUID, id2: identity.id, in: context)
                }

                // Process alias from our own offer
                if case .pairingOffer(_, _, _, let ourLinkedUUID, _) = self.sentOffer {
                    if let ourLinkedUUID, ourLinkedUUID != responderUUID {
                        IdentityReconciliation.createAlias(id1: ourLinkedUUID, id2: responderUUID, in: context)
                    }
                }

                // Create TrainerTrainees if new relationship
                let senderIsTrainer = identity.isTrainer
                let trainerUUID = senderIsTrainer ? identity.id : responderUUID
                let traineeUUID = senderIsTrainer ? responderUUID : identity.id
                self.createTrainerTraineesIfNeeded(trainerUUID: trainerUUID, traineeUUID: traineeUUID, in: context)

                self.sentOffer = nil
                self.performSync()

            case .pairingDeclined:
                self.pendingOffer = nil
                self.sentOffer = nil
                self.connectionState = .searching

            case .entityUpdates(let payload):
                self.handleReceivedDelta(payload)
            }
        }
    }

    /// Whether the current connection has a paired device stored
    var isPairedWithConnectedPeer: Bool {
        guard let context = modelContext, let identity = localIdentity else { return false }
        let localId = identity.id
        return ((try? context.fetch(FetchDescriptor<PairedDevices>(
            predicate: #Predicate { $0.localIdentityId == localId }
        )))?.first) != nil
    }
}

// MARK: - MCSessionDelegate

extension SyncSessionManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            switch state {
            case .connected:
                self.connectedPeer = peerID
                if self.isPairedWithConnectedPeer {
                    self.connectionState = .connected(peerName: peerID.displayName)
                    self.performSync()
                    self.setupSyncSubscriptions()
                } else {
                    self.connectionState = .connected(peerName: peerID.displayName)
                }
            case .notConnected:
                if self.connectedPeer == peerID {
                    self.connectedPeer = nil
                    self.tearDownSyncSubscriptions()
                    self.pendingOffer = nil
                    self.sentOffer = nil
                    self.connectionState = .searching
                }
            case .connecting:
                self.connectionState = .connecting
            @unknown default:
                break
            }
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        handleMessage(data, from: peerID)
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        // Not used
    }

    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        // Could publish progress for UI
    }

    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        guard let localURL, error == nil else { return }
        handleReceivedPayload(at: localURL)
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension SyncSessionManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        let name = info?["name"] ?? peerID.displayName
        let role = info?["role"] ?? "unknown"
        let peer = DiscoveredPeer(peerID: peerID, name: name, role: role)
        DispatchQueue.main.async {
            if !self.discoveredPeers.contains(where: { $0.peerID == peerID }) {
                self.discoveredPeers.append(peer)
            }
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        DispatchQueue.main.async {
            self.discoveredPeers.removeAll { $0.peerID == peerID }
        }
    }
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension SyncSessionManager: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // Auto-accept invitations (both devices are on the sync screen)
        invitationHandler(true, session)
    }
}
