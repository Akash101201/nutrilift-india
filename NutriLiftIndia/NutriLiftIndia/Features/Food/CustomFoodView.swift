import SwiftUI
import SwiftData

struct CustomFoodView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var unit: ServingUnit = .katori
    @State private var amount = 1.0
    @State private var calories = 150.0
    @State private var protein = 5.0
    @State private var carbs = 20.0
    @State private var fat = 5.0

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(spacing: 6) {
                        Text(canSave ? FoodEmoji.emoji(for: name) : "🍽️")
                            .font(.system(size: 56))
                            .accessibilityHidden(true)
                        TextField("What did you eat?", text: $name)
                            .font(.rounded(.title2, weight: .bold))
                            .multilineTextAlignment(.center)
                            .textInputAutocapitalization(.words)
                    }
                    .frame(maxWidth: .infinity)
                    .appCard()

                    Text("📏 Serving")
                        .font(.rounded(.headline, weight: .bold))
                    EmojiSegmented(
                        options: ServingUnit.allCases.map { EmojiOption(value: $0, emoji: $0.emoji, title: $0.displayName) },
                        selection: $unit
                    )
                    VStack(spacing: 12) {
                        LabeledNumberField("Serving amount", value: $amount, unit: unit.displayName, emoji: unit.emoji)
                    }
                    .appCard()

                    Text("🔥 Nutrition per serving")
                        .font(.rounded(.headline, weight: .bold))
                    VStack(spacing: 12) {
                        LabeledNumberField("Calories", value: $calories, unit: "kcal", emoji: "🔥")
                        LabeledNumberField("Protein", value: $protein, unit: "g", emoji: "🥚")
                        LabeledNumberField("Carbs", value: $carbs, unit: "g", emoji: "🍚")
                        LabeledNumberField("Fat", value: $fat, unit: "g", emoji: "🥑")
                    }
                    .appCard()
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .appBackground()
            .navigationTitle("Custom food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button("Save food 🍽️") { save() }
                    .buttonStyle(.gradient)
                    .disabled(!canSave)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.bar)
            }
        }
    }

    private func save() {
        let item = FoodItem(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            servingUnit: unit,
            servingAmount: amount,
            gramsPerServing: amount,
            calories: calories,
            proteinG: protein,
            carbG: carbs,
            fatG: fat,
            sourceTag: "custom",
            confidence: "user",
            isCustom: true
        )
        modelContext.insert(item)
        try? modelContext.save()
        Haptics.success()
        dismiss()
    }
}
