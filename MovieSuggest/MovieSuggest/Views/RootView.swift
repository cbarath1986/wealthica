import SwiftUI

struct RootView: View {
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var genreStore: GenreStore
    @Environment(\.tmdbClient) private var tmdbClient
    @State private var hasKey = APIKeyStore.currentKey() != nil

    private var isUnlocked: Bool { hasKey && settingsStore.hasCompletedOnboarding }

    var body: some View {
        Group {
            if isUnlocked {
                TabView {
                    ForYouView(tmdbClient: tmdbClient)
                        .tabItem { Label("For You", systemImage: "sparkles") }
                    DiscoverView(tmdbClient: tmdbClient)
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
        }
        .task(id: isUnlocked) {
            // Re-runs whenever the app transitions into the signed-in state
            // (onboarding just completed, or a removed key was re-added),
            // not just once before a key exists.
            guard isUnlocked else { return }
            await genreStore.refresh(using: tmdbClient)
        }
    }
}
