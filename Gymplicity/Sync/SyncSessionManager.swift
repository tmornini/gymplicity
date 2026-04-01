import Foundation
import MultipeerConnectivity
import SwiftData
import Combine

// MARK: - Connection State

enum SyncConnectionState: Equatable, Sendable {
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

struct DiscoveredPeer:
    Identifiable, @unchecked Sendable
{
    let peerID: MCPeerID
    let name: String?
    let role: String?
    let identityId: UUID?
    var id: MCPeerID { peerID }
}

// MARK: - Sync Session Manager

@MainActor
class SyncSessionManager:
    NSObject, ObservableObject
{
    private static let serviceType = "gymplicity"

    @Published var connectionState:
        SyncConnectionState = .idle
    @Published var discoveredPeers:
        [DiscoveredPeer] = []
    @Published var lastSyncResult: MergeResult?

    @Published var pendingOffer: SyncMessage?

    private var localPeerID: MCPeerID
    private var session: MCSession?
    private var advertiser:
        MCNearbyServiceAdvertiser?
    private var browser:
        MCNearbyServiceBrowser?

    private var localIdentity: IdentityEntity?
    private var modelContext: ModelContext?

    private var sentOffer: SyncMessage?
    private var connectedPeer: MCPeerID?

    private var cancellables =
        Set<AnyCancellable>()

    init(name: String, role: String) {
        self.localPeerID = MCPeerID(
            displayName: name
        )
        super.init()
    }

    // MARK: - Configuration

    func configure(
        identity: IdentityEntity,
        context: ModelContext
    ) {
        self.localIdentity = identity
        self.modelContext = context
        self.localPeerID = MCPeerID(
            displayName: identity.name
        )
    }

    // MARK: - Discovery

    func startSearching() {
        guard let identity = localIdentity
        else { return }
        stopSearching()

        let session = MCSession(
            peer: localPeerID,
            securityIdentity: nil,
            encryptionPreference: .required
        )
        session.delegate = self
        self.session = session

        let discoveryInfo: [String: String] = [
            "name": identity.name,
            "role": identity.isTrainer
                ? "trainer" : "trainee",
            "id": identity.id.uuidString
        ]

        let advertiser =
            MCNearbyServiceAdvertiser(
                peer: localPeerID,
                discoveryInfo: discoveryInfo,
                serviceType: Self.serviceType
            )
        advertiser.delegate = self
        advertiser.startAdvertisingPeer()
        self.advertiser = advertiser

        let browser = MCNearbyServiceBrowser(
            peer: localPeerID,
            serviceType: Self.serviceType
        )
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
        guard let session, let browser
        else { return }
        connectionState = .connecting
        browser.invitePeer(
            peer.peerID,
            to: session,
            withContext: nil,
            timeout: GymMetrics.connectionTimeout
        )
    }

    // MARK: - Symmetric Pairing

    func sendPairingOffer(
        linkedIdentityUUID: UUID?,
        linkedIdentityName: String?
    ) {
        guard let session,
              let connectedPeer,
              let identity = localIdentity
        else { return }
        let offer = SyncMessage.pairingOffer(
            senderUUID: identity.id,
            senderName: identity.name,
            senderIsTrainer: identity.isTrainer,
            linkedIdentityUUID:
                linkedIdentityUUID,
            linkedIdentityName:
                linkedIdentityName
        )
        sentOffer = offer
        sendMessage(offer, via: session, to: connectedPeer)
        connectionState = .waitingForResponse(
            peerName: connectedPeer.displayName
        )
    }

    func acceptPairing(
        linkedIdentityUUID: UUID?,
        linkedIdentityName: String?
    ) {
        guard let session,
              let connectedPeer,
              let identity = localIdentity,
              let context = modelContext
        else { return }

        let accept =
            SyncMessage.pairingAccepted(
                responderUUID: identity.id,
                responderName: identity.name,
                responderIsTrainer:
                    identity.isTrainer,
                linkedIdentityUUID:
                    linkedIdentityUUID,
                linkedIdentityName:
                    linkedIdentityName
            )

        if case .pairingOffer(
            let senderUUID,
            _,
            let senderIsTrainer,
            let linkedUUID,
            _
        ) = pendingOffer {
            if let linkedUUID,
               linkedUUID != identity.id
            {
                IdentityReconciliation
                    .createAlias(
                        id1: linkedUUID,
                        id2: identity.id,
                        in: context
                    )
            }
            let trainerUUID = senderIsTrainer
                ? senderUUID : identity.id
            let traineeUUID = senderIsTrainer
                ? identity.id : senderUUID
            createTrainerTraineesIfNeeded(
                trainerUUID: trainerUUID,
                traineeUUID: traineeUUID,
                in: context
            )
        }

        sendMessage(accept, via: session, to: connectedPeer)

        pendingOffer = nil
        performSync()
    }

    func declinePairing() {
        guard let session, let connectedPeer
        else { return }
        sendMessage(
            .pairingDeclined,
            via: session,
            to: connectedPeer
        )
        pendingOffer = nil
        sentOffer = nil
        connectionState = .searching
    }

    // MARK: - Message Encoding

    private func sendMessage(
        _ message: SyncMessage,
        via session: MCSession,
        to peer: MCPeerID
    ) {
        let data: Data
        do {
            data = try JSONEncoder()
                .encode(message)
        } catch {
            connectionState = .error(
                "Encode failed: \(error)"
            )
            return
        }
        do {
            try session.send(
                data,
                toPeers: [peer],
                with: .reliable
            )
        } catch {
            connectionState = .error(
                "Send failed: \(error)"
            )
        }
    }

    // MARK: - Pairing Helpers

    private func createTrainerTraineesIfNeeded(
        trainerUUID: UUID,
        traineeUUID: UUID,
        in context: ModelContext
    ) {
        let trainerAliases =
            IdentityReconciliation.aliasGroup(
                for: trainerUUID,
                in: context
            )
        let traineeAliases =
            IdentityReconciliation.aliasGroup(
                for: traineeUUID,
                in: context
            )
        let trainerIds = Array(trainerAliases)
        let traineeIds = Array(traineeAliases)

        let existing = context.fetchFirst(
            FetchDescriptor<TrainerTrainees>(
                predicate: #Predicate {
                    trainerIds.contains(
                        $0.trainerId
                    )
                    && traineeIds.contains(
                        $0.traineeId
                    )
                }
            )
        )

        if existing == nil {
            context.insert(
                TrainerTrainees(
                    trainerId: trainerUUID,
                    traineeId: traineeUUID
                )
            )
        }
    }

