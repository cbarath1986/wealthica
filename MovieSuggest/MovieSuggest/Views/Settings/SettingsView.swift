import SwiftUI

struct SettingsView: View {
    @Environment(\.tmdbClient) private var tmdbClient
    @EnvironmentObject private var settingsStore: SettingsStore

    @State private var apiKeyInput = ""
    @State private var isEditingKey = false
    @State private var isValidating = false
    @State private var validationError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("TMDB API Key") {
                    if isEditingKey {
                        SecureField("Paste your TMDB API key", text: $apiKeyInput)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        if let validationError {
                            Text(validationError).font(.caption).foregroundStyle(.red)
                        }
                        HStack {
                            Button("Cancel") { isEditingKey = false; validationError = nil }
                            Spacer()
                            Button(isValidating ? "Validating…" : "Save") { Task { await saveKey() } }
                                .disabled(apiKeyInput.isEmpty || isValidating)
                        }
                    } else {
                        HStack {
                            Text(maskedKey)
                            Spacer()
                            Button("Update") { apiKeyInput = ""; isEditingKey = true }
                        }
                        Button("Remove Key", role: .destructive) {
                            APIKeyStore.remove()
                            settingsStore.hasCompletedOnboarding = false
                        }
                    }
                }

                Section("Languages") {
                    NavigationLink {
                        LanguagePickerView(selection: $settingsStore.preferredLanguages)
                    } label: {
                        HStack {
                            Text("Preferred Languages")
                            Spacer()
                            Text(languageSummary).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                    Toggle("Only Preferred Languages", isOn: $settingsStore.strictLanguageFilter)
                }

                Section("About") {
                    LabeledContent("Version", value: "1.0")
                    Text("This product uses the TMDB API but is not endorsed or certified by TMDB.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
        }
    }

    private var maskedKey: String {
        guard let key = APIKeyStore.currentKey(), key.count > 4 else { return "Not set" }
        return "••••" + key.suffix(4)
    }

    private var languageSummary: String {
        settingsStore.preferredLanguages
            .compactMap { Language.named($0)?.englishName }
            .sorted()
            .joined(separator: ", ")
    }

    private func saveKey() async {
        isValidating = true
        validationError = nil
        defer { isValidating = false }
        do {
            try await tmdbClient.validate(apiKey: apiKeyInput)
            APIKeyStore.save(apiKeyInput)
            isEditingKey = false
        } catch let error as TMDBError {
            validationError = error.errorDescription
        } catch {
            validationError = error.localizedDescription
        }
    }
}
