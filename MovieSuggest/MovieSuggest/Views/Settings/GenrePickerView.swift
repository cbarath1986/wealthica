import SwiftUI

/// Unlike languages, an empty genre selection is valid — it means "no
/// explicit preference," so recommendations fall back to genre affinity
/// inferred from watch history alone.
struct GenrePickerView: View {
    let genres: [TMDBGenre]
    @Binding var selection: Set<Int>

    var body: some View {
        Group {
            if genres.isEmpty {
                ContentUnavailableView(
                    "Genres not loaded yet",
                    systemImage: "film",
                    description: Text("Check your connection and reopen this screen.")
                )
            } else {
                List(genres) { genre in
                    Button {
                        toggle(genre.id)
                    } label: {
                        HStack {
                            Text(genre.name).foregroundStyle(.primary)
                            Spacer()
                            if selection.contains(genre.id) {
                                Image(systemName: "checkmark").foregroundStyle(.tint)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Genres")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func toggle(_ id: Int) {
        if selection.contains(id) {
            selection.remove(id)
        } else {
            selection.insert(id)
        }
    }
}
