import SwiftUI
import Charts

struct ProgressChartsView: View {
    let trainee: Trainee
    let exerciseDefinition: ExerciseDefinition

    private var history: [(date: Date, exercise: Exercise)] {
        trainee.history(for: exerciseDefinition)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                if history.isEmpty {
                    ContentUnavailableView(
                        "No History Yet",
                        systemImage: "chart.xyaxis.line",
                        description: Text("Complete a workout with \(exerciseDefinition.name) to see progress.")
                    )
                } else {
                    weightPerRepChart
                    totalVolumeChart
                }
            }
            .padding()
        }
        .navigationTitle(exerciseDefinition.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Chart A: Weight @ Reps Over Time

    @ViewBuilder
    private var weightPerRepChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Weight @ Reps Over Time")
                .font(.headline)
            Text("Best weight for each rep count per workout")
                .font(.caption)
                .foregroundStyle(.secondary)

            let dataPoints = weightPerRepData
            let repCounts = Swift.Set(dataPoints.map(\.reps)).sorted()

            Chart(dataPoints) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Weight", point.weight)
                )
                .foregroundStyle(by: .value("Reps", "\(point.reps)-rep"))
                .symbol(by: .value("Reps", "\(point.reps)-rep"))

                PointMark(
                    x: .value("Date", point.date),
                    y: .value("Weight", point.weight)
                )
                .foregroundStyle(by: .value("Reps", "\(point.reps)-rep"))
                .symbol(by: .value("Reps", "\(point.reps)-rep"))
            }
            .chartYAxisLabel("lb")
            .chartLegend(position: .bottom, alignment: .leading)
            .frame(height: 240)

            if repCounts.isEmpty {
                Text("No data")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    /// For each workout, find the max weight used at each distinct rep count.
    private var weightPerRepData: [WeightPerRepPoint] {
        history.flatMap { item in
            let setsByRep = Dictionary(grouping: item.exercise.sortedSets.filter { $0.reps > 0 && $0.weight > 0 }, by: \.reps)
            return setsByRep.compactMap { (reps, sets) -> WeightPerRepPoint? in
                guard let maxWeight = sets.map(\.weight).max() else { return nil }
                return WeightPerRepPoint(date: item.date, reps: reps, weight: maxWeight)
            }
        }
    }

    // MARK: - Chart B: Total Volume Over Time

    @ViewBuilder
    private var totalVolumeChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Total Volume Over Time")
                .font(.headline)
            Text("Sum of weight x reps across all sets per workout")
                .font(.caption)
                .foregroundStyle(.secondary)

            let dataPoints = volumeData

            Chart(dataPoints) { point in
                AreaMark(
                    x: .value("Date", point.date),
                    y: .value("Volume", point.volume)
                )
                .foregroundStyle(.blue.opacity(0.15))

                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Volume", point.volume)
                )
                .foregroundStyle(.blue)

                PointMark(
                    x: .value("Date", point.date),
                    y: .value("Volume", point.volume)
                )
                .foregroundStyle(.blue)
            }
            .chartYAxisLabel("lb")
            .frame(height: 240)
        }
    }

    private var volumeData: [VolumePoint] {
        history.map { item in
            VolumePoint(date: item.date, volume: item.exercise.totalVolume)
        }
    }
}

// MARK: - Chart Data Types

private struct WeightPerRepPoint: Identifiable {
    let id = UUID()
    let date: Date
    let reps: Int
    let weight: Double
}

private struct VolumePoint: Identifiable {
    let id = UUID()
    let date: Date
    let volume: Double
}
