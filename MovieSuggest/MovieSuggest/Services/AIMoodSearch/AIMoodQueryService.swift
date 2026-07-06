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
    @Guide(description: "0 to 3 broad movie genre names that best fit, using standard names like Comedy, Drama, Thriller, Action, Horror, Romance, Science Fiction")
    let genreNames: [String]
}

@available(iOS 26.0, *)
struct AIMoodQueryService {
    func parseMood(_ text: String) async throws -> AIMoodQueryResult {
        let session = LanguageModelSession(instructions: """
            You translate a short free-text description of a desired movie \
            mood into structured search hints: a handful of keywords and up \
            to three broad genre names. Keep each keyword short (1-3 words).
            """)
        let response = try await session.respond(to: text, generating: AIMoodQueryResult.self)
        return response.content
    }
}
#endif
