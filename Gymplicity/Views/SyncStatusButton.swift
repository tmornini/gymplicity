import SwiftUI

struct SyncStatusButton: View {
    @ObservedObject var syncManager: SyncSessionManager
    let identity: IdentityEntity
    @State private var showingSync = false

    var body: some View {
        Button { showingSync = true } label: {
            Image(systemName: iconName)
                .foregroundStyle(iconColor)
                .symbolEffect(.pulse, isActive: isPulsing)
                .rotationEffect(.degrees(isRotating ? 360 : 0))
                .animation(isRotating ? .linear(duration: 1.5).repeatForever(autoreverses: false) : .default, value: isRotating)
        }
        .sheet(isPresented: $showingSync) {
            SyncView(syncManager: syncManager, identity: identity)
        }
    }

    private var iconName: String {
        switch syncManager.connectionState {
        case .idle, .searching:
            "person.2.wave.2"
        case .connecting, .pairing:
            "person.2.wave.2"
        case .syncing:
            "arrow.triangle.2.circlepath"
        case .connected:
            "person.2.wave.2.fill"
        case .error:
            "exclamationmark.triangle"
        }
    }

    private var iconColor: Color {
        switch syncManager.connectionState {
        case .idle, .searching:
            .gray
        case .connecting, .pairing:
            .orange
        case .syncing:
            .blue
        case .connected:
            .green
        case .error:
            .red
        }
    }

    private var isPulsing: Bool {
        switch syncManager.connectionState {
        case .searching, .connecting, .pairing:
            true
        default:
            false
        }
    }

    private var isRotating: Bool {
        if case .syncing = syncManager.connectionState { return true }
        return false
    }
}
