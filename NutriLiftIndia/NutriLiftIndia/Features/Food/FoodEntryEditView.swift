import SwiftUI
import SwiftData

/// Edit an existing diary row (meal, quantity, macros).
struct FoodEntryEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let entry: FoodDiaryEntry

    @State private var meal: MealType
    @State private var quantity: Double
    @State private var calories: Double
    @State private var protein: Double
    @State private var carbs: Double
    @State private var fat: Double
    @State private var fatAddOn: LogPortionAdjustments.FatAddOn = .none
    @State private var portionStyle: LogPortionAdjustments.PortionStyle = .homemade

    private var basePerUnit: MacroSnapshot {
        guard quantity > 0 else {
            return MacroSnapshot(calories: calories, proteinGrams: protein, carbGrams: carbs, fatGrams: fat)
        }
        return MacroSnapshot(
            calories: calories / quantity,
            proteinGrams: protein / quantity,
            carbGrams: carbs / quantity,
            fatGrams: fat / quantity
        )
    }

    private var previewSnapshot: MacroSnapshot {
        LogPortionAdjustments.apply(
            base: basePerUnit.scaled(by: quantity),
            fatAddOn: fatAddOn,
            portionStyle: portionStyle
        )
    }

    init(entry: FoodDiaryEntry) {
        self.entry = entry
        _meal = State(initialValue: entry.mealType)
        _quantity = State(initialValue: entry.quantity)
        _calories = State(initialValue: entry.calories)
        _protein = State(initialValue: entry.proteinG)
        _carbs = State(initialValue: entry.carbG)
        _fat = State(initialValue: entry.fatG)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    VStack(spacing: 6) {
                        Text(FoodEmoji.emoji(for: entry.displayName))
                            .font(.system(size: 56))
                            .accessibilityHidden(true)
                        Text(entry.displayName)
                            .font(.rounded(.title2, weight: .bold))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .appCard()

                    Text("🍽️ Meal")
                        .font(.rounded(.headline, weight: .bold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    EmojiSegmented(
                        options: MealType.allCases.map { EmojiOption(value: $0, emoji: $0.emoji, title: $0.displayName) },
                        selection: $meal
                    )

                    Text("🔢 Quantity")
                        .font(.rounded(.headline, weight: .bold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    BigStepper(
                        value: $quantity,
                        range: 0.25...20,
                        step: 0.25,
                        unit: entry.servingUnit.displayName,
                        fractionDigits: 2
                    )
                    .appCard()
                    .onChange(of: quantity) { old, new in
                        guard old > 0, new > 0 else { return }
                        let factor = new / old
                        calories *= factor
                        protein *= factor
                        carbs *= factor
                        fat *= factor
                    }

                    portionAdjusters

                    Text("🔥 Nutrition")
                        .font(.rounded(.headline, weight: .bold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    VStack(spacing: 12) {
                        LabeledNumberField("Calories", value: $calories, unit: "kcal", emoji: "🔥")
                        LabeledNumberField("Protein", value: $protein, unit: "g", emoji: "🥚")
                        LabeledNumberField("Carbs", value: $carbs, unit: "g", emoji: "🍚")
                        LabeledNumberField("Fat", value: $fat, unit: "g", emoji: "🥑")
                    }
                    .appCard()

                    if fatAddOn != .none || portionStyle != .homemade {
                        Text("Preview with tweaks: \(Int(previewSnapshot.calories.rounded())) kcal")
                            .font(.rounded(.footnote))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .appBackground()
            .navigationTitle("Edit entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button("Save changes") { save() }
                    .buttonStyle(.gradient)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.bar)
            }
        }
    }

    private var portionAdjusters: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("🧈 Cooking fat")
                .font(.rounded(.headline, weight: .bold))
            EmojiSegmented(
                options: LogPortionAdjustments.FatAddOn.allCases.map {
                    EmojiOption(value: $0, emoji: $0.emoji, title: $0.label)
                },
                selection: $fatAddOn
            )
            Text("🏠 Portion style")
                .font(.rounded(.headline, weight: .bold))
            EmojiSegmented(
                options: LogPortionAdjustments.PortionStyle.allCases.map {
                    EmojiOption(value: $0, emoji: $0.emoji, title: $0.label)
                },
                selection: $portionStyle
            )
        }
    }

    private func save() {
        let snap: MacroSnapshot
        if fatAddOn != .none || portionStyle != .homemade {
            snap = previewSnapshot
        } else {
            snap = MacroSnapshot(calories: calories, proteinGrams: protein, carbGrams: carbs, fatGrams: fat)
        }
        entry.mealType = meal
        entry.quantity = quantity
        entry.snapshot = snap
        try? modelContext.save()
        Haptics.success()
        dismiss()
    }
}
