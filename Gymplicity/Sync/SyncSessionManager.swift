import Foundation
import MultipeerConnectivity
import SwiftData
import Combine

// MARK: - Sync Message (lightweight handshake messages via send())

enum SyncMessage: Codable {
    case pairingRequest(traineeUUID: UUID, trainerName: String)
    case pairingAccepted
}

// MARK: - Connection State

enum SyncConnectionState: Equatable {
    case idle
    case searching
    case connecting
    case pairing(peerName: String)
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
    @Published var isConfigured = false

    private var localPeerID: MCPeerID
    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?

    private var localIdentity: IdentityEntity?
    private var modelContext: ModelContext?
    private var syncTimer: Timer?

    // Pairing state
    private var pendingPairingTraineeUUID: UUID?
    private var connectedPeer: MCPeerID?

    init(name: String, role: String) {
        self.localPeerID = MCPeerID(displayName: name)
        super.init()
    }

    // MARK: - Configuration

    func configure(identity: IdentityEntity, context: ModelContext) {
        self.localIdentity = identity
        self.modelContext = context
        self.localPeerID = MCPeerID(displayName: identity.name)
        self.isConfigured = true
    }

    func configureIfNeeded(identity: IdentityEntity, context: ModelContext) {
        guard !isConfigured else { return }
        configure(identity: identity, context: context)
    }

    // MARK: - Auto Sync

    func startAutoSync(container: ModelContainer) {
        guard !isConfigured else {
            startSearchingIfNeeded()
            return
        }

        let context = ModelContext(container)
        guard let identity = (try? context.fetch(FetchDescriptor<IdentityEntity>()))?.first else {
            return
        }

        let localId = identity.id
        let hasPairedDevices = ((try? context.fetch(FetchDescriptor<PairedDevices>(
            predicate: #Predicate { $0.localIdentityId == localId }
        )))?.first) != nil

        guard hasPairedDevices else { return }

        configure(identity: identity, context: context)
        startSearching()
    }

    func startSearchingIfNeeded() {
        guard isConfigured, session == nil else { return }
        startSearching()
    }

    func isPairedWith(name: String) -> Bool {
        guard let context = modelContext, let identity = localIdentity else { return false }
        let localId = identity.id
        let pairings = (try? context.fetch(FetchDescriptor<PairedDevices>(
            predicate: #Predicate { $0.localIdentityId == localId }
        ))) ?? []
        return pairings.contains { $0.remoteName == name }
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
        syncTimer?.invalidate()
        syncTimer = nil
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        session?.disconnect()
        advertiser = nil
        browser = nil
        session = nil
        connectedPeer = nil
        connectionState = .idle
        discoveredPeers = []
    }

    // MARK: - Connection

    func connectToPeer(_ peer: DiscoveredPeer) {
        guard let session, let browser else { return }
        connectionState = .connecting
        browser.invitePeer(peer.peerID, to: session, withContext: nil, timeout: 30)
    }

    // MARK: - Pairing (trainer initiates)

    func sendPairingRequest(traineeUUID: UUID) {
        guard let session, let connectedPeer, let identity = localIdentity else { return }
        let message = SyncMessage.pairingRequest(traineeUUID: traineeUUID, trainerName: identity.name)
        if let data = try? JSONEncoder().encode(message) {
            try? session.send(data, toPeers: [connectedPeer], with: .reliable)
        }
        connectionState = .pairing(peerName: connectedPeer.displayName)
    }

    func acceptPairing() {
        guard let session, let connectedPeer else { return }
        // Perform identity rewrite if needed
        if let traineeUUID = pendingPairingTraineeUUID,
           let context = modelContext,
           let localIdentity {
            IdentityReconciliation.rewriteIdentity(from: localIdentity.id, to: traineeUUID, in: context)
            localIdentity.id = traineeUUID
        }
        // Send acceptance
        let message = SyncMessage.pairingAccepted
        if let data = try? JSONEncoder().encode(message) {
            try? session.send(data, toPeers: [connectedPeer], with: .reliable)
        }
        pendingPairingTraineeUUID = nil
        // Proceed to sync
        performSync()
    }

    // MARK: - Sync

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

    private func startBackgroundSync() {
        syncTimer?.invalidate()
        syncTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.performSync()
            }
        }
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
                return (try? context.fetch(FetchDescriptor<IdentityEntity>(
                    predicate: #Predicate { $0.id == remoteId }
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
        guard let context = modelContext else { return }
        do {
            let data = try Data(contentsOf: url)
            let payload = try JSONDecoder().decode(SyncPayload.self, from: data)
            let result = SyncEngine.put(payload, into: context)
            DispatchQueue.main.async {
                self.lastSyncResult = result
                if let peer = self.connectedPeer {
                    self.connectionState = .connected(peerName: peer.displayName)

                    // Update PairedDevices
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

    // MARK: - Handshake message handling

    private func handleMessage(_ data: Data, from peer: MCPeerID) {
        guard let message = try? JSONDecoder().decode(SyncMessage.self, from: data) else { return }
        DispatchQueue.main.async {
            switch message {
            case .pairingRequest(let traineeUUID, _):
                // Trainee receives this — store pending UUID for user confirmation
                self.pendingPairingTraineeUUID = traineeUUID
                self.connectionState = .pairing(peerName: peer.displayName)

            case .pairingAccepted:
                // Trainer receives this — proceed to sync
                self.performSync()
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
                    self.startBackgroundSync()
                } else {
                    self.connectionState = .connected(peerName: peerID.displayName)
                }
            case .notConnected:
                if self.connectedPeer == peerID {
                    self.connectedPeer = nil
                    self.syncTimer?.invalidate()
                    self.syncTimer = nil
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
            // Auto-connect to previously paired peers
            if self.connectedPeer == nil && self.isPairedWith(name: name) {
                self.connectToPeer(peer)
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
