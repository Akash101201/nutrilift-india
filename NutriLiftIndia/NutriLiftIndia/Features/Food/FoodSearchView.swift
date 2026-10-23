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
                Picker("Meal", selection: $meal) {
                    ForEach(MealType.allCases) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets())
                .padding(.vertical, 8)

                if query.isEmpty && !favorites.isEmpty {
                    Section("Favorites") {
                        ForEach(favorites, id: \.seedId) { foodRow($0) }
                    }
                }
                if query.isEmpty && !recents.isEmpty {
                    Section("Recent") {
                        ForEach(recents, id: \.seedId) { foodRow($0) }
                    }
                }
                Section(query.isEmpty ? "All foods" : "Results") {
                    ForEach(filtered, id: \.seedId) { foodRow($0) }
                }
            }
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
            selected = food
        } label: {
            HStack {
                VStack(alignment: .leading) {
                    Text(food.name)
                    Text("\(Int(food.calories)) kcal / \(food.servingAmount.formatted()) \(food.servingUnit.displayName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    food.isFavorite.toggle()
                } label: {
                    Image(systemName: food.isFavorite ? "star.fill" : "star")
                }
                .buttonStyle(.borderless)
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

    var body: some View {
        NavigationStack {
            Form {
                Section(food.name) {
                    Stepper(value: $quantity, in: 0.25...20, step: 0.25) {
                        Text("Quantity: \(quantity.formatted()) \(food.servingUnit.displayName)")
                    }
                    let snap = food.perServingSnapshot.scaled(by: quantity)
                    Text("\(Int(snap.calories)) kcal · P \(Int(snap.proteinGrams)) · C \(Int(snap.carbGrams)) · F \(Int(snap.fatGrams))")
                        .foregroundStyle(.secondary)
                }
                Section {
                    Button("Add to diary") {
                        let snap = food.perServingSnapshot.scaled(by: quantity)
                        modelContext.insert(FoodDiaryEntry(
                            date: day,
                            mealType: meal,
                            foodSeedId: food.seedId,
                            displayName: food.name,
                            quantity: quantity,
                            servingUnit: food.servingUnit,
                            snapshot: snap
                        ))
                        food.lastUsedAt = Date()
                        try? modelContext.save()
                        onLogged()
                        dismiss()
                    }
                }
            }
            .navigationTitle("Log")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
