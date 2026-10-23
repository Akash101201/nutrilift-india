import SwiftUI
import SwiftData

struct FoodDiaryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FoodDiaryEntry.createdAt, order: .reverse) private var entries: [FoodDiaryEntry]
    @Query(sort: \MealTemplate.name) private var templates: [MealTemplate]
    @State private var day = Date()
    @State private var showAdd = false
    @State private var showPhoto = false
    @State private var showCustom = false

    private var dayEntries: [FoodDiaryEntry] {
        entries.filter { Calendar.current.isDate($0.date, inSameDayAs: day) }
    }

    private var totals: MacroSnapshot {
        DiaryTotals.totals(for: entries, on: day)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    DatePicker("Day", selection: $day, displayedComponents: .date)
                    HStack {
                        Text("Today totals")
                        Spacer()
                        Text("\(Int(totals.calories)) kcal · P \(Int(totals.proteinGrams))")
                            .foregroundStyle(.secondary)
                    }
                }

                ForEach(MealType.allCases.sorted(by: { $0.sortOrder < $1.sortOrder })) { meal in
                    Section(meal.displayName) {
                        let mealEntries = dayEntries.filter { $0.mealType == meal }
                        if mealEntries.isEmpty {
                            Text("Nothing logged")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(mealEntries, id: \.id) { entry in
                                VStack(alignment: .leading) {
                                    Text(entry.displayName)
                                    Text("\(entry.quantity.formatted()) \(entry.servingUnit.displayName) · \(Int(entry.calories)) kcal")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .onDelete { indexSet in
                                for i in indexSet {
                                    modelContext.delete(mealEntries[i])
                                }
                            }
                        }
                    }
                }

                if !templates.isEmpty {
                    Section("Meal templates") {
                        ForEach(templates, id: \.id) { template in
                            Button {
                                applyTemplate(template)
                            } label: {
                                Label(template.name, systemImage: "square.stack")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Food")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Search foods") { showAdd = true }
                        Button("Estimate from photo") { showPhoto = true }
                        Button("Custom food") { showCustom = true }
                        Button("Copy yesterday") { copyYesterday() }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAdd) {
                FoodSearchView(day: day)
            }
            .sheet(isPresented: $showPhoto) {
                PhotoFoodFlowView(day: day)
            }
            .sheet(isPresented: $showCustom) {
                CustomFoodView()
            }
        }
    }

    private func applyTemplate(_ template: MealTemplate) {
        for item in template.items {
            let entry = FoodDiaryEntry(
                date: day,
                mealType: template.mealType,
                foodSeedId: item.foodSeedId,
                displayName: item.displayName,
                quantity: item.quantity,
                servingUnit: ServingUnit(rawValue: item.servingUnitRaw) ?? .katori,
                snapshot: MacroSnapshot(
                    calories: item.calories,
                    proteinGrams: item.proteinG,
                    carbGrams: item.carbG,
                    fatGrams: item.fatG
                )
            )
            modelContext.insert(entry)
        }
        try? modelContext.save()
    }

    private func copyYesterday() {
        guard let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: day) else { return }
        let yEntries = entries.filter { Calendar.current.isDate($0.date, inSameDayAs: yesterday) }
        for e in yEntries {
            modelContext.insert(FoodDiaryEntry(
                date: day,
                mealType: e.mealType,
                foodSeedId: e.foodSeedId,
                displayName: e.displayName,
                quantity: e.quantity,
                servingUnit: e.servingUnit,
                snapshot: e.snapshot,
                source: .manual
            ))
        }
        try? modelContext.save()
    }
}
