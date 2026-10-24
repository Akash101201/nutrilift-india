import SwiftUI
import SwiftData
import UIKit

struct FoodDiaryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FoodDiaryEntry.createdAt, order: .reverse) private var entries: [FoodDiaryEntry]
    @Query(sort: \MealTemplate.name) private var templates: [MealTemplate]
    @Query private var profiles: [UserProfile]
    @State private var day = Date()
    @State private var showAdd = false
    @State private var showPhoto = false
    @State private var photoPreference: PhotoFoodCapturePreference = .choose
    @State private var showCustom = false

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

    private var dayTitle: String {
        if Calendar.current.isDateInToday(day) { return "Today" }
        if Calendar.current.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.weekday(.wide).day().month())
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    summaryCard
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
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
                        Button { showAdd = true } label: { Label("Search foods", systemImage: "magnifyingglass") }
                        Button {
                            openPhotoFlow(preference: .choose)
                        } label: {
                            Label("Estimate from photo", systemImage: "photo")
                        }
                        if cameraAvailable {
                            Button {
                                openPhotoFlow(preference: .camera)
                            } label: {
                                Label("Take photo", systemImage: "camera")
                            }
                        }
                        Button { showCustom = true } label: { Label("Custom food", systemImage: "square.and.pencil") }
                        Button { copyYesterday() } label: { Label("Copy yesterday", systemImage: "doc.on.doc") }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                    .accessibilityLabel("More ways to add food")
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button("Add food 🍛") { showAdd = true }
                    .buttonStyle(.gradient)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.bar)
            }
            .sheet(isPresented: $showAdd) {
                FoodSearchView(day: day)
            }
            .sheet(isPresented: $showPhoto) {
                PhotoFoodFlowView(day: day, preferredCapture: photoPreference)
            }
            .sheet(isPresented: $showCustom) {
                CustomFoodView()
            }
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
                        openPhotoFlow(preference: .camera)
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
                    openPhotoFlow(preference: .choose)
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

    private func openPhotoFlow(preference: PhotoFoodCapturePreference) {
        photoPreference = preference
        showPhoto = true
    }

    // MARK: Summary

    private var summaryCard: some View {
        let target = max(profile?.calorieTarget ?? 0, 1)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(dayTitle)
                    .font(.rounded(.title2, weight: .bold))
                Spacer()
                DatePicker("Day", selection: $day, displayedComponents: .date)
                    .labelsHidden()
            }
            MacroBar(emoji: "🔥", name: "Calories", value: totals.calories, target: target, unit: "kcal", color: Theme.saffron)
            HStack(spacing: 8) {
                miniStat("🥚", "\(Int(totals.proteinGrams.rounded())) g", "Protein", Theme.protein)
                miniStat("🍚", "\(Int(totals.carbGrams.rounded())) g", "Carbs", Theme.carbs)
                miniStat("🥑", "\(Int(totals.fatGrams.rounded())) g", "Fat", Theme.fat)
            }
        }
        .appCard()
    }

    private func miniStat(_ emoji: String, _ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(emoji) \(value)")
                .font(.rounded(.subheadline, weight: .bold))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.rounded(.caption2))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(value)
    }

    // MARK: Meals

    @ViewBuilder
    private func mealSection(_ meal: MealType) -> some View {
        let mealEntries = dayEntries.filter { $0.mealType == meal }
        let kcal = mealEntries.reduce(0) { $0 + $1.calories }
        Section {
            if mealEntries.isEmpty {
                Text("Nothing here yet. Tap Add food 🍽️")
                    .font(.rounded(.subheadline))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(mealEntries, id: \.id) { entry in
                    HStack(spacing: 12) {
                        Text(FoodEmoji.emoji(for: entry.displayName))
                            .font(.title2)
                            .frame(width: 40, height: 40)
                            .background(Theme.saffron.opacity(0.14), in: Circle())
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.displayName)
                                .font(.rounded(.body, weight: .semibold))
                            Text("\(entry.quantity.formatted()) \(entry.servingUnit.displayName) · \(Int(entry.calories)) kcal")
                                .font(.rounded(.caption))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { indexSet in
                    for i in indexSet {
                        modelContext.delete(mealEntries[i])
                    }
                    try? modelContext.save()
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
