import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    @State private var selectedProvider: InferenceProvider = .google
    @State private var apiKey: String = ""
    @State private var selectedModel: String = ""
    @State private var selectedFormat: OutputFormat = .mathML
    @State private var testStatus: TestStatus = .idle

    enum TestStatus: Equatable {
        case idle
        case testing
        case success
        case failure(String)
    }

    var body: some View {
        Form {
            Section("Inference Provider") {
                Picker("Provider", selection: $selectedProvider) {
                    ForEach(InferenceProvider.allCases, id: \.self) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: selectedProvider) { _, newProvider in
                    providerDidChange(to: newProvider)
                }

                Picker("Model", selection: $selectedModel) {
                    ForEach(selectedProvider.models, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
                .pickerStyle(.menu)
                .disabled(testStatus == .testing)
            }

            Section(selectedProvider.apiKeyLabel) {
                if selectedProvider == .apfel {
                    Text("Apfel runs on-device. No API key required unless the server was started with --token.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                SecureField("API Key", text: $apiKey)
                    .textFieldStyle(.roundedBorder)

                HStack(spacing: 8) {
                    Button("Save") {
                        do {
                            try SettingsStore.saveAPIKey(apiKey, for: selectedProvider)
                            testStatus = .success
                        } catch {
                            testStatus = .failure(error.localizedDescription)
                        }
                    }

                    Button(selectedProvider == .apfel ? "Test Connection" : "Test API") {
                        testAPI()
                    }
                    .disabled(selectedProvider != .apfel && (apiKey.isEmpty || testStatus == .testing))

                    switch testStatus {
                    case .idle:
                        EmptyView()
                    case .testing:
                        ProgressView()
                            .scaleEffect(0.7)
                    case .success:
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .help("API key werkt")
                    case .failure(let msg):
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                        Text(msg)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }

            Section("Shortcut") {
                KeyboardShortcuts.Recorder("Capture Formula:", name: .captureFormula)
                    .labelsHidden()

                Text("Default: ⌘⌥M")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Output Format") {
                Picker("Format", selection: $selectedFormat) {
                    ForEach(OutputFormat.allCases, id: \.self) { format in
                        Text(format.displayName).tag(format)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: selectedFormat) { _, newFormat in
                    SettingsStore.saveFormat(newFormat)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            loadSavedSettings()
        }
    }

    private func loadSavedSettings() {
        let provider = SettingsStore.getProvider()
        selectedProvider = provider
        selectedModel = SettingsStore.getModel(for: provider)
        selectedFormat = SettingsStore.getFormat()
        apiKey = SettingsStore.getAPIKey(for: provider) ?? ""
    }

    private func providerDidChange(to provider: InferenceProvider) {
        let savedModel = SettingsStore.getModel(for: provider)
        selectedModel = provider.models.contains(savedModel) ? savedModel : provider.defaultModel
        apiKey = SettingsStore.getAPIKey(for: provider) ?? ""
        SettingsStore.saveProvider(provider)
        testStatus = .idle
    }

    private func testAPI() {
        testStatus = .testing
        let key = apiKey
        let provider = selectedProvider

        Task {
            do {
                try await InferenceService.shared.testAPIKey(key, for: provider)
                await MainActor.run {
                    testStatus = .success
                }
            } catch {
                await MainActor.run {
                    testStatus = .failure(error.localizedDescription)
                }
            }
        }
    }
}
