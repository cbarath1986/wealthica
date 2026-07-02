import SwiftUI

struct RootView: View {
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var genreStore: GenreStore
    @Environment(\.tmdbClient) private var tmdbClient
    @State private var hasKey = APIKeyStore.currentKey() != nil

    var body: some View {
        Group {
            if hasKey && settingsStore.hasCompletedOnboarding {
                TabView {
                    ForYouView()
                        .tabItem { Label("For You", systemImage: "sparkles") }
                    DiscoverView()
                        .tabItem { Label("Discover", systemImage: "magnifyingglass") }
                    MyMoviesView()
                        .tabItem { Label("My Movies", systemImage: "film.stack") }
                    SettingsView()
                        .tabItem { Label("Settings", systemImage: "gearshape") }
                }
            } else {
                OnboardingView()
            }
        }
        .onChange(of: settingsStore.hasCompletedOnboarding) { _, _ in
            hasKey = APIKeyStore.currentKey() != nil
        }
        .task {
            hasKey = APIKeyStore.currentKey() != nil
            await genreStore.refresh(using: tmdbClient)
        }
    }
}
