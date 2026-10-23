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

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                Picker("Unit", selection: $unit) {
                    ForEach(ServingUnit.allCases) { Text($0.displayName).tag($0) }
                }
                field("Serving amount", value: $amount)
                field("Calories", value: $calories)
                field("Protein g", value: $protein)
                field("Carbs g", value: $carbs)
                field("Fat g", value: $fat)
            }
            .navigationTitle("Custom food")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let item = FoodItem(
                            name: name,
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
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func field(_ title: String, value: Binding<Double>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField(title, value: value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 100)
        }
    }
}
