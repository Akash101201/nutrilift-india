import SwiftUI
import SwiftData
import UIKit

struct FoodDiaryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FoodDiaryEntry.createdAt, order: .reverse) private var entries: [FoodDiaryEntry]
    @Query(sort: \MealTemplate.name) private var templates: [MealTemplate]
    @Query(sort: \FoodItem.name) private var foods: [FoodItem]
    @Query private var profiles: [UserProfile]

    @State private var day = Date()
    @State private var showAdd = false
    @State private var addMeal: MealType = .lunch
    @State private var showPhoto = false
    @State private var photoPreference: PhotoFoodCapturePreference = .choose
    @State private var showCustom = false
    @State private var editingEntry: FoodDiaryEntry?
    @State private var quickLogFood: FoodItem?
    @State private var saveTemplateMeal: MealType?
    @State private var templateName = ""
    @State private var showTemplateNameAlert = false

    private var profile: UserProfile? { profiles.first }

    private var photoEstimateAvailable: Bool {
        PhotoNutritionEstimatorFactory.make().isAvailable
    }

    private var cameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    private var dayEntries: [FoodDiaryEntry] {
        entries.filter { Calendar.current.isDate($0.date, inSameDayAs: day) }
    }

    private var totals: MacroSnapshot {
        DiaryTotals.totals(for: entries, on: day)
    }

    private var remaining: MacroTargets {
        DiaryTotals.remaining(targets: profile?.targets ?? .empty, consumed: totals)
    }

    private var dayTitle: String {
        if Calendar.current.isDateInToday(day) { return "Today" }
        if Calendar.current.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.weekday(.wide).day().month())
    }

    private var loggedDates: [Date] { entries.map(\.date) }

    private var nextEmptyMeal: MealType? {
        MealType.allCases
            .sorted { $0.sortOrder < $1.sortOrder }
            .first { meal in dayEntries.filter { $0.mealType == meal }.isEmpty }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    summaryCard
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                if let nudge = proteinNudgeText {
                    Section {
                        HStack(alignment: .top, spacing: 10) {
                            Text("💪")
                                .font(.title2)
                                .accessibilityHidden(true)
                            Text(nudge)
                                .font(.rounded(.subheadline))
                                .foregroundStyle(.primary)
                        }
                        .padding(.vertical, 4)
                    } header: {
                        EmojiHeader(emoji: "🧭", title: "Coach nudge")
                    }
                    .listRowBackground(Theme.card)
                }

                if dayEntries.isEmpty, let quickMeal = nextEmptyMeal {
                    quickAddSection(for: quickMeal)
                }

                Section {
                    photoLogCard
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                } header: {
                    EmojiHeader(emoji: "📸", title: "Add with photo")
                }

                ForEach(MealType.allCases.sorted(by: { $0.sortOrder < $1.sortOrder })) { meal in
                    mealSection(meal)
                }

                if !templates.isEmpty {
                    Section {
                        ForEach(templates, id: \.id) { template in
                            Button {
                                applyTemplate(template)
                            } label: {
                                Label(template.name, systemImage: "square.stack")
                            }
                        }
                    } header: {
                        EmojiHeader(emoji: "📋", title: "Meal templates")
                    }
                    .listRowBackground(Theme.card)
                }
            }
            .scrollContentBackground(.hidden)
            .appBackground()
            .tint(Theme.saffron)
            .navigationTitle("Food")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            openSearch(meal: nextEmptyMeal ?? .lunch)
                        } label: {
                            Label("Search foods", systemImage: "magnifyingglass")
                        }
                        Button {
                            openPhotoFlow(preference: .choose, meal: nextEmptyMeal ?? .lunch)
                        } label: {
                            Label("Estimate from photo", systemImage: "photo")
                        }
                        if cameraAvailable {
                            Button {
                                openPhotoFlow(preference: .camera, meal: nextEmptyMeal ?? .lunch)
                            } label: {
                                Label("Take photo", systemImage: "camera")
                            }
                        }
                        Button {
                            openCustom(meal: nextEmptyMeal ?? .lunch)
                        } label: {
                            Label("Custom food", systemImage: "square.and.pencil")
                        }
                        Button { copyYesterday() } label: { Label("Copy yesterday", systemImage: "doc.on.doc") }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                    .accessibilityLabel("More ways to add food")
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button("Add food 🍛") { openSearch(meal: nextEmptyMeal ?? .lunch) }
                    .buttonStyle(.gradient)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.bar)
            }
            .sheet(isPresented: $showAdd) {
                FoodSearchView(day: day, initialMeal: addMeal)
            }
            .sheet(isPresented: $showPhoto) {
                PhotoFoodFlowView(day: day, preferredCapture: photoPreference, initialMeal: addMeal)
            }
            .sheet(isPresented: $showCustom) {
                CustomFoodView(day: day, initialMeal: addMeal)
            }
            .sheet(isPresented: Binding(
                get: { editingEntry != nil },
                set: { if !$0 { editingEntry = nil } }
            )) {
                if let entry = editingEntry {
                    FoodEntryEditView(entry: entry)
                }
            }
            .sheet(isPresented: Binding(
                get: { quickLogFood != nil },
                set: { if !$0 { quickLogFood = nil } }
            )) {
                if let food = quickLogFood {
                    FoodLogConfirmView(food: food, day: day, meal: addMeal) {
                        quickLogFood = nil
                    }
                }
            }
            .alert("Save as template", isPresented: $showTemplateNameAlert) {
                TextField("Template name", text: $templateName)
                Button("Save") { commitSaveTemplate() }
                Button("Cancel", role: .cancel) {
                    saveTemplateMeal = nil
                    templateName = ""
                }
            } message: {
                Text("Reuse this meal with one tap later.")
            }
        }
    }

    // MARK: Protein nudge

    private var proteinNudgeText: String? {
        guard let profile, Calendar.current.isDateInToday(day) else { return nil }
        let remainingProtein = remaining.proteinGrams
        guard remainingProtein >= 25 else { return nil }
        let dinnerEmpty = dayEntries.filter { $0.mealType == .dinner }.isEmpty
        let snacksEmpty = dayEntries.filter { $0.mealType == .snacks }.isEmpty
        guard dinnerEmpty || snacksEmpty else { return nil }
        let ideas = InsightsEngine.highProteinSuggestions(for: profile.dietPref)
        let slot = dinnerEmpty ? "dinner" : "a snack"
        return "Need ~\(Int(remainingProtein.rounded())) g protein — try \(ideas) for \(slot)."
    }

    // MARK: Quick add (usual meal)

    @ViewBuilder
    private func quickAddSection(for meal: MealType) -> some View {
        let mealTemplates = templates.filter { $0.mealType == meal }
        let usual = foods
            .filter { $0.lastUsedAt != nil }
            .sorted { ($0.lastUsedAt ?? .distantPast) > ($1.lastUsedAt ?? .distantPast) }
            .prefix(4)

        if !mealTemplates.isEmpty || !usual.isEmpty {
            Section {
                if !mealTemplates.isEmpty {
                    ForEach(mealTemplates, id: \.id) { template in
                        Button {
                            applyTemplate(template)
                        } label: {
                            Label("Usual: \(template.name)", systemImage: "arrow.triangle.2.circlepath")
                        }
                    }
                }
                ForEach(Array(usual), id: \.seedId) { food in
                    Button {
                        addMeal = meal
                        quickLogFood = food
                    } label: {
                        Label(food.name, systemImage: "clock.arrow.circlepath")
                    }
                }
                Button {
                    openSearch(meal: meal)
                } label: {
                    Label("Search for \(meal.displayName.lowercased())", systemImage: "magnifyingglass")
                }
            } header: {
                EmojiHeader(emoji: meal.emoji, title: "Usual \(meal.displayName.lowercased())")
            }
            .listRowBackground(Theme.card)
        }
    }

    // MARK: Photo / camera

    private var photoLogCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Text("📷")
                    .font(.system(size: 36))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Snap a meal")
                        .font(.rounded(.headline, weight: .bold))
                    Text(
                        photoEstimateAvailable
                            ? "Estimate calories on-device with Apple Intelligence. Photos stay on this iPhone."
                            : "Photo estimates need Apple Intelligence on a supported iPhone. You can still search and log foods."
                    )
                    .font(.rounded(.footnote))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 10) {
                if cameraAvailable {
                    Button {
                        openPhotoFlow(preference: .camera, meal: nextEmptyMeal ?? .lunch)
                    } label: {
                        Label("Camera", systemImage: "camera.fill")
                    }
                    .buttonStyle(.gradient)
                    .accessibilityHint(
                        photoEstimateAvailable
                            ? "Open camera to estimate food"
                            : "Opens photo flow; estimate needs Apple Intelligence"
                    )
                }

                Button {
                    openPhotoFlow(preference: .choose, meal: nextEmptyMeal ?? .lunch)
                } label: {
                    Label(cameraAvailable ? "Gallery" : "Choose photo", systemImage: "photo.on.rectangle")
                }
                .buttonStyle(.soft)
                .accessibilityHint(
                    photoEstimateAvailable
                        ? "Choose a photo to estimate food"
                        : "Opens photo flow; estimate needs Apple Intelligence"
                )
            }

            HStack(spacing: 6) {
                Image(systemName: "lock.shield.fill")
                    .foregroundStyle(Theme.leaf)
                Text(photoEstimateAvailable ? "Photo not uploaded · on-device only" : "Unavailable on this device")
                    .font(.rounded(.caption, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .appCard()
        .opacity(photoEstimateAvailable ? 1 : 0.85)
    }

    private func openPhotoFlow(preference: PhotoFoodCapturePreference, meal: MealType) {
        addMeal = meal
        photoPreference = preference
        showPhoto = true
    }

    private func openSearch(meal: MealType) {
        addMeal = meal
        showAdd = true
    }

    private func openCustom(meal: MealType) {
        addMeal = meal
        showCustom = true
    }

    // MARK: Summary

    private var summaryCard: some View {
        let targetCalories = max(profile?.calorieTarget ?? 0, 1)
        let proteinTarget = max(profile?.proteinTargetG ?? 0, 1)
        let carbTarget = max(profile?.carbTargetG ?? 0, 1)
        let fatTarget = max(profile?.fatTargetG ?? 0, 1)
        let streak = HabitStats.currentStreak(loggedDates: loggedDates)
        let loggedToday = HabitStats.loggedToday(loggedDates: loggedDates)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(dayTitle)
                    .font(.rounded(.title2, weight: .bold))
                Spacer()
                DatePicker("Day", selection: $day, displayedComponents: .date)
                    .labelsHidden()
            }

            if Calendar.current.isDateInToday(day) {
                HStack(spacing: 8) {
                    Text("🔥")
                        .opacity(streak > 0 ? 1 : 0.35)
                    Text(streak == 1 ? "1 day streak" : "\(streak) day streak")
                        .font(.rounded(.subheadline, weight: .semibold))
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text(Microcopy.streakLine(streak: streak, loggedToday: loggedToday))
                        .font(.rounded(.caption))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            MacroBar(emoji: "🔥", name: "Calories", value: totals.calories, target: targetCalories, unit: "kcal", color: Theme.saffron)
            MacroBar(emoji: "🥚", name: "Protein", value: totals.proteinGrams, target: proteinTarget, color: Theme.protein)
            MacroBar(emoji: "🍚", name: "Carbs", value: totals.carbGrams, target: carbTarget, color: Theme.carbs)
            MacroBar(emoji: "🥑", name: "Fat", value: totals.fatGrams, target: fatTarget, color: Theme.fat)

            if profile != nil {
                Text(remainingLine)
                    .font(.rounded(.caption))
                    .foregroundStyle(.secondary)
            }
        }
        .appCard()
    }

    private var remainingLine: String {
        let kcal = Int(remaining.calories.rounded())
        let protein = Int(remaining.proteinGrams.rounded())
        if remaining.calories >= 0 {
            return "Remaining · \(kcal) kcal · \(protein) g protein"
        }
        return "Over by \(abs(kcal)) kcal · protein \(protein >= 0 ? "\(protein) g left" : "\(abs(protein)) g over")"
    }

    // MARK: Meals

    @ViewBuilder
    private func mealSection(_ meal: MealType) -> some View {
        let mealEntries = dayEntries.filter { $0.mealType == meal }
        let kcal = mealEntries.reduce(0) { $0 + $1.calories }
        Section {
            if mealEntries.isEmpty {
                Button {
                    openSearch(meal: meal)
                } label: {
                    Text("Nothing here yet. Tap to add \(meal.displayName.lowercased()) 🍽️")
                        .font(.rounded(.subheadline))
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(mealEntries, id: \.id) { entry in
                    Button {
                        editingEntry = entry
                    } label: {
                        HStack(spacing: 12) {
                            Text(FoodEmoji.emoji(for: entry.displayName))
                                .font(.title2)
                                .frame(width: 40, height: 40)
                                .background(Theme.saffron.opacity(0.14), in: Circle())
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.displayName)
                                    .font(.rounded(.body, weight: .semibold))
                                    .foregroundStyle(.primary)
                                Text("\(entry.quantity.formatted()) \(entry.servingUnit.displayName) · \(Int(entry.calories)) kcal")
                                    .font(.rounded(.caption))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "pencil")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .onDelete { indexSet in
                    for i in indexSet {
                        modelContext.delete(mealEntries[i])
                    }
                    try? modelContext.save()
                }

                Button {
                    beginSaveTemplate(meal: meal)
                } label: {
                    Label("Save \(meal.displayName.lowercased()) as template", systemImage: "square.and.arrow.down")
                }
            }
        } header: {
            EmojiHeader(
                emoji: meal.emoji,
                title: meal.displayName,
                trailing: mealEntries.isEmpty ? nil : "\(Int(kcal.rounded())) kcal"
            )
        }
        .listRowBackground(Theme.card)
    }

    // MARK: Actions

    private func beginSaveTemplate(meal: MealType) {
        let mealEntries = dayEntries.filter { $0.mealType == meal }
        guard !mealEntries.isEmpty else { return }
        saveTemplateMeal = meal
        templateName = "My \(meal.displayName.lowercased())"
        showTemplateNameAlert = true
    }

    private func commitSaveTemplate() {
        guard let meal = saveTemplateMeal else { return }
        let mealEntries = dayEntries.filter { $0.mealType == meal }
        guard !mealEntries.isEmpty else { return }
        let name = templateName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let items = mealEntries.map { entry in
            MealTemplateItem(
                foodSeedId: entry.foodSeedId ?? "",
                displayName: entry.displayName,
                quantity: entry.quantity,
                servingUnit: entry.servingUnit,
                snapshot: entry.snapshot
            )
        }
        modelContext.insert(MealTemplate(name: name, mealType: meal, items: items))
        try? modelContext.save()
        Haptics.success()
        saveTemplateMeal = nil
        templateName = ""
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
        Haptics.success()
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
        Haptics.success()
    }
}
