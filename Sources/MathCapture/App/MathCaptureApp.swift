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
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundColor(.red)
                    .frame(maxWidth: 250)
                Divider()
            }

            Button {
                CaptureManager.shared.startCapture()
            } label: {
                Label("Capture Formula", systemImage: "camera.viewfinder")
            }

            Divider()

            Menu {
                ForEach(InferenceProvider.allCases, id: \.self) { provider in
                    Button {
                        SettingsStore.saveProvider(provider)
                    } label: {
                        let isSelected = provider == SettingsStore.getProvider()
                        HStack {
                            if isSelected {
                                Image(systemName: "checkmark")
                            }
                            Label(provider.displayName, systemImage: provider.iconName)
                        }
                    }
                }
            } label: {
                Label("Provider: \(SettingsStore.getProvider().displayName)", systemImage: "server.rack")
            }

            let currentProvider = SettingsStore.getProvider()
            let currentModel = SettingsStore.getModel(for: currentProvider)
            Menu {
                ForEach(currentProvider.models, id: \.self) { model in
                    Button {
                        SettingsStore.saveModel(model, for: currentProvider)
                    } label: {
                        let isSelected = model == currentModel
                        Text((isSelected ? "✓ " : "") + model)
                    }
                }
            } label: {
                Label("Model: \(currentModel)", systemImage: "cpu")
            }

            let currentFormat = SettingsStore.getFormat()
            Menu {
                ForEach(OutputFormat.allCases, id: \.self) { format in
                    Button {
                        SettingsStore.saveFormat(format)
                    } label: {
                        let isSelected = format == currentFormat
                        HStack {
                            if isSelected {
                                Image(systemName: "checkmark")
                            }
                            Label(format.displayName, systemImage: format.iconName)
                        }
                    }
                }
            } label: {
                Label("Format: \(currentFormat.displayName)", systemImage: "doc.text")
            }

            Divider()

            Button {
                openWindow(id: "history")
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Label("Recent Captures", systemImage: "clock.arrow.circlepath")
            }

            Divider()

            Button {
                openWindow(id: "settings")
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Label("Settings", systemImage: "gearshape")
            }

            Divider()

            Button(role: .destructive) {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit MathCapture", systemImage: "power")
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