    // MARK: - Full Sync

    func performSync() {
        guard let session,
              let connectedPeer,
              let identity = localIdentity,
              let context = modelContext
        else { return }

        connectionState = .syncing(
            peerName: connectedPeer.displayName
        )

        let pairedIdentity =
            findPairedIdentity(in: context)
        guard let pairedIdentity else {
            connectionState = .error(
                "No paired identity found"
            )
            return
        }

        let payload = SyncPayloadBuilder.build(
            localIdentity: identity,
            pairedIdentity: pairedIdentity,
            context: context
        )

        let data: Data
        do {
            data = try JSONEncoder()
                .encode(payload)
        } catch {
            connectionState = .error(
                "Failed to encode sync data"
            )
            return
        }

        let tempURL = FileManager.default
            .temporaryDirectory
            .appendingPathComponent(
                "sync-\(UUID().uuidString).json"
            )
        do {
            try data.write(to: tempURL)
        } catch {
            connectionState = .error(
                "Failed to write sync file"
            )
            return
        }

        session.sendResource(
            at: tempURL,
            withName: "sync-payload",
            toPeer: connectedPeer
        ) { [weak self] error in
            Task { @MainActor in
                // Best-effort cleanup: temp file
                // removal is non-critical and does
                // not warrant surfacing to the user
                do {
                    try FileManager.default
                        .removeItem(at: tempURL)
                } catch {
                    assertionFailure(
                        "[SyncCleanup] \(error)"
                    )
                }
                if let error {
                    self?.connectionState =
                        .error(
                            "Send failed: "
                            + error
                                .localizedDescription
                        )
                }
            }
        }
    }

    // MARK: - Delta Sync

