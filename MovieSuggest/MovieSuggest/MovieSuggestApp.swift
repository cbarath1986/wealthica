import SwiftUI
import SwiftData

@main
struct MovieSuggestApp: App {
    @StateObject private var settingsStore = SettingsStore()
    @StateObject private var genreStore = GenreStore()
    private let tmdbClient = TMDBClient(apiKeyProvider: { APIKeyStore.currentKey() })

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(settingsStore)
                .environmentObject(genreStore)
                .environment(\.tmdbClient, tmdbClient)
        }
        .modelContainer(for: Movie.self)
    }
}
