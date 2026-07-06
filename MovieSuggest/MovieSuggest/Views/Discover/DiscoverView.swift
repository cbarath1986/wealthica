import SwiftUI

struct DiscoverView: View {
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var genreStore: GenreStore
    @StateObject private var viewModel: DiscoverViewModel
    @StateObject private var moodViewModel: MoodSearchViewModel
    @State private var aiMoodText = ""

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 12)]

    init(tmdbClient: TMDBClient) {
        _viewModel = StateObject(wrappedValue: DiscoverViewModel(tmdbClient: tmdbClient))
        _moodViewModel = StateObject(wrappedValue: MoodSearchViewModel(tmdbClient: tmdbClient))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    moodSection

                    if moodViewModel.isActive {
                        moodResultsSection
                    } else {
                        searchResultsSection
                    }
                }
                .padding(.vertical, 12)
            }
            .navigationTitle("Discover")
            .searchable(text: $viewModel.query, prompt: "Search movies")
            .onChange(of: viewModel.query) { _, _ in
                if !viewModel.query.isEmpty { moodViewModel.clear() }
                viewModel.queryChanged(dismissedMovieIDs: settingsStore.dismissedMovieIDs)
            }
            .navigationDestination(for: Int.self) { movieID in
                MovieDetailView(movieID: movieID)
            }
            .task { await viewModel.loadTrendingIfNeeded(dismissedMovieIDs: settingsStore.dismissedMovieIDs) }
        }
    }

    // MARK: - Moods

    private var moodSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            aiMoodField

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(MoodTag.all) { mood in
                        moodChip(mood)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func moodChip(_ mood: MoodTag) -> some View {
        let isSelected = moodViewModel.selectedMood == mood
        return Button {
            if isSelected {
                moodViewModel.clear()
            } else {
                moodViewModel.select(mood, preferredLanguages: settingsStore.preferredLanguages, dismissedMovieIDs: settingsStore.dismissedMovieIDs)
            }
        } label: {
            Label(mood.title, systemImage: mood.icon)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? Color.accentColor : Color(uiColor: .secondarySystemBackground))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var aiMoodField: some View {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), settingsStore.isAIMoodSearchEnabled, AIMoodAvailability.current.isAvailable {
            HStack {
                TextField("Describe a mood… (e.g. \"something to cheer me up\")", text: $aiMoodText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { submitAIMood() }
                Button {
                    submitAIMood()
                } label: {
                    Image(systemName: "sparkles")
                }
                .disabled(aiMoodText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || moodViewModel.isLoading)
            }
            .padding(.horizontal)
        }
        #endif
    }

    private func submitAIMood() {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, *) else { return }
        let text = aiMoodText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        moodViewModel.searchFreeText(
            text,
            genreStore: genreStore,
            preferredLanguages: settingsStore.preferredLanguages,
            dismissedMovieIDs: settingsStore.dismissedMovieIDs
        )
        #endif
    }

    private var moodResultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(moodResultsTitle).font(.headline)
                Spacer()
                Button("Clear") { moodViewModel.clear() }
            }
            .padding(.horizontal)

            if let errorMessage = moodViewModel.errorMessage {
                ContentUnavailableView("No results", systemImage: "questionmark.circle", description: Text(errorMessage))
                    .padding(.top, 40)
            } else {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(moodViewModel.results) { movie in
                        NavigationLink(value: movie.id) {
                            MoviePosterCard(movie: movie, onNotInterested: {
                                settingsStore.dismiss(movie.id)
                                moodViewModel.removeDismissed(movie.id)
                            })
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }

            if moodViewModel.isLoading {
                ProgressView().frame(maxWidth: .infinity).padding()
            }
        }
    }

    private var moodResultsTitle: String {
        if let mood = moodViewModel.selectedMood { return mood.title }
        if let text = moodViewModel.aiQueryText { return "\"\(text)\"" }
        return "Mood Search"
    }

    // MARK: - Regular search / trending

    private var searchResultsSection: some View {
        VStack {
            if let errorMessage = viewModel.errorMessage {
                ContentUnavailableView("Something went wrong", systemImage: "wifi.exclamationmark", description: Text(errorMessage))
                    .padding(.top, 60)
            } else {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(viewModel.results) { movie in
                        NavigationLink(value: movie.id) {
                            MoviePosterCard(movie: movie, onNotInterested: {
                                settingsStore.dismiss(movie.id)
                                viewModel.queryChanged(dismissedMovieIDs: settingsStore.dismissedMovieIDs)
                            })
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
            if viewModel.isLoading {
                ProgressView().padding()
            }
        }
    }
}
