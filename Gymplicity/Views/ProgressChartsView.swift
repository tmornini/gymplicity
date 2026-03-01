import SwiftUI
import SwiftData
import Charts

struct ProgressChartsView: View {
    @Environment(\.modelContext) private var modelContext
    let identity: IdentityEntity
    let exercise: ExerciseEntity

    private var history: [(date: Date, set: SetEntity)] {
        identity.history(for: exercise, in: modelContext)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                if history.isEmpty {
                    ContentUnavailableView(
                        "No History Yet",
                        systemImage: "chart.xyaxis.line",
                        description: Text("Complete a workout with \(exercise.name) to see progress.")
                    )
                } else {
                    weightPerRepChart
                    totalVolumeChart
                }
            }
            .padding()
        }
        .navigationTitle(exercise.name)
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

    private var weightPerRepData: [WeightPerRepPoint] {
        // Group sets by date, then by reps, take max weight
        let byDate = Dictionary(grouping: history.filter { $0.set.reps > 0 && $0.set.weight > 0 }, by: { $0.date })
        return byDate.flatMap { (date, items) in
            let byReps = Dictionary(grouping: items, by: { $0.set.reps })
            return byReps.compactMap { (reps, sets) -> WeightPerRepPoint? in
                guard let maxWeight = sets.map(\.set.weight).max() else { return nil }
                return WeightPerRepPoint(date: date, reps: reps, weight: maxWeight)
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
        let byDate = Dictionary(grouping: history, by: { $0.date })
        return byDate.map { (date, items) in
            VolumePoint(date: date, volume: items.reduce(0) { $0 + $1.set.volume })
        }
        .sorted { $0.date < $1.date }
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
