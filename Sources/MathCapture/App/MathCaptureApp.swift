import SwiftUI
import KeyboardShortcuts

@main
struct MathCaptureApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.openWindow) private var openWindow

    init() {
        KeyboardShortcuts.onKeyUp(for: .captureFormula) {
            CaptureManager.shared.startCapture()
        }

        NotificationManager.requestPermission()
    }

    var body: some Scene {
        MenuBarExtra("MathCapture", systemImage: "x.squareroot") {
            if let error = CaptureManager.shared.lastError {
                Text("⚠ " + error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .frame(maxWidth: 250)
                Divider()
            }

            Button("Capture Formula") {
                CaptureManager.shared.startCapture()
            }

            Divider()

            Menu("Provider: \(SettingsStore.getProvider().displayName)") {
                ForEach(InferenceProvider.allCases, id: \.self) { provider in
                    Button {
                        SettingsStore.saveProvider(provider)
                    } label: {
                        Text((provider == SettingsStore.getProvider() ? "✓ " : "") + provider.displayName)
                    }
                }
            }

            let currentProvider = SettingsStore.getProvider()
            let currentModel = SettingsStore.getModel(for: currentProvider)
            Menu("Model: \(currentModel)") {
                ForEach(currentProvider.models, id: \.self) { model in
                    Button {
                        SettingsStore.saveModel(model, for: currentProvider)
                    } label: {
                        Text((model == currentModel ? "✓ " : "") + model)
                    }
                }
            }

            let currentFormat = SettingsStore.getFormat()
            Menu("Format: \(currentFormat.displayName)") {
                ForEach(OutputFormat.allCases, id: \.self) { format in
                    Button {
                        SettingsStore.saveFormat(format)
                    } label: {
                        Text((format == currentFormat ? "✓ " : "") + format.displayName)
                    }
                }
            }

            Divider()

            Button("Recent Captures...") {
                openWindow(id: "history")
                NSApp.activate(ignoringOtherApps: true)
            }

            Divider()

            Button("Settings...") {
                openWindow(id: "settings")
                NSApp.activate(ignoringOtherApps: true)
            }

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }

        Window("Welcome", id: "setup") {
            SetupView()
                .fixedSize()
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)

        Window("MathCapture Settings", id: "settings") {
            SettingsView()
                .frame(minWidth: 420)
                .fixedSize()
        }
        .windowResizability(.contentSize)

        Window("Recent Captures", id: "history") {
            CaptureHistoryView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !UserDefaults.standard.bool(forKey: "setupComplete") else { return }

        var attempts = 0
        let timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { timer in
            attempts += 1
            guard attempts < 20 else { timer.invalidate(); return }

            if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "setup" }) {
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                timer.invalidate()
            }
        }
        timer.fire()
    }
}

extension KeyboardShortcuts.Name {
    static let captureFormula = Self("captureFormula")
}
