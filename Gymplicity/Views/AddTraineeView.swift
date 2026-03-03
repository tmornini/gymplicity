import SwiftUI
import SwiftData

struct AddTraineeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let trainer: IdentityEntity
    @State private var name = ""
    @FocusState private var nameFieldFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: GymMetrics.space24) {
                AnimatedMascotView(pose: .spotting, animation: .bounce, color: GymColors.energy)
                    .frame(height: 80)
                Text("Who's training today?")
                    .font(GymFont.heading2)
                    .foregroundStyle(GymColors.secondaryText)

                TextField("Name", text: $name)
                    .focused($nameFieldFocused)
                    .font(GymFont.heading3)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, GymMetrics.space24)
                    .submitLabel(.done)
                    .onSubmit { save() }

                Spacer()
            }
            .padding(.top, GymMetrics.space32)
            .navigationTitle("New Trainee")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { save() }
                        .fontWeight(.semibold)
                        .foregroundStyle(GymColors.energy)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { nameFieldFocused = true }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let trainee = IdentityEntity(name: trimmed, isTrainer: false)
        modelContext.insert(trainee)
        let join = TrainerTrainees(trainerId: trainer.id, traineeId: trainee.id)
        modelContext.insert(join)
        dismiss()
    }
}
