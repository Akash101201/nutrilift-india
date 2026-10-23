import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct PhotoFoodFlowView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var foods: [FoodItem]

    var day: Date

    @StateObject private var vm = PhotoFoodViewModel()
    @State private var pickerItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var meal: MealType = .lunch

    var body: some View {
        NavigationStack {
            Group {
                switch vm.phase {
                case .capture:
                    capturePage
                case .estimating:
                    ProgressView("Estimating on-device…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .review:
                    reviewPage
                case .unavailable:
                    ContentUnavailableView(
                        "Photo estimate unavailable",
                        systemImage: "camera.metering.unknown",
                        description: Text(PhotoNutritionError.unavailable.localizedDescription)
                    )
                }
            }
            .navigationTitle("Photo food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                if !vm.estimator.isAvailable {
                    vm.phase = .unavailable
                }
            }
            .alert("Estimate failed", isPresented: Binding(
                get: { vm.errorMessage != nil },
                set: { if !$0 { vm.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(vm.errorMessage ?? "")
            }
        }
    }

    private var capturePage: some View {
        Form {
            Section {
                Text("Photos stay on this device. They are not uploaded. Estimates use Apple Foundation Models only.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Label("Photo not uploaded", systemImage: "lock.shield")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Photo") {
                if let image = vm.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Label("Choose photo", systemImage: "photo")
                }
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button {
                        showCamera = true
                    } label: {
                        Label("Take photo", systemImage: "camera")
                    }
                }
            }

            Section("Optional hints (improves estimate)") {
                TextField("Food name", text: $vm.foodNameHint)
                TextField("Quantity (e.g. 2 roti, 1 katori)", text: $vm.quantityHint)
            }

            Section("Meal") {
                Picker("Meal", selection: $meal) {
                    ForEach(MealType.allCases) { Text($0.displayName).tag($0) }
                }
            }

            Section {
                Button("Estimate on-device") {
                    Task { await vm.runEstimate() }
                }
                .disabled(vm.imageJPEG == nil)
            }
        }
        .onChange(of: pickerItem) { _, item in
            Task {
                guard let item,
                      let data = try? await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else { return }
                vm.setImage(image)
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in
                if let image { vm.setImage(image) }
                showCamera = false
            }
            .ignoresSafeArea()
        }
    }

    private var reviewPage: some View {
        Form {
            Section {
                Label("Estimate — confirm or edit before saving", systemImage: "pencil")
                    .font(.footnote)
                Label("Photo not uploaded · discarded after save", systemImage: "trash")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Override any field") {
                TextField("Name", text: $vm.editName)
                HStack {
                    Text("Quantity")
                    TextField("Qty", value: $vm.editQuantity, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
                Picker("Unit", selection: $vm.editUnit) {
                    ForEach(ServingUnit.allCases) { Text($0.displayName).tag($0) }
                }
                macroField("Calories", value: $vm.editCalories)
                macroField("Protein g", value: $vm.editProtein)
                macroField("Carbs g", value: $vm.editCarbs)
                macroField("Fat g", value: $vm.editFat)
            }
            if let notes = vm.estimateNotes, !notes.isEmpty {
                Section("Model notes") {
                    Text(notes).font(.footnote).foregroundStyle(.secondary)
                }
            }
            Section {
                Button("Save to diary") {
                    save()
                }
                Button("Discard", role: .destructive) {
                    vm.resetToCapture()
                }
            }
        }
    }

    private func macroField(_ title: String, value: Binding<Double>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField(title, value: value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 100)
        }
    }

    private func save() {
        let name = vm.editName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let match = foods.first { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }
        let snap = MacroSnapshot(
            calories: vm.editCalories,
            proteinGrams: vm.editProtein,
            carbGrams: vm.editCarbs,
            fatGrams: vm.editFat
        )
        modelContext.insert(FoodDiaryEntry(
            date: day,
            mealType: meal,
            foodSeedId: match?.seedId,
            displayName: name,
            quantity: vm.editQuantity,
            servingUnit: vm.editUnit,
            snapshot: snap,
            source: .photoEstimate
        ))
        if let match {
            match.lastUsedAt = Date()
        }
        try? modelContext.save()
        vm.discardPhoto()
        dismiss()
    }
}

@MainActor
final class PhotoFoodViewModel: ObservableObject {
    enum Phase {
        case capture, estimating, review, unavailable
    }

    let estimator: any PhotoNutritionEstimating = PhotoNutritionEstimatorFactory.make()

    @Published var phase: Phase = .capture
    @Published var image: UIImage?
    @Published var imageJPEG: Data?
    @Published var foodNameHint = ""
    @Published var quantityHint = ""
    @Published var errorMessage: String?

    @Published var editName = ""
    @Published var editQuantity = 1.0
    @Published var editUnit: ServingUnit = .plate
    @Published var editCalories = 0.0
    @Published var editProtein = 0.0
    @Published var editCarbs = 0.0
    @Published var editFat = 0.0
    @Published var estimateNotes: String?

    /// True only after user reaches review; prevents accidental auto-save.
    @Published var awaitingConfirm = false

    func setImage(_ image: UIImage) {
        self.image = image
        self.imageJPEG = image.jpegData(compressionQuality: 0.85)
    }

    func runEstimate() async {
        guard let data = imageJPEG else { return }
        phase = .estimating
        do {
            let estimate = try await estimator.estimate(PhotoNutritionRequest(
                imageJPEGData: data,
                foodNameHint: foodNameHint.isEmpty ? nil : foodNameHint,
                quantityHint: quantityHint.isEmpty ? nil : quantityHint
            ))
            apply(estimate)
            awaitingConfirm = true
            phase = .review
        } catch {
            errorMessage = error.localizedDescription
            phase = .capture
        }
    }

    func apply(_ estimate: PhotoNutritionEstimate) {
        editName = estimate.name
        editQuantity = estimate.quantity
        editUnit = estimate.servingUnit
        editCalories = estimate.calories
        editProtein = estimate.proteinGrams
        editCarbs = estimate.carbGrams
        editFat = estimate.fatGrams
        estimateNotes = estimate.notes
    }

    func canSaveConfirmed() -> Bool {
        awaitingConfirm && !editName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func discardPhoto() {
        image = nil
        imageJPEG = nil
        awaitingConfirm = false
    }

    func resetToCapture() {
        discardPhoto()
        phase = estimator.isAvailable ? .capture : .unavailable
    }
}

struct CameraPicker: UIViewControllerRepresentable {
    var onImage: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onImage: onImage) }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onImage: (UIImage?) -> Void
        init(onImage: @escaping (UIImage?) -> Void) { self.onImage = onImage }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onImage(nil)
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            onImage(info[.originalImage] as? UIImage)
        }
    }
}
