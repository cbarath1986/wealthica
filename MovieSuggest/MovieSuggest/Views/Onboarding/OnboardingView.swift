import SwiftUI

struct OnboardingView: View {
    @Environment(\.tmdbClient) private var tmdbClient
    @EnvironmentObject private var settingsStore: SettingsStore

    private enum Step { case apiKey, languages }

    /// Builds that ship a built-in TMDB key have nothing to ask for on the
    /// key step, so onboarding starts straight at language selection.
    @State private var step: Step = DefaultAPIKey.isConfigured ? .languages : .apiKey
    @State private var apiKeyInput = ""
    @State private var isValidating = false
    @State private var validationError: String?

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .apiKey: apiKeyStep.padding()
                case .languages: languageStep
                }
            }
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
        // `LanguagePickerView` wraps a searchable List, which needs to be the
        // sole top-level content under the NavigationStack to scroll
        // correctly — sharing a VStack with sibling header/button views (as
        // this used to) left the list unable to scroll. Pinning the header
        // and button as safe-area insets instead keeps the list itself as
        // the only real content view.
        LanguagePickerView(selection: $settingsStore.preferredLanguages)
            .safeAreaInset(edge: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Which languages do you want movies in?")
                        .font(.title3.bold())
                    Text("You can change this any time in Settings.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.bar)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Button("Done") {
                    settingsStore.hasCompletedOnboarding = true
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .padding()
                .background(.bar)
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
