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

    private var sortedPairs: [(
        identity: IdentityEntity,
        workout: WorkoutEntity
    )] {
        let traineeList = trainer.trainees(in: modelContext)
        let traineeIds = traineeList.map(\.id)
        let workoutsByID = BatchTraversal
            .workoutsByIdentity(
                identityIds: traineeIds,
                in: modelContext
            )
        let traineeMap = Dictionary(
            traineeList.map { ($0.id, $0) },
            uniquingKeysWith: { a, _ in a }
        )

        return workoutsByID.flatMap {
            (identityId, workouts)
                -> [(
                    identity: IdentityEntity,
                    workout: WorkoutEntity
                )]
            in
            guard let trainee =
                traineeMap[identityId]
            else { return [] }
            return workouts
                .filter {
                    !$0.isCompleted(
                        in: modelContext
                    ) && !$0.isTemplate
                }
                .map {
                    (
                        identity: trainee,
                        workout: $0
                    )
                }
        }
        .sorted {
            $0.workout.date < $1.workout.date
        }
    }

    var body: some View {
        let pairs = sortedPairs
        let currentPair: (
            identity: IdentityEntity,
            workout: WorkoutEntity
        )? = {
            guard currentIndex >= 0,
                currentIndex < pairs.count
            else { return nil }
            return pairs[currentIndex]
        }()

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
                                trainer: trainer,
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
                            HStack(spacing: GymMetrics.space4) {
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
                    VStack(spacing: GymMetrics.space2) {
                        Text(pair.identity.name)
                            .font(GymFont.heading3)
                        if pairs.count > 1 {
                            pageDots(count: pairs.count)
                        } else {
                            Text(pair.workout.date, style: .date)
                                .font(GymFont.caption)
                                .foregroundStyle(GymColors.secondaryText)
                        }
                    }
                }
            }
        }
        .onAppear {
            guard !hasInitialized else { return }
            hasInitialized = true
            if let index = pairs.firstIndex(
                where: {
                    $0.workout.id == initialWorkoutId
                }
            ) {
                currentIndex = index
            }
        }
        .onChange(of: pairs.map(\.workout.id)) { oldIds, newIds in
            guard oldIds != newIds else { return }
            if newIds.isEmpty {
                dismiss()
                return
            }
            let removedIds = Set(oldIds).subtracting(newIds)
            for id in removedIds {
                viewModes.removeValue(forKey: id)
                guidedSetIndices.removeValue(forKey: id)
            }
            if currentIndex >= newIds.count {
                currentIndex = max(0, newIds.count - 1)
            }
        }
    }

    // MARK: - Page Dots

    private func pageDots(count: Int) -> some View {
        HStack(spacing: GymMetrics.space6) {
            ForEach(0..<count, id: \.self) { index in
                if index == currentIndex {
                    Capsule()
                        .fill(GymColors.energy)
                        .frame(
                            width: GymMetrics
                                .activeDotWidth,
                            height: GymMetrics
                                .activeDotHeight
                        )
                } else {
                    Circle()
                        .fill(GymColors.steel)
                        .frame(
                            width: GymMetrics
                                .inactiveDotSize,
                            height: GymMetrics
                                .inactiveDotSize
                        )
                }
            }
        }
        .animation(
            .spring(
                response: GymMetrics.pageSpringResponse,
                dampingFraction: GymMetrics.pageSpringDamping
            ),
            value: currentIndex
        )
    }

    // MARK: - Edge Gestures

    private var edgeGestures: some View {
        HStack(spacing: 0) {
            Color.clear
                .frame(width: GymMetrics.edgeGestureWidth)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: GymMetrics.dragMinDistance)
                        .onEnded { value in
                            if value.translation.width
                                > GymMetrics.dragThreshold
                            {
                                goToPrevious(
                                    count: sortedPairs
                                        .count
                                )
                            }
                        }
                )

            Spacer()

            Color.clear
                .frame(width: GymMetrics.edgeGestureWidth)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: GymMetrics.dragMinDistance)
                        .onEnded { value in
                            if value.translation.width
                                < -GymMetrics.dragThreshold
                            {
                                goToNext(
                                    count: sortedPairs
                                        .count
                                )
                            }
                        }
                )
        }
        .allowsHitTesting(true)
    }

    // MARK: - Navigation

    private func goToPrevious(count: Int) {
        guard count > 1 else { return }
        withAnimation(.easeInOut(duration: GymMetrics.animationQuick)) {
            currentIndex = (currentIndex - 1 + count) % count
        }
    }

    private func goToNext(count: Int) {
        guard count > 1 else { return }
        withAnimation(.easeInOut(duration: GymMetrics.animationQuick)) {
            currentIndex = (currentIndex + 1) % count
        }
    }
}
