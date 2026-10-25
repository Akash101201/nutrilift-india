import SwiftUI
import SwiftData

struct BarcodeScanFlowView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \FoodItem.name) private var foods: [FoodItem]

    var day: Date
    var initialMeal: MealType = .lunch

    @State private var meal: MealType = .lunch
    @State private var didSetMeal = false
    @State private var showCamera = false
    @State private var manualCode = ""
    @State private var phase: Phase = .capture
    @State private var product: BarcodeProduct?
    @State private var quantity = 1.0
    @State private var errorMessage: String?
    @State private var lookingUpOnline = false
    @State private var showCustom = false

    private enum Phase {
        case capture
        case found
        case notFound(code: String)
    }

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .capture:
                    capturePage
                case .found:
                    if let product {
                        confirmPage(product)
                    }
                case .notFound(let code):
                    notFoundPage(code: code)
                }
            }
            .appBackground()
            .tint(Theme.saffron)
            .navigationTitle("Scan barcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                if !didSetMeal {
                    meal = initialMeal
                    didSetMeal = true
                }
            }
            .alert("Lookup failed", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .fullScreenCover(isPresented: $showCamera) {
                ZStack(alignment: .topTrailing) {
                    BarcodeScannerView(
                        onCode: { code in
                            showCamera = false
                            resolve(code: code)
                        },
                        onCancel: { showCamera = false }
                    )
                    .ignoresSafeArea()
                    Button("Cancel") { showCamera = false }
                        .buttonStyle(.soft)
                        .padding()
                }
            }
            .sheet(isPresented: $showCustom) {
                CustomFoodView(day: day, initialMeal: meal)
            }
        }
    }

    // MARK: Capture

    private var capturePage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("📦 Packaged Indian products")
                        .font(.rounded(.title3, weight: .bold))
                    Text("Scan whey, protein bars, Amul protein drinks, and more. We check a local Indian list first; you can optionally look up Open Food Facts online.")
                        .font(.rounded(.subheadline))
                        .foregroundStyle(.secondary)
                }
                .appCard()

                EmojiSegmented(
                    options: MealType.allCases.map { EmojiOption(value: $0, emoji: $0.emoji, title: $0.displayName) },
                    selection: $meal
                )

                if BarcodeCameraSupport.isAvailable {
                    Button {
                        showCamera = true
                    } label: {
                        Label("Scan with camera", systemImage: "barcode.viewfinder")
                    }
                    .buttonStyle(.gradient)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Or type the barcode")
                        .font(.rounded(.headline, weight: .semibold))
                    TextField("EAN / UPC number", text: $manualCode)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .font(.rounded(.body, weight: .medium))
                    Button("Look up") {
                        resolve(code: manualCode)
                    }
                    .buttonStyle(.soft)
                    .disabled(BarcodeCatalog.normalize(manualCode).count < 8)
                }
                .appCard()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Popular in catalog")
                        .font(.rounded(.headline, weight: .semibold))
                    ForEach(BarcodeCatalog.all.prefix(6)) { item in
                        Button {
                            product = item
                            quantity = 1
                            phase = .found
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.displayName)
                                        .font(.rounded(.subheadline, weight: .semibold))
                                        .foregroundStyle(.primary)
                                    Text("\(Int(item.calories.rounded())) kcal · \(Int(item.proteinG.rounded())) g protein")
                                        .font(.rounded(.caption))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
                .appCard()
            }
            .padding(20)
        }
    }

    // MARK: Confirm

    private func confirmPage(_ product: BarcodeProduct) -> some View {
        ScrollView {
            VStack(spacing: 18) {
                VStack(spacing: 6) {
                    Text(product.category == "whey" ? "🥤" : (product.category == "protein_drink" ? "🥛" : "🍫"))
                        .font(.system(size: 56))
                    Text(product.displayName)
                        .font(.rounded(.title2, weight: .bold))
                        .multilineTextAlignment(.center)
                    Text("\(meal.emoji) \(meal.displayName) · \(product.barcode)")
                        .font(.rounded(.subheadline))
                        .foregroundStyle(.secondary)
                    Text(originBadge(product))
                        .font(.rounded(.caption, weight: .medium))
                        .foregroundStyle(Theme.leaf)
                }
                .frame(maxWidth: .infinity)
                .appCard()

                VStack(spacing: 14) {
                    BigStepper(
                        value: $quantity,
                        range: 0.25...20,
                        step: 0.25,
                        unit: product.servingUnit.displayName,
                        fractionDigits: 2
                    )
                }
                .appCard()

                let snap = product.perServingSnapshot.scaled(by: quantity)
                VStack(spacing: 12) {
                    Text("\(Int(snap.calories.rounded())) kcal")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    HStack {
                        macroChip("🥚", snap.proteinGrams, Theme.protein)
                        macroChip("🍚", snap.carbGrams, Theme.carbs)
                        macroChip("🥑", snap.fatGrams, Theme.fat)
                    }
                }
                .appCard()
            }
            .padding(20)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                Button("Add to diary") { log(product) }
                    .buttonStyle(.gradient)
                Button("Scan another") {
                    phase = .capture
                    self.product = nil
                    manualCode = ""
                }
                .font(.rounded(.subheadline, weight: .semibold))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.bar)
        }
    }

    private func originBadge(_ product: BarcodeProduct) -> String {
        switch product.lookupOrigin {
        case .local: "Local Indian catalog"
        case .openFoodFacts: "Open Food Facts · online"
        case .manual: "Manual"
        }
    }

    private func macroChip(_ emoji: String, _ grams: Double, _ color: Color) -> some View {
        Text("\(emoji) \(Int(grams.rounded())) g")
            .font(.rounded(.subheadline, weight: .bold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: Not found

    private func notFoundPage(code: String) -> some View {
        VStack(spacing: 18) {
            FriendlyEmptyState(
                emoji: "🔍",
                title: "Not in the local list",
                message: "Barcode \(code) isn’t in our Indian whey/bar pack. Look up Open Food Facts online, or add it as a custom food."
            )
            if lookingUpOnline {
                ProgressView("Checking Open Food Facts…")
            } else {
                Button("Look up online (Open Food Facts)") {
                    Task { await lookupOnline(code: code) }
                }
                .buttonStyle(.gradient)
                Button("Add as custom food") {
                    showCustom = true
                }
                .buttonStyle(.soft)
            }
            Button("Try another barcode") {
                phase = .capture
                manualCode = ""
            }
            .font(.rounded(.subheadline, weight: .semibold))
        }
        .padding(20)
    }

    // MARK: Logic

    private func resolve(code: String) {
        let normalized = BarcodeCatalog.normalize(code)
        guard normalized.count >= 8 else {
            errorMessage = "Enter at least 8 digits."
            return
        }
        if let local = BarcodeCatalog.lookup(normalized) {
            product = local
            quantity = 1
            phase = .found
            Haptics.success()
            return
        }
        phase = .notFound(code: normalized)
    }

    @MainActor
    private func lookupOnline(code: String) async {
        lookingUpOnline = true
        defer { lookingUpOnline = false }
        do {
            let found = try await OpenFoodFactsClient.lookup(barcode: code)
            product = found
            quantity = 1
            phase = .found
            Haptics.success()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func log(_ product: BarcodeProduct) {
        let item = upsertFoodItem(from: product)
        let snap = product.perServingSnapshot.scaled(by: quantity)
        modelContext.insert(FoodDiaryEntry(
            date: day,
            mealType: meal,
            foodSeedId: item.seedId,
            displayName: product.displayName,
            quantity: quantity,
            servingUnit: product.servingUnit,
            snapshot: snap,
            source: .barcode
        ))
        item.lastUsedAt = Date()
        try? modelContext.save()
        Haptics.success()
        dismiss()
    }

    private func upsertFoodItem(from product: BarcodeProduct) -> FoodItem {
        if let existing = foods.first(where: { $0.seedId == product.foodSeedId }) {
            return existing
        }
        let item = FoodItem(
            seedId: product.foodSeedId,
            name: product.displayName,
            transliterations: [product.barcode, product.brand].filter { !$0.isEmpty },
            servingUnit: product.servingUnit,
            servingAmount: product.servingAmount,
            gramsPerServing: product.gramsPerServing,
            calories: product.calories,
            proteinG: product.proteinG,
            carbG: product.carbG,
            fatG: product.fatG,
            sourceTag: product.source,
            confidence: "high",
            isCustom: true
        )
        modelContext.insert(item)
        return item
    }
}
