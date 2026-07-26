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
            Section {
                Picker("Provider", selection: $selectedProvider) {
                    ForEach(InferenceProvider.allCases, id: \.self) { provider in
                        Label(provider.displayName, systemImage: provider.iconName)
                            .tag(provider)
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
            } header: {
                Label("Inference Provider", systemImage: "server.rack")
            }

            Section {
                if selectedProvider == .apfel {
                    Label {
                        Text("Apfel runs on-device. No API key required unless the server was started with --token.")
                    } icon: {
                        Image(systemName: "info.circle")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                SecureField("API Key", text: $apiKey)
                    .textFieldStyle(.roundedBorder)

                HStack(spacing: 8) {
                    Button {
                        do {
                            try SettingsStore.saveAPIKey(apiKey, for: selectedProvider)
                            testStatus = .success
                        } catch {
                            testStatus = .failure(error.localizedDescription)
                        }
                    } label: {
                        Label("Save", systemImage: "checkmark")
                    }

                    Button {
                        testAPI()
                    } label: {
                        Label(selectedProvider == .apfel ? "Test Connection" : "Test API", systemImage: "bolt")
                    }
                    .disabled(selectedProvider != .apfel && (apiKey.isEmpty || testStatus == .testing))

                    Spacer()

                    switch testStatus {
                    case .idle:
                        EmptyView()
                    case .testing:
                        ProgressView()
                            .scaleEffect(0.7)
                    case .success:
                        Label("OK", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    case .failure(let msg):
                        Label(msg, systemImage: "xmark.circle.fill")
                            .foregroundColor(.red)
                            .font(.caption)
                            .lineLimit(2)
                            .truncationMode(.tail)
                    }
                }
            } header: {
                Label(selectedProvider.apiKeyLabel, systemImage: selectedProvider.iconName)
            }

            Section {
                KeyboardShortcuts.Recorder("Capture Formula:", name: .captureFormula)
                    .labelsHidden()

                Label("Default: ⌘⌥M", systemImage: "keyboard")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Label("Shortcut", systemImage: "command")
            }

            Section {
                Picker("Format", selection: $selectedFormat) {
                    ForEach(OutputFormat.allCases, id: \.self) { format in
                        Label(format.displayName, systemImage: format.iconName)
                            .tag(format)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: selectedFormat) { _, newFormat in
                    SettingsStore.saveFormat(newFormat)
                }
            } header: {
                Label("Output Format", systemImage: "doc.text")
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
