import SwiftUI
import SwiftData

struct ActiveWorkoutsContainerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let trainer: IdentityEntity
    let initialWorkoutId: UUID
    @State private var currentIndex: Int = 0
    @State private var viewModes: [UUID: ViewMode] = [:]
    @State private var guidedSetIndices: [UUID: Int] = [:]
    @State private var hasInitialized = false

    enum ViewMode { case list, guided }

    private var sortedPairs: [(identity: IdentityEntity, workout: WorkoutEntity)] {
        trainer.trainees(in: modelContext)
            .flatMap { trainee in
                trainee.activeWorkouts(in: modelContext).map { (identity: trainee, workout: $0) }
            }
            .sorted { $0.workout.date < $1.workout.date }
    }

    private var currentPair: (identity: IdentityEntity, workout: WorkoutEntity)? {
        let pairs = sortedPairs
        guard currentIndex >= 0, currentIndex < pairs.count else { return nil }
        return pairs[currentIndex]
    }

    var body: some View {
        let pairs = sortedPairs
        Group {
            if let pair = currentPair {
                let workoutId = pair.workout.id
                let mode = viewModes[workoutId, default: .list]
                ZStack {
                    Group {
                        switch mode {
                        case .list:
                            ActiveWorkoutView(
                                workout: pair.workout,
                                onSwitchToGuided: {
                                    viewModes[workoutId] = .guided
                                }
                            )
                        case .guided:
                            GuidedWorkoutView(
                                workout: pair.workout,
                                onSwitchToList: {
                                    viewModes[workoutId] = .list
                                },
                                initialSetIndex: guidedSetIndices[workoutId],
                                onSetIndexChange: { newIndex in
                                    guidedSetIndices[workoutId] = newIndex
                                }
                            )
                        }
                    }
                    .id(workoutId)

                    if pairs.count > 1 {
                        edgeGestures
                    }
                }
            } else {
                Color.clear
                    .onAppear { dismiss() }
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let pair = currentPair {
                let mode = viewModes[pair.workout.id, default: .list]
                if mode == .list {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            dismiss()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                    .fontWeight(.semibold)
                                Text("Back")
                            }
                        }
                    }
                }
            }
            ToolbarItem(placement: .principal) {
                if let pair = currentPair {
                    VStack(spacing: 2) {
                        Text(pair.identity.name)
                            .font(.headline)
                        if pairs.count > 1 {
                            pageDots(count: pairs.count)
                        } else {
                            Text(pair.workout.date, style: .date)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .onAppear {
            guard !hasInitialized else { return }
            hasInitialized = true
            let pairs = sortedPairs
            if let index = pairs.firstIndex(where: { $0.workout.id == initialWorkoutId }) {
                currentIndex = index
            }
        }
        .onChange(of: sortedPairs.map(\.workout.id)) { oldIds, newIds in
            guard oldIds != newIds else { return }
            if newIds.isEmpty {
                dismiss()
                return
            }
            // Clean up state for removed workouts
            let removedIds = Set(oldIds).subtracting(newIds)
            for id in removedIds {
                viewModes.removeValue(forKey: id)
                guidedSetIndices.removeValue(forKey: id)
            }
            // Clamp index
            if currentIndex >= newIds.count {
                currentIndex = max(0, newIds.count - 1)
            }
        }
    }

    // MARK: - Page Dots

    private func pageDots(count: Int) -> some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                Circle()
                    .fill(index == currentIndex ? Color.primary : Color.secondary.opacity(0.4))
                    .frame(width: 6, height: 6)
            }
        }
    }

    // MARK: - Edge Gestures

    private var edgeGestures: some View {
        HStack(spacing: 0) {
            // Left edge — swipe right to go to previous
            Color.clear
                .frame(width: 24)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 30)
                        .onEnded { value in
                            if value.translation.width > 50 {
                                goToPrevious()
                            }
                        }
                )

            Spacer()

            // Right edge — swipe left to go to next
            Color.clear
                .frame(width: 24)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 30)
                        .onEnded { value in
                            if value.translation.width < -50 {
                                goToNext()
                            }
                        }
                )
        }
        .allowsHitTesting(true)
    }

    // MARK: - Navigation

    private func goToPrevious() {
        let count = sortedPairs.count
        guard count > 1 else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            currentIndex = (currentIndex - 1 + count) % count
        }
    }

    private func goToNext() {
        let count = sortedPairs.count
        guard count > 1 else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            currentIndex = (currentIndex + 1) % count
        }
    }
}
