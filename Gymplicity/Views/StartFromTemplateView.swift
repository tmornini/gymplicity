import SwiftUI
import SwiftData

struct StartFromTemplateView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let trainer: IdentityEntity
    let trainee: IdentityEntity
    var onStart: (WorkoutEntity) -> Void = { _ in }

    var body: some View {
        NavigationStack {
            let templates = trainer.templates(in: modelContext)
            VStack(spacing: 0) {
                AnimatedMascotView(pose: .lifting, animation: .bounce, color: GymColors.energy)
                    .frame(height: GymMetrics.mascotSmall)
                    .padding(.top, GymMetrics.space16)

                List {
                    ForEach(templates) { template in
                        Button {
                            guard trainee.activeWorkouts(in: modelContext).isEmpty else { return }
                            let workout = modelContext.instantiateTemplate(template, for: trainee)
                            SyncTrigger.structureChanged()
                            onStart(workout)
                            dismiss()
                        } label: {
                            StartTemplateRow(template: template)
                        }
                    }

                    if templates.isEmpty {
                        Section {
                            VStack(spacing: GymMetrics.space16) {
                                MascotView(pose: .thinking, color: GymColors.secondaryText)
                                    .frame(height: GymMetrics.mascotSmall)
                                Text("Create templates from the Templates screen first")
                                    .font(GymFont.body)
                                    .foregroundStyle(GymColors.secondaryText)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, GymMetrics.space16)
                        }
                    }
                }
            }
            .navigationTitle("Start from Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

private struct StartTemplateRow: View {
    @Environment(\.modelContext) private var modelContext
    let template: WorkoutEntity

    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(GymColors.focus)
                .frame(width: GymMetrics.setBarWidth)
                .padding(.trailing, GymMetrics.space8)

            VStack(alignment: .leading, spacing: 4) {
                Text(template.templateName ?? "Untitled")
                    .font(GymFont.heading3)
                    .foregroundStyle(.primary)

                let groups = template.groups(in: modelContext)
                let setCount = groups.flatMap { $0.sets(in: modelContext) }.count
                let exerciseCount = template.exerciseCount(in: modelContext)

                HStack(spacing: 8) {
                    Text("\(exerciseCount) exercise\(exerciseCount == 1 ? "" : "s")")
                    Text("\(setCount) set\(setCount == 1 ? "" : "s")")
                }
                .font(GymFont.caption)
                .foregroundStyle(GymColors.secondaryText)
            }
        }
        .padding(.vertical, 2)
    }
}