    private func sendEntityDelta(
        notifications: [Notification]
    ) {
        guard let session,
              let connectedPeer,
              let identity = localIdentity,
              let context = modelContext
        else { return }

        var changedSets: [UUID] = []
        var changedWorkouts: [UUID] = []
        var changedIdentities: [UUID] = []
        var changedExercises: [UUID] = []
        var changedGroups: [UUID] = []

        for notification in notifications {
            guard let type = notification
                .userInfo?["type"] as? String,
                let id = notification
                    .userInfo?["id"] as? UUID
            else { continue }
            switch type {
            case "SetEntity":
                changedSets.append(id)
            case "WorkoutEntity":
                changedWorkouts.append(id)
            case "IdentityEntity":
                changedIdentities.append(id)
            case "ExerciseEntity":
                changedExercises.append(id)
            case "WorkoutGroupEntity":
                changedGroups.append(id)
            default: break
            }
        }

        var setDTOs: [SetDTO] = []
        for id in Set(changedSets) {
            if let entity = context.fetchFirst(
                FetchDescriptor<SetEntity>(
                    predicate: #Predicate {
                        $0.id == id
                    }
                )
            ) {
                setDTOs.append(entity.toDTO())
            }
        }

        var workoutDTOs: [WorkoutDTO] = []
        for id in Set(changedWorkouts) {
            if let entity = context.fetchFirst(
                FetchDescriptor<WorkoutEntity>(
                    predicate: #Predicate {
                        $0.id == id
                    }
                )
            ) {
                workoutDTOs.append(
                    entity.toDTO()
                )
            }
        }

        var identityDTOs: [IdentityDTO] = []
        for id in Set(changedIdentities) {
            if let entity = context.fetchFirst(
                FetchDescriptor<IdentityEntity>(
                    predicate: #Predicate {
                        $0.id == id
                    }
                )
            ) {
                identityDTOs.append(
                    entity.toDTO()
                )
            }
        }

        var exerciseDTOs: [ExerciseDTO] = []
        for id in Set(changedExercises) {
            if let entity = context.fetchFirst(
                FetchDescriptor<ExerciseEntity>(
                    predicate: #Predicate {
                        $0.id == id
                    }
                )
            ) {
                exerciseDTOs.append(
                    entity.toDTO()
                )
            }
        }

        var groupDTOs: [WorkoutGroupDTO] = []
        for id in Set(changedGroups) {
            if let entity = context.fetchFirst(
                FetchDescriptor<WorkoutGroupEntity>(
                    predicate: #Predicate {
                        $0.id == id
                    }
                )
            ) {
                groupDTOs.append(
                    entity.toDTO()
                )
            }
        }

        guard !setDTOs.isEmpty
            || !workoutDTOs.isEmpty
            || !identityDTOs.isEmpty
            || !exerciseDTOs.isEmpty
            || !groupDTOs.isEmpty
        else { return }

        let senderDTO = identity.toDTO()
        if !identityDTOs.contains(where: {
            $0.id == senderDTO.id
        }) {
            identityDTOs.append(senderDTO)
        }

        let payload = SyncPayload.delta(
            senderIdentityId: identity.id,
            identities: identityDTOs,
            exercises: exerciseDTOs,
            workouts: workoutDTOs,
            workoutGroups: groupDTOs,
            sets: setDTOs,
            setCompletions: [],
            workoutCompletions: [],
            deviceSyncEvents: []
        )

        let message =
            SyncMessage.entityUpdates(payload)
        let data: Data
        do {
            data = try JSONEncoder()
                .encode(message)
        } catch {
            connectionState = .error(
                "Delta encode failed: \(error)"
            )
            return
        }
        do {
            try session.send(
                data,
                toPeers: [connectedPeer],
                with: .reliable
            )
        } catch {
            connectionState = .error(
                "Delta send failed: \(error)"
            )
        }
    }

    // MARK: - Change-driven sync subscriptions

    private func setupSyncSubscriptions() {
        tearDownSyncSubscriptions()

        NotificationCenter.default
            .publisher(
                for: SyncTrigger
                    .entityUpdatedNotification
            )
            .collect(.byTime(
                DispatchQueue.main,
                .milliseconds(GymMetrics.deltaCollectMs)
            ))
            .sink { [weak self] notifications in
                self?.sendEntityDelta(
                    notifications: notifications
                )
            }
            .store(in: &cancellables)

        NotificationCenter.default
            .publisher(
                for: SyncTrigger
                    .structureChangedNotification
            )
            .debounce(
                for: .seconds(Int(GymMetrics.deltaDebounce)),
                scheduler: DispatchQueue.main
            )
            .sink { [weak self] _ in
                self?.performSync()
            }
            .store(in: &cancellables)
    }

    private func tearDownSyncSubscriptions() {
        cancellables.removeAll()
    }

    private func findPairedIdentity(
        in context: ModelContext
    ) -> IdentityEntity? {
        guard let identity = localIdentity
        else { return nil }
        if identity.isTrainer {
            let localId = identity.id
            if let pairing = context.fetchFirst(
                FetchDescriptor<PairedDevices>(
                    predicate: #Predicate {
                        $0.localIdentityId
                            == localId
                    }
                )
            ) {
                let remoteId =
                    pairing.remoteIdentityId
                if let direct =
                    context.fetchFirst(
                        FetchDescriptor<
                            IdentityEntity
                        >(
                            predicate: #Predicate {
                                $0.id == remoteId
                            }
                        )
                    )
                {
                    return direct
                }
                let aliasIds = Array(
                    IdentityReconciliation
                        .aliasGroup(
                            for: remoteId,
                            in: context
                        )
                )
                return context.fetchFirst(
                    FetchDescriptor<
                        IdentityEntity
                    >(
                        predicate: #Predicate {
                            aliasIds
                                .contains($0.id)
                        }
                    )
                )
            }
            let trainees =
                identity.trainees(in: context)
            return trainees.count == 1
                ? trainees.first : nil
        } else {
            return identity.trainer(in: context)
        }
    }

    // MARK: - Receive payload

    private func handleReceivedPayload(
        at url: URL
    ) {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            connectionState = .error(
                "Failed to read sync file"
            )
            return
        }

        let payload: SyncPayload
        do {
            payload = try JSONDecoder()
                .decode(
                    SyncPayload.self,
                    from: data
                )
        } catch {
            connectionState = .error(
                "Failed to decode sync data"
            )
            return
        }

        guard let context = self.modelContext
        else { return }
        let result = SyncEngine.merge(
            payload,
            into: context
        )
        self.lastSyncResult = result
        if let peer = self.connectedPeer {
            self.connectionState = .connected(
                peerName: peer.displayName
            )
            self.updatePairedDevices(
                senderIdentityId:
                    payload.senderIdentityId
            )
        }

        // Best-effort cleanup: temp file removal
        // is non-critical and does not warrant
        // surfacing to the user
        do {
            try FileManager.default
                .removeItem(at: url)
        } catch {
            assertionFailure(
                "[SyncCleanup] \(error)"
            )
        }
    }

    private func handleReceivedDelta(
        _ payload: SyncPayload
    ) {
        guard let context = self.modelContext
        else { return }
        let result = SyncEngine.merge(
            payload,
            into: context
        )
        self.lastSyncResult = result
    }

    private func updatePairedDevices(
        senderIdentityId: UUID
    ) {
        guard let context = modelContext,
              let identity = localIdentity,
              connectedPeer != nil
        else { return }
        let localId = identity.id
        let remoteId = senderIdentityId
        let existing = context.fetchFirst(
            FetchDescriptor<PairedDevices>(
                predicate: #Predicate {
                    $0.localIdentityId
                        == localId
                    && $0.remoteIdentityId
                        == remoteId
                }
            )
        )
        if existing == nil {
            context.insert(PairedDevices(
                localIdentityId: localId,
                remoteIdentityId: remoteId
            ))
        }
        context.insert(DeviceSyncEvents(
            localIdentityId: localId,
            remoteIdentityId: remoteId,
            syncedAt: .now
        ))
    }

    // MARK: - Message handling

    private func handleMessage(
        _ data: Data,
        from peer: MCPeerID
    ) {
        let message: SyncMessage
        do {
            message = try JSONDecoder()
                .decode(
                    SyncMessage.self,
                    from: data
                )
        } catch {
            connectionState = .error(
                "Decode failed: \(error)"
            )
            return
        }

        switch message {
        case .pairingOffer:
            self.pendingOffer = message
            self.connectionState = .pairing(
                peerName: peer.displayName
            )

        case .pairingAccepted(
            let responderUUID,
            _,
            _,
            let linkedUUID,
            _
        ):
            guard let context = self.modelContext,
                  let identity = self.localIdentity
            else { return }

            if let linkedUUID,
               linkedUUID != identity.id
            {
                IdentityReconciliation
                    .createAlias(
                        id1: linkedUUID,
                        id2: identity.id,
                        in: context
                    )
            }

            if case .pairingOffer(
                _, _, _,
                let ourLinkedUUID,
                _
            ) = self.sentOffer {
                if let ourLinkedUUID,
                   ourLinkedUUID != responderUUID
                {
                    IdentityReconciliation
                        .createAlias(
                            id1: ourLinkedUUID,
                            id2: responderUUID,
                            in: context
                        )
                }
            }

            let senderIsTrainer =
                identity.isTrainer
            let trainerUUID = senderIsTrainer
                ? identity.id : responderUUID
            let traineeUUID = senderIsTrainer
                ? responderUUID : identity.id
            self.createTrainerTraineesIfNeeded(
                trainerUUID: trainerUUID,
                traineeUUID: traineeUUID,
                in: context
            )

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

    var isPairedWithConnectedPeer: Bool {
        guard let context = modelContext,
              let identity = localIdentity
        else { return false }
        let localId = identity.id
        return context.fetchFirst(
            FetchDescriptor<PairedDevices>(
                predicate: #Predicate {
                    $0.localIdentityId == localId
                }
            )
        ) != nil
    }
}

