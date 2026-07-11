import SwiftUI
import AppKit

struct SetupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var apfelStatus: ApfelStatus = .checking

    enum ApfelStatus {
        case checking
        case installed
        case notInstalled
        case installing
        case installFailed(String)

        var isInstalling: Bool {
            if case .installing = self { return true }
            return false
        }

        var isInstalled: Bool {
            if case .installed = self { return true }
            return false
        }
    }

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "x.squareroot")
                .font(.system(size: 40))
                .foregroundColor(.accentColor)

            Text("Welcome to MathCapture")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Capture math formulas from your screen and copy the result as LaTeX or MathML.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "apple.terminal")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Apfel (Local AI)")
                            .fontWeight(.medium)
                        Text(detailText)
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }

                    Spacer()

                    switch apfelStatus {
                    case .notInstalled:
                        Button("Install") { installApfel() }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    case .installing:
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(height: 20)
                    default:
                        EmptyView()
                    }

                    Image(systemName: apfelIcon)
                        .foregroundColor(apfelColor)
                        .font(.title3)
                }
                .padding(12)
                .background(Color(.textBackgroundColor))
                .cornerRadius(8)

                if #available(macOS 15, *) {
                    ScreenRecordingRow()
                } else {
                    setupRow(
                        icon: "rectangle.dashed",
                        title: "Screen Recording",
                        detail: "macOS will ask for permission on your first capture",
                        statusIcon: "circle",
                        statusColor: .secondary
                    )
                }
            }

            VStack(spacing: 8) {
                Button("Get Started") {
                    completeSetup()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(apfelStatus.isInstalling)

                if !apfelStatus.isInstalled {
                    Button("Skip — use a cloud provider") {
                        completeSetup()
                    }
                    .buttonStyle(.link)
                    .controlSize(.small)
                }
            }

            Text("You can always switch providers in Settings")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(24)
        .frame(width: 420)
        .fixedSize()
        .onAppear(perform: checkApfel)
    }

    private var detailText: String {
        switch apfelStatus {
        case .checking: return "Checking..."
        case .installed: return "Ready for on-device recognition"
        case .notInstalled: return "Install for 100% offline formula recognition"
        case .installing: return "Installing via Homebrew..."
        case .installFailed(let msg): return msg
        }
    }

    private var apfelIcon: String {
        switch apfelStatus {
        case .checking: return "circle"
        case .installed: return "checkmark.circle.fill"
        case .notInstalled, .installFailed: return "xmark.circle.fill"
        case .installing: return "circle"
        }
    }

    private var apfelColor: Color {
        switch apfelStatus {
        case .checking: return .gray
        case .installed: return .green
        case .notInstalled: return .orange
        case .installing: return .gray
        case .installFailed: return .red
        }
    }

    private func checkApfel() {
        DispatchQueue.global().async {
            let installed = InferenceService.isApfelInstalled
            DispatchQueue.main.async {
                apfelStatus = installed ? .installed : .notInstalled
            }
        }
    }

    private func installApfel() {
        apfelStatus = .installing
        DispatchQueue.global().async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = ["-c", "brew install apfel"]

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            do {
                try process.run()
                process.waitUntilExit()

                if process.terminationStatus == 0 {
                    DispatchQueue.main.async {
                        apfelStatus = .installed
                    }
                } else {
                    let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let msg = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                        ?? "Installation failed. Try: brew install apfel"
                    DispatchQueue.main.async {
                        apfelStatus = .installFailed(msg)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    apfelStatus = .installFailed(error.localizedDescription)
                }
            }
        }
    }

    private func completeSetup() {
        UserDefaults.standard.set(true, forKey: "setupComplete")
        dismiss()
    }

    private func setupRow(icon: String, title: String, detail: String, statusIcon: String, statusColor: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .fontWeight(.medium)
                Text(detail)
                    .foregroundColor(.secondary)
                    .font(.caption)
            }

            Spacer()

            Image(systemName: statusIcon)
                .foregroundColor(statusColor)
                .font(.title3)
        }
        .padding(12)
        .background(Color(.textBackgroundColor))
        .cornerRadius(8)
    }
}

@available(macOS 15, *)
private struct ScreenRecordingRow: View {
    @State private var isGranted: Bool?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "rectangle.dashed")
                .font(.title3)
                .foregroundColor(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text("Screen Recording")
                    .fontWeight(.medium)
                Text(isGranted == true ? "Granted" : isGranted == false ? "Required for capture" : "Checking...")
                    .foregroundColor(isGranted == true ? .secondary : .orange)
                    .font(.caption)
            }

            Spacer()

            if isGranted == false {
                Button("Grant Access") {
                    CGRequestScreenCaptureAccess()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Image(systemName: isGranted == true ? "checkmark.circle.fill" : isGranted == false ? "xmark.circle.fill" : "circle")
                .foregroundColor(isGranted == true ? .green : isGranted == false ? .orange : .gray)
                .font(.title3)
        }
        .padding(12)
        .background(Color(.textBackgroundColor))
        .cornerRadius(8)
        .onAppear {
            isGranted = CGPreflightScreenCaptureAccess()
        }
    }
}

extension Notification.Name {
    static let setupComplete = Notification.Name("setupComplete")
}
