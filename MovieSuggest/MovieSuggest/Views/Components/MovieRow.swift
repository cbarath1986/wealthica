import SwiftUI

/// Compact list row used in My Movies and search results.
struct MovieRow: View {
    let movie: TMDBMovie
    var isWatched = false
    var isFavorite = false

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: TMDBImage.thumbnail(movie.posterPath)) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(2 / 3, contentMode: .fill)
                default:
                    Rectangle().fill(.quaternary)
                }
            }
            .frame(width: 46, height: 69)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(movie.title)
                    .font(.body)
                    .lineLimit(2)
                if let year = movie.releaseYear {
                    Text(year)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(spacing: 4) {
                if isFavorite {
                    Image(systemName: "heart.fill").foregroundStyle(.red)
                }
                if isWatched {
                    Image(systemName: "eye.fill").foregroundStyle(.secondary)
                }
            }
            .font(.caption)
        }
    }
}