// MARK: - MCSessionDelegate

extension SyncSessionManager: MCSessionDelegate {
    nonisolated func session(
        _ session: MCSession,
        peer peerID: MCPeerID,
        didChange state: MCSessionState
    ) {
        nonisolated(unsafe) let peerID = peerID
        Task { @MainActor in
            switch state {
            case .connected:
                self.connectedPeer = peerID
                if self
                    .isPairedWithConnectedPeer
                {
                    self.connectionState =
                        .connected(
                            peerName:
                                peerID.displayName
                        )
                    self.performSync()
                    self
                        .setupSyncSubscriptions()
                } else {
                    self.connectionState =
                        .connected(
                            peerName:
                                peerID.displayName
                        )
                }
            case .notConnected:
                if self.connectedPeer == peerID
                {
                    self.connectedPeer = nil
                    self
                        .tearDownSyncSubscriptions()
                    self.pendingOffer = nil
                    self.sentOffer = nil
                    self.connectionState =
                        .searching
                }
            case .connecting:
                self.connectionState =
                    .connecting
            @unknown default:
                break
            }
        }
    }

    nonisolated func session(
        _ session: MCSession,
        didReceive data: Data,
        fromPeer peerID: MCPeerID
    ) {
        nonisolated(unsafe) let peerID = peerID
        Task { @MainActor in
            handleMessage(data, from: peerID)
        }
    }

