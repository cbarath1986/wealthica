import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.tmdbClient) private var tmdbClient
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var genreStore: GenreStore

    @State private var apiKeyInput = ""
    @State private var isEditingKey = false
    @State private var isValidating = false
    @State private var validationError: String?
    /// Mirrored into state (rather than read from the Keychain in a
    /// computed property) so removing/saving a key re-renders the section —
    /// a Keychain change alone is invisible to SwiftUI.
    @State private var hasPersonalKey = APIKeyStore.personalKey() != nil

    @State private var exportURL: URL?
    @State private var isImporting = false
    @State private var backupAlertMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
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
                            Button(hasPersonalKey ? "Update" : "Use My Own Key") {
                                apiKeyInput = ""
                                isEditingKey = true
                            }
                        }
                        if hasPersonalKey {
                            Button("Remove Key", role: .destructive) {
                                APIKeyStore.remove()
                                hasPersonalKey = false
                                // With a built-in key the app keeps working
                                // (requests fall back to it); without one
                                // there's nothing left to call TMDB with, so
                                // return to onboarding.
                                if !DefaultAPIKey.isConfigured {
                                    settingsStore.hasCompletedOnboarding = false
                                }
                            }
                        }
                    }
                } header: {
                    Text("TMDB API Key")
                } footer: {
                    if DefaultAPIKey.isConfigured && !hasPersonalKey {
                        Text("This app includes a shared TMDB key so it works out of the box. Adding your own free key gives you your own rate limit.")
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

                Section("Genres") {
                    NavigationLink {
                        GenrePickerView(genres: genreStore.genres, selection: $settingsStore.preferredGenreIDs)
                    } label: {
                        HStack {
                            Text("Preferred Genres")
                            Spacer()
                            Text(genreSummary).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                    Toggle("Only Preferred Genres", isOn: $settingsStore.strictGenreFilter)
                }

                Section {
                    if aiMoodAvailability.isAvailable {
                        Toggle("AI-Powered Mood Search", isOn: $settingsStore.isAIMoodSearchEnabled)
                    } else {
                        HStack {
                            Text("AI-Powered Mood Search")
                            Spacer()
                            Text("Unavailable").foregroundStyle(.secondary)
                        }
                        .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Mood Search")
                } footer: {
                    if case .unavailable(let reason) = aiMoodAvailability {
                        Text(reason)
                    } else {
                        Text("Describe a mood in your own words and Apple Intelligence turns it into a search — entirely on-device, nothing leaves your phone. Mood tag chips work either way.")
                    }
                }

                Section("Not Interested") {
                    NavigationLink {
                        HiddenMoviesView()
                    } label: {
                        HStack {
                            Text("Hidden Movies")
                            Spacer()
                            Text("\(settingsStore.dismissedMovieIDs.count)").foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    if let exportURL {
                        ShareLink(item: exportURL) {
                            Label("Export Library", systemImage: "square.and.arrow.up")
                        }
                    } else {
                        Label("Preparing export…", systemImage: "square.and.arrow.up")
                            .foregroundStyle(.secondary)
                    }
                    Button {
                        isImporting = true
                    } label: {
                        Label("Import Library", systemImage: "square.and.arrow.down")
                    }
                } header: {
                    Text("Backup")
                } footer: {
                    Text("Your watch history, favorites, watchlist, and preferences — never your API key. Importing overwrites matching movies and replaces your language/genre/hidden preferences; it doesn't touch movies not in the backup.")
                }

                Section("About") {
                    LabeledContent("Version", value: appVersion)
                    Text("This product uses the TMDB API but is not endorsed or certified by TMDB.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .task { prepareExportFile() }
            .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
                handleImport(result)
            }
            .alert("Backup", isPresented: Binding(
                get: { backupAlertMessage != nil },
                set: { if !$0 { backupAlertMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(backupAlertMessage ?? "")
            }
        }
    }

    private var aiMoodAvailability: AIMoodAvailability { AIMoodAvailability.current }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        return build.map { "\(version) (\($0))" } ?? version
    }

    private var maskedKey: String {
        if hasPersonalKey, let key = APIKeyStore.personalKey(), key.count > 4 {
            return "••••" + key.suffix(4)
        }
        return DefaultAPIKey.isConfigured ? "Built-in key" : "Not set"
    }

    private var languageSummary: String {
        settingsStore.preferredLanguages
            .compactMap { Language.named($0)?.englishName }
            .sorted()
            .joined(separator: ", ")
    }

    private var genreSummary: String {
        guard !settingsStore.preferredGenreIDs.isEmpty else { return "Any" }
        return settingsStore.preferredGenreIDs
            .compactMap { genreStore.name(for: $0) }
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
            hasPersonalKey = true
            isEditingKey = false
        } catch let error as TMDBError {
            validationError = error.errorDescription
        } catch {
            validationError = error.localizedDescription
        }
    }

    private func prepareExportFile() {
        let movies = (try? modelContext.fetch(FetchDescriptor<Movie>())) ?? []
        guard let data = LibraryBackupService.export(movies: movies, settingsStore: settingsStore) else { return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("MovieSuggest-Backup.json")
        try? data.write(to: url, options: .atomic)
        exportURL = url
    }

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            importLibrary(from: url)
        case .failure(let error):
            backupAlertMessage = error.localizedDescription
        }
    }

    private func importLibrary(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            backupAlertMessage = "Couldn't access that file."
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }
        do {
            let data = try Data(contentsOf: url)
            let count = try LibraryBackupService.restore(from: data, context: modelContext, settingsStore: settingsStore)
            backupAlertMessage = "Restored \(count) movie(s) and your preferences."
        } catch {
            backupAlertMessage = error.localizedDescription
        }
    }
}
