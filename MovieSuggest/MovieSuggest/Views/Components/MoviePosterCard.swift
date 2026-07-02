import SwiftUI

/// Poster card used in grids and feeds (For You, Discover, "More like this").
struct MoviePosterCard: View {
    let movie: TMDBMovie
    var caption: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            AsyncImage(url: TMDBImage.poster(movie.posterPath)) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(2 / 3, contentMode: .fill)
                default:
                    ZStack {
                        Rectangle().fill(.quaternary)
                        Image(systemName: "film")
                            .foregroundStyle(.secondary)
                    }
                    .aspectRatio(2 / 3, contentMode: .fill)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Text(movie.title)
                .font(.subheadline.weight(.medium))
                .lineLimit(2)

            HStack(spacing: 4) {
                if let year = movie.releaseYear {
                    Text(year)
                }
                if let voteAverage = movie.voteAverage, voteAverage > 0 {
                    Text("·")
                    Image(systemName: "star.fill").imageScale(.small)
                    Text(String(format: "%.1f", voteAverage))
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if let caption {
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
    }
}
