import SwiftUI

struct DiscoverView: View {
    @Environment(\.tmdbClient) private var tmdbClient
    @StateObject private var viewModel: ViewModelBox = ViewModelBox()

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                if let errorMessage = viewModel.vm?.errorMessage {
                    ContentUnavailableView("Something went wrong", systemImage: "wifi.exclamationmark", description: Text(errorMessage))
                        .padding(.top, 60)
                } else {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(viewModel.vm?.results ?? []) { movie in
                            NavigationLink(value: movie.id) {
                                MoviePosterCard(movie: movie)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
                if viewModel.vm?.isLoading == true {
                    ProgressView().padding()
                }
            }
            .navigationTitle("Discover")
            .searchable(text: Binding(
                get: { viewModel.vm?.query ?? "" },
                set: { viewModel.vm?.query = $0; viewModel.vm?.queryChanged() }
            ), prompt: "Search movies")
            .navigationDestination(for: Int.self) { movieID in
                MovieDetailView(movieID: movieID)
            }
            .task {
                if viewModel.vm == nil { viewModel.vm = DiscoverViewModel(tmdbClient: tmdbClient) }
                await viewModel.vm?.loadTrendingIfNeeded()
            }
        }
    }
}

/// SwiftUI evaluates the `tmdbClient` environment value during body
/// construction, so the view model (which needs it) is created lazily
/// in `.task` rather than as a `@StateObject` initializer default.
private final class ViewModelBox: ObservableObject {
    @Published var vm: DiscoverViewModel?
}