    nonisolated func session(
        _ session: MCSession,
        didReceive stream: InputStream,
        withName streamName: String,
        fromPeer peerID: MCPeerID
    ) {
        // Not used
    }

    nonisolated func session(
        _ session: MCSession,
        didStartReceivingResourceWithName
            resourceName: String,
        fromPeer peerID: MCPeerID,
        with progress: Progress
    ) {
        // Could publish progress for UI
    }

    nonisolated func session(
        _ session: MCSession,
        didFinishReceivingResourceWithName
            resourceName: String,
        fromPeer peerID: MCPeerID,
        at localURL: URL?,
        withError error: Error?
    ) {
        guard let localURL, error == nil
        else { return }
        Task { @MainActor in
            handleReceivedPayload(at: localURL)
        }
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension SyncSessionManager:
    MCNearbyServiceBrowserDelegate
{
    nonisolated func browser(
        _ browser: MCNearbyServiceBrowser,
        foundPeer peerID: MCPeerID,
        withDiscoveryInfo info:
            [String: String]?
    ) {
        let name = info?["name"]
        let role = info?["role"]
        let identityId = info?["id"]
            .flatMap { UUID(uuidString: $0) }
        let peer = DiscoveredPeer(
            peerID: peerID,
            name: name,
            role: role,
            identityId: identityId
        )
        nonisolated(unsafe) let peerID = peerID
        Task { @MainActor in
            if !self.discoveredPeers
                .contains(where: {
                    $0.peerID == peerID
                })
            {
                self.discoveredPeers
                    .append(peer)
            }
        }
    }

    nonisolated func browser(
        _ browser: MCNearbyServiceBrowser,
        lostPeer peerID: MCPeerID
    ) {
        nonisolated(unsafe) let peerID = peerID
        Task { @MainActor in
            self.discoveredPeers.removeAll {
                $0.peerID == peerID
            }
        }
    }
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension SyncSessionManager:
    MCNearbyServiceAdvertiserDelegate
{
    nonisolated func advertiser(
        _ advertiser:
            MCNearbyServiceAdvertiser,
        didReceiveInvitationFromPeer
            peerID: MCPeerID,
        withContext context: Data?,
        invitationHandler: @escaping (
            Bool, MCSession?
        ) -> Void
    ) {
        nonisolated(unsafe)
            let invitationHandler =
                invitationHandler
        Task { @MainActor in
            invitationHandler(true, session)
        }
    }
}
