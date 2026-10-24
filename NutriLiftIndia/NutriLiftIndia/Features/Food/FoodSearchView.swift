import SwiftUI
import SwiftData

struct FoodSearchView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \FoodItem.name) private var foods: [FoodItem]

    var day: Date
    @State private var query = ""
    @State private var meal: MealType = .lunch
    @State private var selected: FoodItem?
    @State private var quantity = 1.0

    private var filtered: [FoodItem] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let base: [FoodItem]
        if q.isEmpty {
            base = foods
                .sorted { ($0.lastUsedAt ?? .distantPast) > ($1.lastUsedAt ?? .distantPast) }
        } else {
            base = foods.filter { $0.searchBlob.contains(q) }
        }
        return Array(base.prefix(80))
    }

    private var favorites: [FoodItem] {
        foods.filter(\.isFavorite).prefix(12).map { $0 }
    }

    private var recents: [FoodItem] {
        foods.filter { $0.lastUsedAt != nil && !$0.isFavorite }
            .sorted { ($0.lastUsedAt ?? .distantPast) > ($1.lastUsedAt ?? .distantPast) }
            .prefix(12)
            .map { $0 }
    }

    var body: some View {
        NavigationStack {
            List {
                EmojiSegmented(
                    options: MealType.allCases.map { EmojiOption(value: $0, emoji: $0.emoji, title: $0.displayName) },
                    selection: $meal
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                if query.isEmpty && !favorites.isEmpty {
                    Section {
                        ForEach(favorites, id: \.seedId) { foodRow($0) }
                    } header: {
                        EmojiHeader(emoji: "⭐️", title: "Favorites")
                    }
                    .listRowBackground(Theme.card)
                }
                if query.isEmpty && !recents.isEmpty {
                    Section {
                        ForEach(recents, id: \.seedId) { foodRow($0) }
                    } header: {
                        EmojiHeader(emoji: "🕒", title: "Recent")
                    }
                    .listRowBackground(Theme.card)
                }
                Section {
                    ForEach(filtered, id: \.seedId) { foodRow($0) }
                } header: {
                    EmojiHeader(emoji: query.isEmpty ? "🍛" : "🔎", title: query.isEmpty ? "All foods" : "Results")
                }
                .listRowBackground(Theme.card)

                if !query.isEmpty && filtered.isEmpty {
                    FriendlyEmptyState(
                        emoji: "🤔",
                        title: "No match for “\(query)”",
                        message: "Try another spelling, or add it yourself as a custom food."
                    )
                    .listRowBackground(Color.clear)
                }
            }
            .scrollContentBackground(.hidden)
            .appBackground()
            .tint(Theme.saffron)
            .searchable(text: $query, prompt: "Search roti, dal, paneer…")
            .navigationTitle("Add food")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(isPresented: Binding(
                get: { selected != nil },
                set: { if !$0 { selected = nil } }
            )) {
                if let food = selected {
                    FoodLogConfirmView(food: food, day: day, meal: meal) {
                        dismiss()
                    }
                }
            }
        }
    }

    private func foodRow(_ food: FoodItem) -> some View {
        Button {
            Haptics.tap()
            selected = food
        } label: {
            HStack(spacing: 12) {
                Text(FoodEmoji.emoji(for: food.name))
                    .font(.title2)
                    .frame(width: 40, height: 40)
                    .background(Theme.saffron.opacity(0.14), in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(food.name)
                        .font(.rounded(.body, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text("\(Int(food.calories)) kcal / \(food.servingAmount.formatted()) \(food.servingUnit.displayName)")
                        .font(.rounded(.caption))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    Haptics.selection()
                    food.isFavorite.toggle()
                } label: {
                    Image(systemName: food.isFavorite ? "star.fill" : "star")
                        .foregroundStyle(food.isFavorite ? Theme.saffron : Color.secondary)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(food.isFavorite ? "Remove from favorites" : "Add to favorites")
            }
        }
    }
}

struct FoodLogConfirmView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let food: FoodItem
    let day: Date
    let meal: MealType
    var onLogged: () -> Void

    @State private var quantity = 1.0
    @State private var logged = false
    @State private var celebrateCount = 0

    private var snapshot: MacroSnapshot { food.perServingSnapshot.scaled(by: quantity) }

    private static let quickQuantities: [(label: String, value: Double)] = [
        ("¼", 0.25), ("½", 0.5), ("1", 1), ("2", 2), ("3", 3),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    VStack(spacing: 6) {
                        Text(FoodEmoji.emoji(for: food.name))
                            .font(.system(size: 64))
                            .accessibilityHidden(true)
                        Text(food.name)
                            .font(.rounded(.title2, weight: .bold))
                            .multilineTextAlignment(.center)
                        Text("\(meal.emoji) \(meal.displayName)")
                            .font(.rounded(.subheadline))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 14) {
                        EmojiSegmented(
                            options: Self.quickQuantities.map { EmojiOption(value: $0.value, emoji: "", title: $0.label) },
                            selection: $quantity
                        )
                        BigStepper(
                            value: $quantity,
                            range: 0.25...20,
                            step: 0.25,
                            unit: food.servingUnit.displayName,
                            fractionDigits: 2
                        )
                    }
                    .appCard()

                    VStack(spacing: 14) {
                        Text("\(Int(snapshot.calories.rounded())) kcal")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .contentTransition(.numericText())
                        HStack(spacing: 10) {
                            macroTile("🥚", snapshot.proteinGrams, "Protein", Theme.protein)
                            macroTile("🍚", snapshot.carbGrams, "Carbs", Theme.carbs)
                            macroTile("🥑", snapshot.fatGrams, "Fat", Theme.fat)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .appCard()
                }
                .padding(20)
            }
            .appBackground()
            .navigationTitle("Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button(logged ? "Logged! 🎉" : "Add to diary") { log() }
                    .buttonStyle(.gradient)
                    .disabled(logged)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.bar)
            }
            .celebrate(trigger: celebrateCount)
        }
    }

    private func macroTile(_ emoji: String, _ grams: Double, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(emoji) \(Int(grams.rounded())) g")
                .font(.rounded(.headline, weight: .bold))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.rounded(.caption))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue("\(Int(grams.rounded())) grams")
    }

    private func log() {
        guard !logged else { return }
        logged = true
        modelContext.insert(FoodDiaryEntry(
            date: day,
            mealType: meal,
            foodSeedId: food.seedId,
            displayName: food.name,
            quantity: quantity,
            servingUnit: food.servingUnit,
            snapshot: snapshot
        ))
        food.lastUsedAt = Date()
        try? modelContext.save()
        celebrateCount += 1
        // Let the confetti play briefly before the sheets close.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            onLogged()
            dismiss()
        }
    }
}
