import SwiftUI

struct SessionHistoryView: View {
    let session: Session

    var body: some View {
        List {
            Section {
                LabeledContent("Date") {
                    Text(session.date, style: .date)
                }
                LabeledContent("Exercises") {
                    Text("\(session.exerciseCount)")
                }
                let totalSets = session.entries.flatMap(\.sets).count
                LabeledContent("Sets") {
                    Text("\(totalSets)")
                }
                if session.totalVolume > 0 {
                    LabeledContent("Total Volume") {
                        Text("\(Int(session.totalVolume)) lb")
                    }
                }
                if let notes = session.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notes")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(notes)
                    }
                }
            }

            ForEach(session.sortedEntries) { entry in
                Section(entry.exerciseName) {
                    ForEach(entry.sortedSets) { exerciseSet in
                        HStack {
                            Text("Set \(setNumber(exerciseSet, in: entry))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(width: 50, alignment: .leading)
                            Text(formatWeight(exerciseSet.weight))
                                .font(.body.monospacedDigit())
                            Text("x")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(exerciseSet.reps)")
                                .font(.body.monospacedDigit())
                            Spacer()
                            Text("\(Int(exerciseSet.volume)) lb vol")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack {
                        Spacer()
                        Text("Volume: \(Int(entry.totalVolume)) lb")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Session Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func setNumber(_ exerciseSet: ExerciseSet, in entry: SessionEntry) -> Int {
        (entry.sortedSets.firstIndex(where: { $0.id == exerciseSet.id }) ?? 0) + 1
    }

    private func formatWeight(_ weight: Double) -> String {
        if weight == weight.rounded() {
            return "\(Int(weight)) lb"
        }
        return String(format: "%.1f lb", weight)
    }
}
