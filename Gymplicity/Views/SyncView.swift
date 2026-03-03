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
                        dismiss()
                    }
                }
            }
            .onAppear {
                syncManager.configureIfNeeded(identity: identity, context: modelContext)
                syncManager.startSearchingIfNeeded()
            }
        }
    }

    // MARK: - State Views

    private var idleView: some View {
        VStack(spacing: GymMetrics.space16) {
            Spacer()
            AnimatedMascotView(pose: .waving, animation: .wave, color: GymColors.energy)
                .frame(height: GymMetrics.mascotMedium)
            Text("Hey, want to find a friend?")
                .font(GymFont.heading2)
            Text("Tap to start searching for nearby devices")
                .font(GymFont.body)
                .foregroundStyle(GymColors.secondaryText)
            Button("Start Searching") {
                syncManager.configureIfNeeded(identity: identity, context: modelContext)
                syncManager.startSearchingIfNeeded()
            }
            .buttonStyle(.gymPrimary)
            .padding(.horizontal, 40)
            Spacer()
        }
    }

    private var searchingView: some View {
        VStack(spacing: 20) {
            if syncManager.discoveredPeers.isEmpty {
                Spacer()
                AnimatedMascotView(pose: .stretching, animation: .wobble, color: GymColors.secondaryText)
                    .frame(height: GymMetrics.mascotMedium)
                Text("Looking for nearby devices...")
                    .font(GymFont.body)
                    .foregroundStyle(GymColors.secondaryText)
                Text("Make sure the other device has Gymplicity open")
                    .font(GymFont.caption)
                    .foregroundStyle(GymColors.tertiaryText)
                    .multilineTextAlignment(.center)
                Spacer()
            } else {
                List {
                    Section {
                        ForEach(syncManager.discoveredPeers) { peer in
                            Button {
                                handlePeerTap(peer)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(peer.name)
                                            .font(GymFont.body)
                                        Text(peer.role.capitalized)
                                            .font(GymFont.caption)
                                            .foregroundStyle(GymColors.secondaryText)
                                    }
                                    Spacer()
                                    if isPaired(with: peer) {
                                        Text("Paired")
                                            .gymPill(GymColors.power)
                                    } else {
                                        Text("New")
                                            .gymPill(GymColors.focus)
                                    }
                                    Image(systemName: "chevron.right")
                                        .font(GymFont.caption)
                                        .foregroundStyle(GymColors.secondaryText)
                                }
                            }
                            .foregroundStyle(.primary)
                        }
                    } header: {
                        HStack(spacing: GymMetrics.space4) {
                            MascotView(pose: .spotting, color: GymColors.secondaryText)
                                .frame(height: GymMetrics.mascotInline)
                            Text("Nearby Devices")
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
        VStack(spacing: GymMetrics.space16) {
            Spacer()
            AnimatedMascotView(pose: .walking, animation: .pulse, color: GymColors.energy)
                .frame(height: 80)
            Text("Connecting...")
                .font(GymFont.body)
                .foregroundStyle(GymColors.secondaryText)
            Spacer()
        }
    }

    @ViewBuilder
    private func pairingView(peerName: String) -> some View {
        if identity.isTrainer {
            VStack(spacing: GymMetrics.space16) {
                Spacer()
                AnimatedMascotView(pose: .stretching, animation: .wobble, color: GymColors.energy)
                    .frame(height: 80)
                Text("Waiting for \(peerName) to accept pairing...")
                    .font(GymFont.body)
                    .foregroundStyle(GymColors.secondaryText)
                Spacer()
            }
        } else {
            VStack(spacing: GymMetrics.space16) {
                Spacer()
                MascotView(pose: .spotting, color: GymColors.focus)
                    .frame(height: GymMetrics.mascotMedium)
                Text("\(peerName) wants to pair with you")
                    .font(GymFont.heading2)
                Text("This will link your account to their trainer profile")
                    .font(GymFont.body)
                    .foregroundStyle(GymColors.secondaryText)
                    .multilineTextAlignment(.center)
                HStack(spacing: GymMetrics.space16) {
                    Button("Decline") {
                        syncManager.stopSearching()
                        syncManager.startSearching()
                    }
                    .buttonStyle(.bordered)
                    Button("Accept") {
                        syncManager.acceptPairing()
                    }
                    .buttonStyle(.gymPrimary)
                }
                .padding(.horizontal, 40)
                Spacer()
            }
        }
    }

    private func syncingView(peerName: String) -> some View {
        VStack(spacing: GymMetrics.space16) {
            Spacer()
            AnimatedMascotView(pose: .curling, animation: .rep, color: GymColors.energy)
                .frame(height: 80)
            Text("Syncing with \(peerName)...")
                .font(GymFont.body)
                .foregroundStyle(GymColors.secondaryText)
            Spacer()
        }
    }

    private func connectedView(peerName: String) -> some View {
        VStack(spacing: GymMetrics.space16) {
            Spacer()
            AnimatedMascotView(pose: .celebrating, animation: .bounce, color: GymColors.power)
                .frame(height: GymMetrics.mascotMedium)
            Text("Connected to \(peerName)")
                .font(GymFont.heading2)

            if let result = syncManager.lastSyncResult {
                Text(result.summary)
                    .font(GymFont.body)
                    .foregroundStyle(GymColors.secondaryText)
            }

            Text("Background sync active")
                .font(GymFont.caption)
                .foregroundStyle(GymColors.tertiaryText)

            Button("Sync Now") {
                syncManager.performSync()
            }
            .buttonStyle(.bordered)
            Spacer()
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: GymMetrics.space16) {
            Spacer()
            MascotView(pose: .resting, color: GymColors.warning)
                .frame(height: 80)
            Text("Sync Error")
                .font(GymFont.heading2)
            Text(message)
                .font(GymFont.body)
                .foregroundStyle(GymColors.secondaryText)
                .multilineTextAlignment(.center)
            Button("Try Again") {
                syncManager.startSearching()
            }
            .buttonStyle(.gymPrimary)
            .padding(.horizontal, 40)
            Spacer()
        }
    }

    // MARK: - Helpers

    private func handlePeerTap(_ peer: DiscoveredPeer) {
        syncManager.connectToPeer(peer)
        if identity.isTrainer && !isPaired(with: peer) {
            showingTraineePicker = true
        }
    }

    private func isPaired(with peer: DiscoveredPeer) -> Bool {
        let localId = identity.id
        let pairings = (try? modelContext.fetch(FetchDescriptor<PairedDevices>(
            predicate: #Predicate { $0.localIdentityId == localId }
        ))) ?? []
        return pairings.contains { $0.remoteName == peer.name }
    }
}
