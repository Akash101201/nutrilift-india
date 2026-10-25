import SwiftUI
import AVFoundation
import VisionKit

/// Live barcode scanner. Uses VisionKit DataScanner when available; otherwise a camera unavailable message.
struct BarcodeScannerView: UIViewControllerRepresentable {
    var onCode: (String) -> Void
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        if DataScannerViewController.isSupported, DataScannerViewController.isAvailable {
            let scanner = DataScannerViewController(
                recognizedDataTypes: [.barcode()],
                qualityLevel: .balanced,
                recognizesMultipleItems: false,
                isHighFrameRateTrackingEnabled: false,
                isHighlightingEnabled: true
            )
            scanner.delegate = context.coordinator
            context.coordinator.scanner = scanner
            return scanner
        }
        return UIHostingController(rootView: UnsupportedScannerView(onCancel: onCancel))
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        if let scanner = uiViewController as? DataScannerViewController, context.coordinator.started == false {
            try? scanner.startScanning()
            context.coordinator.started = true
        }
    }

    static func dismantleUIViewController(_ uiViewController: UIViewController, coordinator: Coordinator) {
        (uiViewController as? DataScannerViewController)?.stopScanning()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onCode: onCode, onCancel: onCancel)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onCode: (String) -> Void
        let onCancel: () -> Void
        var scanner: DataScannerViewController?
        var started = false
        private var locked = false

        init(onCode: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
            self.onCode = onCode
            self.onCancel = onCancel
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            handle(item)
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard let first = addedItems.first else { return }
            handle(first)
        }

        private func handle(_ item: RecognizedItem) {
            guard !locked else { return }
            if case .barcode(let barcode) = item, let payload = barcode.payloadStringValue {
                let digits = payload.filter(\.isNumber)
                guard digits.count >= 8 else { return }
                locked = true
                scanner?.stopScanning()
                Haptics.success()
                onCode(digits)
            }
        }
    }
}

private struct UnsupportedScannerView: View {
    var onCancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("📷")
                .font(.system(size: 48))
            Text("Barcode camera unavailable")
                .font(.rounded(.headline, weight: .bold))
            Text("Use a physical iPhone, or enter the barcode number manually.")
                .font(.rounded(.subheadline))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Close", action: onCancel)
                .buttonStyle(.gradient)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appBackground()
    }
}

enum BarcodeCameraSupport {
    static var isAvailable: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }
}
