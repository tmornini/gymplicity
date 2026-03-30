import SwiftUI
import SwiftData

struct SyncView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject
    private var syncManager: SyncSessionManager
    let identity: IdentityEntity
    @State private var showingMatchPicker = false
    @State private var showingOfferVerification = false

    var body: some View {
        NavigationStack {
            VStack(spacing: GymMetrics.space24) {
                switch syncManager.connectionState {
                case .idle:
                    idleView
                case .searching:
                    searchingView
                case .connecting:
                    connectingView
                case .pairing(let peerName):
                    pairingView(peerName: peerName)
                case .waitingForResponse(let peerName):
                    waitingView(peerName: peerName)
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
                syncManager.configure(
                    identity: identity,
                    context: modelContext
                )
                syncManager.startSearching()
            }
            .onDisappear {
                syncManager.stopSearching()
            }
        }
    }

    // MARK: - State Views

    private var idleView: some View {
        VStack(spacing: GymMetrics.space16) {
            Spacer()
            AnimatedMascotView(
                pose: .waving,
                animation: .wave,
                color: GymColors.energy
            )
            .frame(height: GymMetrics.mascotMedium)
            Text("Hey, want to find a friend?")
                .font(GymFont.heading2)
            Text(
                "Tap to start searching"
                    + " for nearby devices"
            )
            .font(GymFont.body)
            .foregroundStyle(GymColors.secondaryText)
            Button("Start Searching") {
                syncManager.configure(
                    identity: identity,
                    context: modelContext
                )
                syncManager.startSearching()
            }
            .buttonStyle(.gymPrimary)
            .padding(.horizontal, GymMetrics.actionPadding)
            Spacer()
        }
    }

    private var searchingView: some View {
        VStack(spacing: GymMetrics.space20) {
            if syncManager.discoveredPeers.isEmpty {
                Spacer()
                AnimatedMascotView(
                    pose: .stretching,
                    animation: .wobble,
                    color: GymColors.secondaryText
                )
                .frame(height: GymMetrics.mascotMedium)
                Text("Looking for nearby devices...")
                    .font(GymFont.body)
                    .foregroundStyle(GymColors.secondaryText)
                Text(
                    "Make sure both devices"
                        + " have the sync screen open"
                )
                .font(GymFont.caption)
                .foregroundStyle(GymColors.tertiaryText)
                    .multilineTextAlignment(.center)
                Spacer()
            } else {
                List {
                    Section {
                        ForEach(
                            syncManager.discoveredPeers
                        ) { peer in
                            Button {
                                handlePeerTap(peer)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: GymMetrics.space2) {
                                        Text(peer.name)
                                            .font(GymFont.body)
                                        Text(peer.role.capitalized)
                                            .font(GymFont.caption)
                                            .foregroundStyle(
                                                GymColors.secondaryText
                                            )
                                    }
                                    Spacer()
                                    if isPaired(with: peer) {
                                        Text("Paired")
                                            .gymPill(
                                                GymColors.power
                                            )
                                    } else {
                                        Text("New")
                                            .gymPill(
                                                GymColors.focus
                                            )
                                    }
                                    Image(
                                        systemName: "chevron.right"
                                    )
                                    .font(GymFont.caption)
                                    .foregroundStyle(
                                        GymColors.secondaryText
                                    )
                                }
                            }
                            .foregroundStyle(.primary)
                        }
                    } header: {
                        HStack(
                            spacing: GymMetrics.space4
                        ) {
                            MascotView(
                                pose: .waving,
                                color: GymColors
                                    .secondaryText
                            )
                            .frame(
                                height: GymMetrics
                                    .mascotInline
                            )
                            Text("Nearby Devices")
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .confirmationDialog(
            "Match Identity",
            isPresented: $showingMatchPicker
        ) {
            matchPickerButtons
        } message: {
            Text(matchPickerMessage)
        }
    }

    private var connectingView: some View {
        VStack(spacing: GymMetrics.space16) {
            Spacer()
            AnimatedMascotView(
                pose: .walking,
                animation: .pulse,
                color: GymColors.energy
            )
                .frame(height: GymMetrics.mascotCard)
            Text("Connecting...")
                .font(GymFont.body)
                .foregroundStyle(
                    GymColors.secondaryText
                )
            Spacer()
        }
    }

    @ViewBuilder
    private func pairingView(
        peerName: String
    ) -> some View {
        if let offer = syncManager.pendingOffer,
           case .pairingOffer(
               _,
               let senderName,
               let senderIsTrainer,
               _,
               let linkedName
           ) = offer {
            if let linkedName {
                // Verification step: sender linked us to a specific identity
                verificationView(
                    peerName: peerName,
                    senderName: senderName,
                    senderIsTrainer: senderIsTrainer,
                    linkedName: linkedName
                )
            } else {
                // No linked identity -- go straight to match-or-new
                matchOrNewView(
                    peerName: peerName,
                    senderName: senderName,
                    senderIsTrainer: senderIsTrainer
                )
            }
        } else {
            // Fallback
            VStack(spacing: GymMetrics.space16) {
                Spacer()
                AnimatedMascotView(
                    pose: .stretching,
                    animation: .wobble,
                    color: GymColors.energy
                )
                .frame(height: GymMetrics.mascotCard)
                Text(
                    "Pairing with \(peerName)..."
                )
                .font(GymFont.body)
                .foregroundStyle(
                    GymColors.secondaryText
                )
                Spacer()
            }
        }
    }

    private func verificationView(
        peerName: String,
        senderName: String,
        senderIsTrainer: Bool,
        linkedName: String
    ) -> some View {
        VStack(spacing: GymMetrics.space16) {
            Spacer()
            MascotView(
                pose: .waving,
                color: GymColors.focus
            )
            .frame(height: GymMetrics.mascotMedium)
            Text(
                "\(senderName)"
                    + " (\(senderIsTrainer ? "trainer" : "trainee"))"
                    + " wants to pair with you"
                    + " as \"\(linkedName)\""
            )
            .font(GymFont.heading2)
            .multilineTextAlignment(.center)
            Text("Is this you?")
                .font(GymFont.body)
                .foregroundStyle(
                    GymColors.secondaryText
                )
            HStack(spacing: GymMetrics.space16) {
                Button("That's not me") {
                    syncManager.declinePairing()
                }
                .buttonStyle(.bordered)
                Button("Yes, that's me") {
                    // Proceed to match-or-new
                    showingMatchPicker = true
                }
                .buttonStyle(.gymPrimary)
            }
            .padding(.horizontal, GymMetrics.actionPadding)
            Spacer()
        }
    }

    private func matchOrNewView(
        peerName: String,
        senderName: String,
        senderIsTrainer: Bool
    ) -> some View {
        VStack(spacing: GymMetrics.space16) {
            Spacer()
            MascotView(
                pose: .waving,
                color: GymColors.focus
            )
            .frame(height: GymMetrics.mascotMedium)
            Text(
                "\(senderName)"
                    + " (\(senderIsTrainer ? "trainer" : "trainee"))"
                    + " wants to pair"
            )
            .font(GymFont.heading2)
            .multilineTextAlignment(.center)
            Text(
                "Do you already have a"
                    + " profile for them?"
            )
                .font(GymFont.body)
                .foregroundStyle(
                    GymColors.secondaryText
                )
                .multilineTextAlignment(.center)

            VStack(spacing: GymMetrics.space8) {
                // Show existing profiles to match
                let candidates = matchCandidates(
                    forTrainer: senderIsTrainer
                )
                ForEach(candidates) { candidate in
                    Button {
                        syncManager.acceptPairing(
                            linkedIdentityUUID: candidate.id,
                            linkedIdentityName: candidate.name
                        )
                    } label: {
                        HStack {
                            Text(candidate.name)
                                .font(GymFont.body)
                            Spacer()
                            Image(
                                systemName:
                                    "checkmark.circle"
                            )
                        }
                        .padding(
                            .horizontal,
                            GymMetrics.space16
                        )
                        .padding(
                            .vertical,
                            GymMetrics.space12
                        )
                        .background(
                            GymColors.steel
                                .opacity(GymMetrics.opacityLight)
                        )
                        .cornerRadius(
                            GymMetrics.radiusMedium
                        )
                    }
                    .foregroundStyle(.primary)
                }

                Button(
                    "New -- first time connecting"
                ) {
                    syncManager.acceptPairing(
                        linkedIdentityUUID: nil,
                        linkedIdentityName: nil
                    )
                }
                .buttonStyle(.gymPrimary)
            }
            .padding(.horizontal, GymMetrics.space20)

            Button("Decline") {
                syncManager.declinePairing()
            }
            .foregroundStyle(
                GymColors.secondaryText
            )
            .padding(.top, GymMetrics.space8)

            Spacer()
        }
    }

    private func waitingView(
        peerName: String
    ) -> some View {
        VStack(spacing: GymMetrics.space16) {
            Spacer()
            AnimatedMascotView(
                pose: .stretching,
                animation: .wobble,
                color: GymColors.energy
            )
            .frame(height: GymMetrics.mascotCard)
            Text(
                "Waiting for \(peerName)"
                    + " to respond..."
            )
            .font(GymFont.body)
            .foregroundStyle(
                GymColors.secondaryText
            )
            Button("Cancel") {
                syncManager.declinePairing()
            }
            .buttonStyle(.bordered)
            Spacer()
        }
    }

    private func syncingView(
        peerName: String
    ) -> some View {
        VStack(spacing: GymMetrics.space16) {
            Spacer()
            AnimatedMascotView(
                pose: .curling,
                animation: .rep,
                color: GymColors.energy
            )
            .frame(height: GymMetrics.mascotCard)
            Text("Syncing with \(peerName)...")
                .font(GymFont.body)
                .foregroundStyle(
                    GymColors.secondaryText
                )
            Spacer()
        }
    }

    private func connectedView(
        peerName: String
    ) -> some View {
        VStack(spacing: GymMetrics.space16) {
            Spacer()
            AnimatedMascotView(
                pose: .celebrating,
                animation: .bounce,
                color: GymColors.power
            )
            .frame(height: GymMetrics.mascotMedium)
            Text("Connected to \(peerName)")
                .font(GymFont.heading2)

            if let result = syncManager.lastSyncResult {
                Text(result.summary)
                    .font(GymFont.body)
                    .foregroundStyle(
                        GymColors.secondaryText
                    )
            }

            Text("Background sync active")
                .font(GymFont.caption)
                .foregroundStyle(
                    GymColors.tertiaryText
                )

            Button("Sync Now") {
                syncManager.performSync()
            }
            .buttonStyle(.bordered)
            Spacer()
        }
    }

    private func errorView(
        message: String
    ) -> some View {
        VStack(spacing: GymMetrics.space16) {
            Spacer()
            MascotView(
                pose: .resting,
                color: GymColors.warning
            )
                .frame(height: GymMetrics.mascotCard)
            Text("Sync Error")
                .font(GymFont.heading2)
            Text(message)
                .font(GymFont.body)
                .foregroundStyle(
                    GymColors.secondaryText
                )
                .multilineTextAlignment(.center)
            Button("Try Again") {
                syncManager.startSearching()
            }
            .buttonStyle(.gymPrimary)
            .padding(.horizontal, GymMetrics.actionPadding)
            Spacer()
        }
    }

    // MARK: - Helpers

    private func handlePeerTap(
        _ peer: DiscoveredPeer
    ) {
        syncManager.connectToPeer(peer)
        if !isPaired(with: peer) {
            // Show match picker after connection is established
            showingMatchPicker = true
        }
    }

    private func isPaired(
        with peer: DiscoveredPeer
    ) -> Bool {
        guard let remoteId = peer.identityId
        else { return false }
        let localId = identity.id
        let pairings = modelContext.fetchOrEmpty(
            FetchDescriptor<PairedDevices>(
                predicate: #Predicate {
                    $0.localIdentityId == localId
                        && $0.remoteIdentityId
                            == remoteId
                }
            )
        )
        return !pairings.isEmpty
    }

    /// Returns candidates the user might match the peer to
    private func matchCandidates(
        forTrainer senderIsTrainer: Bool
    ) -> [IdentityEntity] {
        if senderIsTrainer {
            // Sender is a trainer -- show our trainers
            if let trainer = identity.trainer(
                in: modelContext
            ) {
                return [trainer]
            }
            return []
        } else {
            // Sender is a trainee -- show our trainees
            return identity.trainees(
                in: modelContext
            )
        }
    }

    private var matchPickerMessage: String {
        if identity.isTrainer {
            "Which of your trainees"
                + " is this device?"
        } else {
            "Is this one of your trainers?"
        }
    }

    @ViewBuilder
    private var matchPickerButtons: some View {
        if identity.isTrainer {
            let trainees = identity.trainees(
                in: modelContext
            )
            ForEach(trainees) { trainee in
                Button(trainee.name) {
                    syncManager.sendPairingOffer(
                        linkedIdentityUUID:
                            trainee.id,
                        linkedIdentityName:
                            trainee.name
                    )
                }
            }
            Button("New trainee") {
                syncManager.sendPairingOffer(
                    linkedIdentityUUID: nil,
                    linkedIdentityName: nil
                )
            }
        } else {
            // Trainee initiating -- show known trainers
            if let trainer = identity.trainer(
                in: modelContext
            ) {
                Button(trainer.name) {
                    syncManager.sendPairingOffer(
                        linkedIdentityUUID:
                            trainer.id,
                        linkedIdentityName:
                            trainer.name
                    )
                }
            }
            Button("New trainer") {
                syncManager.sendPairingOffer(
                    linkedIdentityUUID: nil,
                    linkedIdentityName: nil
                )
            }
        }
        Button("Cancel", role: .cancel) { }
    }
}
