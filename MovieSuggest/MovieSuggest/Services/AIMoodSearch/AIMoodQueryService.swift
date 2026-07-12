import Foundation
#if canImport(FoundationModels)
import FoundationModels

/// Structured output for a free-text mood description, produced entirely
/// on-device by Apple Intelligence — nothing about the query or the
/// library ever leaves the phone.
@available(iOS 26.0, *)
@Generable
struct AIMoodQueryResult {
    @Guide(description: "3 to 6 short keywords or phrases describing the mood, tone, or themes, e.g. \"feel-good\", \"plot twist\", \"underdog\"")
    let keywords: [String]
    @Guide(description: "0 to 3 genre names that best fit, chosen ONLY from this exact list (copy the spelling exactly, or omit if nothing fits): Action, Adventure, Animation, Comedy, Crime, Documentary, Drama, Family, Fantasy, History, Horror, Music, Mystery, Romance, Science Fiction, TV Movie, Thriller, War, Western")
    let genreNames: [String]
}

@available(iOS 26.0, *)
struct AIMoodQueryService {
    /// The exact genre-name spellings this app's TMDB genre cache uses —
    /// baked into the instructions (rather than left to the model's own
    /// judgment) so `genreNames` reliably matches something in
    /// `GenreStore.genres` instead of drifting to synonyms like "Sci-Fi"
    /// that would silently fail to resolve to any genre id.
    func parseMood(_ text: String) async throws -> AIMoodQueryResult {
        let session = LanguageModelSession(instructions: """
            You translate a short free-text description of a desired movie \
            mood into structured search hints: a handful of keywords and up \
            to three broad genre names. Keep each keyword short (1-3 words). \
            Genre names must be copied exactly from the allowed list — do not \
            invent or abbreviate them.
            """)
        let response = try await session.respond(to: text, generating: AIMoodQueryResult.self)
        return response.content
    }
}
#endif
