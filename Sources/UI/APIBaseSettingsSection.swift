import SwiftUI

struct APIBaseSettingsSection: View {
    @ObservedObject var settings: SettingsManager
    let onSave: () -> Void

    @State private var apiBaseOption: APIBaseOption = .zenmuxAI
    @State private var customAPIBaseInput: String = ""
    @State private var showSaved = false
    @State private var error: String?

    var body: some View {
        settingsCard(
            icon: "globe",
            title: "API Base",
            subtitle: "Select the ZenMux domain used for quota requests, or provide a custom base URL."
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    Text("Endpoint")
                        .foregroundStyle(.secondary)

                    Spacer(minLength: 16)

                    Picker("API Base", selection: $apiBaseOption) {
                        ForEach(APIBaseOption.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .labelsHidden()
                    .accessibilityLabel("API Base")
                }

                if apiBaseOption == .custom {
                    TextField("https://your-zenmux-server.example", text: $customAPIBaseInput)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.large)
                }

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    statusLabel

                    Spacer(minLength: 8)

                    Button("Save") {
                        saveAPIBase()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .font(.caption)
            }
        }
        .onAppear {
            apiBaseOption = settings.apiBaseOption
            customAPIBaseInput = settings.customAPIBase
        }
    }

    @ViewBuilder
    private var statusLabel: some View {
        if let error {
            Label(error, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
        } else if showSaved {
            Label("API Base saved. New quota requests will use this endpoint.", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        } else {
            Label("The subscription API path is added automatically.", systemImage: "info.circle")
                .foregroundStyle(.secondary)
        }
    }

    private func saveAPIBase() {
        let baseURLString: String
        switch apiBaseOption {
        case .zenmuxAI:
            baseURLString = AppConstants.API.zenmuxAIBaseURLString
        case .zenmuxDev:
            baseURLString = AppConstants.API.zenmuxDevBaseURLString
        case .custom:
            baseURLString = customAPIBaseInput.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard AppConstants.API.subscriptionDetailURL(baseURLString: baseURLString) != nil else {
            error = "Enter a valid http:// or https:// base URL."
            showSaved = false
            return
        }

        settings.apiBaseOption = apiBaseOption
        if apiBaseOption == .custom {
            settings.customAPIBase = baseURLString
        }
        error = nil
        showSaved = true
        onSave()
    }
}
