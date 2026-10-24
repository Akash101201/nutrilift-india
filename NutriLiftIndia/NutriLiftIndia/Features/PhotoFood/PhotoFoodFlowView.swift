import SwiftUI
import SwiftData
import PhotosUI
import UIKit

/// How the Food tab should open the photo estimate flow.
enum PhotoFoodCapturePreference: Equatable {
    /// Show the capture screen (user picks gallery or camera).
    case choose
    /// Jump straight into the system camera when available.
    case camera
}

struct PhotoFoodFlowView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var foods: [FoodItem]

    var day: Date
    var preferredCapture: PhotoFoodCapturePreference = .choose

    @StateObject private var vm = PhotoFoodViewModel()
    @State private var pickerItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var meal: MealType = .lunch
    @State private var didApplyPreference = false

    var body: some View {
        NavigationStack {
            Group {
                switch vm.phase {
                case .capture:
                    capturePage
                case .estimating:
                    VStack(spacing: 14) {
                        Text("🔍")
                            .font(.system(size: 56))
                            .accessibilityHidden(true)
                        ProgressView()
                        Text("Estimating on-device…")
                            .font(.rounded(.headline, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .review:
                    reviewPage
                case .unavailable:
                    FriendlyEmptyState(
                        emoji: "📵",
                        title: "Photo estimate unavailable",
                        message: PhotoNutritionError.unavailable.localizedDescription
                    )
                }
            }
            .appBackground()
            .tint(Theme.saffron)
            .navigationTitle("Photo food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                guard vm.estimator.isAvailable else { return }
                applyPreferredCaptureIfNeeded()
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

    private func applyPreferredCaptureIfNeeded() {
        guard !didApplyPreference else { return }
        didApplyPreference = true
        guard preferredCapture == .camera,
              UIImagePickerController.isSourceTypeAvailable(.camera) else { return }
        // Slight delay so the sheet can finish presenting before the camera cover.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            showCamera = true
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
            .listRowBackground(Theme.card)

            Section {
                if let image = vm.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button {
                        showCamera = true
                    } label: {
                        Label("Take photo with camera", systemImage: "camera.fill")
                            .font(.rounded(.body, weight: .semibold))
                    }
                }

                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Label("Choose from photo library", systemImage: "photo.on.rectangle")
                        .font(.rounded(.body, weight: .semibold))
                }
            } header: {
                EmojiHeader(emoji: "📸", title: "Capture or choose")
            } footer: {
                Text("Camera and library both stay on-device. Confirm the estimate before it is saved to your diary.")
                    .font(.rounded(.caption))
            }
            .listRowBackground(Theme.card)

            Section {
                TextField("Food name", text: $vm.foodNameHint)
                TextField("Quantity (e.g. 2 roti, 1 katori)", text: $vm.quantityHint)
            } header: {
                EmojiHeader(emoji: "💡", title: "Optional hints (improves estimate)")
            }
            .listRowBackground(Theme.card)

            Section {
                EmojiSegmented(
                    options: MealType.allCases.map { EmojiOption(value: $0, emoji: $0.emoji, title: $0.displayName) },
                    selection: $meal
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            } header: {
                EmojiHeader(emoji: "🍽️", title: "Meal")
            }

            Section {
                Button("Estimate on-device ✨") {
                    Task { await vm.runEstimate() }
                }
                .buttonStyle(.gradient)
                .disabled(vm.imageJPEG == nil)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
        }
        .scrollContentBackground(.hidden)
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
            .listRowBackground(Theme.card)
            Section {
                TextField("Name", text: $vm.editName)
                LabeledNumberField("Quantity", value: $vm.editQuantity, emoji: "🔢")
                Picker("Unit", selection: $vm.editUnit) {
                    ForEach(ServingUnit.allCases) { Text("\($0.emoji) \($0.displayName)").tag($0) }
                }
                LabeledNumberField("Calories", value: $vm.editCalories, unit: "kcal", emoji: "🔥")
                LabeledNumberField("Protein", value: $vm.editProtein, unit: "g", emoji: "🥚")
                LabeledNumberField("Carbs", value: $vm.editCarbs, unit: "g", emoji: "🍚")
                LabeledNumberField("Fat", value: $vm.editFat, unit: "g", emoji: "🥑")
            } header: {
                EmojiHeader(emoji: "✏️", title: "Override any field")
            }
            .listRowBackground(Theme.card)
            if let notes = vm.estimateNotes, !notes.isEmpty {
                Section {
                    Text(notes).font(.footnote).foregroundStyle(.secondary)
                } header: {
                    EmojiHeader(emoji: "📝", title: "Model notes")
                }
                .listRowBackground(Theme.card)
            }
            Section {
                Button("Save to diary") {
                    save()
                }
                .buttonStyle(.gradient)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                Button("Discard", role: .destructive) {
                    vm.resetToCapture()
                }
                .listRowBackground(Theme.card)
            }
        }
        .scrollContentBackground(.hidden)
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

    @Published var phase: Phase
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

    init() {
        phase = estimator.isAvailable ? .capture : .unavailable
    }

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
