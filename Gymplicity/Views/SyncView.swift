import SwiftUI
import SwiftData

struct SyncView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var syncManager: SyncSessionManager
    let identity: IdentityEntity
    @State private var selectedTrainee: IdentityEntity?
    @State private var showingTraineePicker = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                switch syncManager.connectionState {
                case .idle:
                    idleView
                case .searching:
                    searchingView
                case .connecting:
                    connectingView
                case .pairing(let peerName):
                    pairingView(peerName: peerName)
                case .syncing(let peerName):
                    syncingView(peerName: peerName)
                case .connected(let peerName):
                    connectedView(peerName: peerName)
                case .error(let message):
                    errorView(message: message)
                }
            }
            .padding()
            .navigationTitle("Sync")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        syncManager.stopSearching()
                        dismiss()
                    }
                }
            }
            .onAppear {
                syncManager.configure(identity: identity, context: modelContext)
                syncManager.startSearching()
            }
            .onDisappear {
                syncManager.stopSearching()
            }
        }
    }

    // MARK: - State Views

    private var idleView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.wave.2")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Tap to start searching for nearby devices")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Start Searching") {
                syncManager.configure(identity: identity, context: modelContext)
                syncManager.startSearching()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var searchingView: some View {
        VStack(spacing: 20) {
            if syncManager.discoveredPeers.isEmpty {
                Spacer()
                ProgressView()
                    .scaleEffect(1.2)
                Text("Looking for nearby devices...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Make sure both devices have the sync screen open")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                Spacer()
            } else {
                List {
                    Section("Nearby Devices") {
                        ForEach(syncManager.discoveredPeers) { peer in
                            Button {
                                handlePeerTap(peer)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(peer.name)
                                            .font(.body)
                                        Text(peer.role.capitalized)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if isPaired(with: peer) {
                                        Text("Paired")
                                            .font(.caption)
                                            .foregroundStyle(.green)
                                    } else {
                                        Text("New")
                                            .font(.caption)
                                            .foregroundStyle(.blue)
                                    }
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .foregroundStyle(.primary)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .confirmationDialog("Select Trainee", isPresented: $showingTraineePicker) {
            let trainees = identity.trainees(in: modelContext)
            ForEach(trainees) { trainee in
                Button(trainee.name) {
                    selectedTrainee = trainee
                    if let trainee = selectedTrainee {
                        syncManager.sendPairingRequest(traineeUUID: trainee.id)
                    }
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Which trainee is this device?")
        }
    }

    private var connectingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Connecting...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func pairingView(peerName: String) -> some View {
        if identity.isTrainer {
            // Trainer is waiting for trainee to accept
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                Text("Waiting for \(peerName) to accept pairing...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } else {
            // Trainee sees pairing request
            VStack(spacing: 16) {
                Image(systemName: "person.2.circle")
                    .font(.system(size: 48))
                    .foregroundStyle(.blue)
                Text("\(peerName) wants to pair with you")
                    .font(.headline)
                Text("This will link your account to their trainer profile")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                HStack(spacing: 16) {
                    Button("Decline") {
                        syncManager.stopSearching()
                        syncManager.startSearching()
                    }
                    .buttonStyle(.bordered)
                    Button("Accept") {
                        syncManager.acceptPairing()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    private func syncingView(peerName: String) -> some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Syncing with \(peerName)...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func connectedView(peerName: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            Text("Connected to \(peerName)")
                .font(.headline)

            if let result = syncManager.lastSyncResult {
                Text(result.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text("Background sync active")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Button("Sync Now") {
                syncManager.performSync()
            }
            .buttonStyle(.bordered)
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            Text("Sync Error")
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Try Again") {
                syncManager.startSearching()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Helpers

    private func handlePeerTap(_ peer: DiscoveredPeer) {
        syncManager.connectToPeer(peer)
        // If trainer and not paired, show trainee picker after connection
        if identity.isTrainer && !isPaired(with: peer) {
            showingTraineePicker = true
        }
    }

    private func isPaired(with peer: DiscoveredPeer) -> Bool {
        let localId = identity.id
        let pairings = (try? modelContext.fetch(FetchDescriptor<PairedDevices>(
            predicate: #Predicate { $0.localIdentityId == localId }
        ))) ?? []
        // Check if any pairing matches this peer name
        return pairings.contains { $0.remoteName == peer.name }
    }
}
