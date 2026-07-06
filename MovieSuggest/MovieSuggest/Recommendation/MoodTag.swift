import Foundation

/// A curated "mood" a user can tap to browse movies matching a feeling
/// rather than a genre. TMDB keyword ids aren't documented or stable, so
/// each mood carries human-readable keyword names, resolved to ids at
/// runtime by `MoodKeywordResolver`.
struct MoodTag: Identifiable, Hashable {
    let id: String
    let title: String
    let icon: String
    let keywordNames: [String]

    static let all: [MoodTag] = [
        MoodTag(id: "feelgood", title: "Feel-Good", icon: "sun.max.fill", keywordNames: ["feel-good", "uplifting"]),
        MoodTag(id: "mindbending", title: "Mind-Bending", icon: "brain.head.profile", keywordNames: ["mind bending", "plot twist"]),
        MoodTag(id: "tearjerker", title: "Tearjerker", icon: "cloud.rain.fill", keywordNames: ["tearjerker", "emotional"]),
        MoodTag(id: "edgeofseat", title: "Edge of Your Seat", icon: "bolt.fill", keywordNames: ["suspense", "nail-biting"]),
        MoodTag(id: "cozy", title: "Cozy Night In", icon: "house.fill", keywordNames: ["cozy", "slice of life"]),
        MoodTag(id: "truestory", title: "Based on a True Story", icon: "checkmark.seal.fill", keywordNames: ["based on true story", "biography"]),
        MoodTag(id: "underdog", title: "Underdog Story", icon: "figure.run", keywordNames: ["underdog", "sports"]),
        MoodTag(id: "family", title: "Family Movie Night", icon: "figure.2.and.child.holdinghands", keywordNames: ["family", "family relationships"]),
        MoodTag(id: "darkcomedy", title: "Dark Comedy", icon: "theatermasks.fill", keywordNames: ["dark comedy", "black comedy"]),
        MoodTag(id: "epicadventure", title: "Epic Adventure", icon: "map.fill", keywordNames: ["epic", "adventure"]),
    ]
}
