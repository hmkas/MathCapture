import AppKit
import SwiftUI

@MainActor
final class CaptureManager: ObservableObject {
    static let shared = CaptureManager()

    @Published var lastError: String?

    private var overlayWindow: CapturePanel?
    private var overlayView: OverlayView?

    private init() {}

    func startCapture() {
        let provider = SettingsStore.getProvider()
        guard SettingsStore.getAPIKey(for: provider) != nil else {
            lastError = "Configure your \(provider.apiKeyLabel) in Settings first."
            NotificationManager.showError(lastError!)
            return
        }

        guard let screen = NSScreen.main else { return }

        let panel = CapturePanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.level = .screenSaver
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.title = "MathCapture"

        let overlay = OverlayView(frame: screen.frame)
        overlay.onCapture = { [weak self] image in
            Task { @MainActor [weak self] in
                self?.processImage(image)
            }
        }
        overlay.onCancel = { [weak self] in
            self?.hideOverlay()
        }

        panel.contentView = overlay
        self.overlayView = overlay
        self.overlayWindow = panel

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    private func processImage(_ image: CGImage) {
        hideOverlay()
        lastError = nil

        Task {
            do {
                let result = try await InferenceService.shared.recognizeFormula(image: image)
                await MainActor.run {
                    let provider = SettingsStore.getProvider()
                    let model = SettingsStore.getModel(for: provider)
                    let format = SettingsStore.getFormat()
                    CaptureHistory.shared.addEntry(
                        content: result,
                        format: format.displayName,
                        provider: provider.displayName,
                        model: model,
                        image: image
                    )
                    ClipboardManager.copyText(result)
                    NotificationManager.showSuccess(format: format)
                }
            } catch {
                await MainActor.run {
                    lastError = error.localizedDescription
                    NotificationManager.showError(error.localizedDescription)
                }
            }
        }
    }

    private func hideOverlay() {
        overlayView?.cleanup()
        overlayWindow?.orderOut(nil)
        overlayWindow = nil
        overlayView = nil
    }
}
