import SwiftUI
import KeyboardShortcuts

@main
struct MathCaptureApp: App {
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

extension KeyboardShortcuts.Name {
    static let captureFormula = Self("captureFormula")
}
