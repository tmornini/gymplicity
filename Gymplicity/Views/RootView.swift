import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var identities: [IdentityEntity]
    @State private var showingSetup = false
    @State private var setupName = ""

    private var currentIdentity: IdentityEntity? { identities.first }

    var body: some View {
        NavigationStack {
            Group {
                if let identity = currentIdentity {
                    if identity.isTrainer {
                        HomeView(identity: identity)
                    } else {
                        ProfileView(identity: identity)
                    }
                } else {
                    welcomeView
                }
            }
            .navigationTitle("Gymplicity")
            .alert(
            "Set Up Your Profile",
            isPresented: $showingSetup
        ) {
            TextField("Your Name", text: $setupName)
            Button("I'm a Trainer") {
                createIdentity(isTrainer: true)
            }
            .disabled(setupName
                .trimmingCharacters(
                    in: .whitespaces
                ).isEmpty)
            Button("I'm a Trainee") {
                createIdentity(isTrainer: false)
            }
            .disabled(setupName
                .trimmingCharacters(
                    in: .whitespaces
                ).isEmpty)
            Button("Cancel", role: .cancel) { }
        }
        }
    }

    // MARK: - Welcome View

    private var welcomeView: some View {
        VStack(spacing: GymMetrics.space24) {
            Spacer()
            AnimatedMascotView(
                pose: .waving,
                animation: .wave,
                color: GymColors.energy
            )
                .frame(height: GymMetrics.mascotLarge)
            Text("Welcome to Gymplicity")
                .font(GymFont.heading1)
            Text("Train smarter. Track everything.")
                .font(GymFont.body)
                .foregroundStyle(GymColors.secondaryText)
            Button("Get Started") { showingSetup = true }
                .buttonStyle(.gymPrimary)
                .padding(.horizontal, GymMetrics.actionPadding)
            Spacer()
        }
        .padding()
    }

    // MARK: - Actions

    private func createIdentity(
        isTrainer: Bool
    ) {
        let name = setupName
            .trimmingCharacters(in: .whitespaces)
        let identity = IdentityEntity(
            name: name,
            isTrainer: isTrainer
        )
        modelContext.insert(identity)
        SyncTrigger.structureChanged()
    }
}
