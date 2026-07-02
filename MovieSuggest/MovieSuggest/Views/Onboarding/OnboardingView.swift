import SwiftUI

struct OnboardingView: View {
    @Environment(\.tmdbClient) private var tmdbClient
    @EnvironmentObject private var settingsStore: SettingsStore

    private enum Step { case apiKey, languages }

    @State private var step: Step = .apiKey
    @State private var apiKeyInput = ""
    @State private var isValidating = false
    @State private var validationError: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                switch step {
                case .apiKey: apiKeyStep
                case .languages: languageStep
                }
            }
            .padding()
            .navigationTitle("Welcome to MovieSuggest")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var apiKeyStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("MovieSuggest uses The Movie Database (TMDB) for its catalog and posters. Get a free API key, then paste it below.")
                .font(.body)

            Link("Get a free TMDB API key", destination: URL(string: "https://www.themoviedb.org/settings/api")!)
                .font(.subheadline)

            SecureField("TMDB API key", text: $apiKeyInput)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if let validationError {
                Text(validationError).font(.caption).foregroundStyle(.red)
            }

            Button {
                Task { await validateAndContinue() }
            } label: {
                if isValidating {
                    ProgressView()
                } else {
                    Text("Validate & Continue").frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(apiKeyInput.isEmpty || isValidating)

            Spacer()
        }
    }

    private var languageStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Which languages do you want movies in?")
                .font(.title3.bold())
            Text("You can change this any time in Settings.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            LanguagePickerView(selection: $settingsStore.preferredLanguages)
                .frame(maxHeight: .infinity)

            Button("Done") {
                settingsStore.hasCompletedOnboarding = true
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
        }
    }

    private func validateAndContinue() async {
        isValidating = true
        validationError = nil
        defer { isValidating = false }
        do {
            try await tmdbClient.validate(apiKey: apiKeyInput)
            APIKeyStore.save(apiKeyInput)
            step = .languages
        } catch let error as TMDBError {
            validationError = error.errorDescription
        } catch {
            validationError = error.localizedDescription
        }
    }
}
