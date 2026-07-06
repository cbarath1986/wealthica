import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Whether Apple Intelligence's on-device model can be used for free-text
/// mood search on this device/OS/Xcode combination, and why not if it
/// can't. Every other file reasons about this plain enum only — `#if
/// canImport(FoundationModels)` is confined to this file and
/// `AIMoodQueryService`, so a build without the Foundation Models SDK (or a
/// device that just isn't Apple Intelligence-eligible) simply reports
/// `.unavailable` here and every other feature in the app is unaffected.
enum AIMoodAvailability: Equatable {
    case available
    case unavailable(reason: String)

    var isAvailable: Bool {
        if case .available = self { return true }
        return false
    }

    @MainActor
    static var current: AIMoodAvailability {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return .available
            case .unavailable(.deviceNotEligible):
                return .unavailable(reason: "This device doesn't support Apple Intelligence.")
            case .unavailable(.appleIntelligenceNotEnabled):
                return .unavailable(reason: "Turn on Apple Intelligence in Settings to use AI mood search.")
            case .unavailable(.modelNotReady):
                return .unavailable(reason: "Apple Intelligence's model is still downloading. Try again shortly.")
            case .unavailable:
                return .unavailable(reason: "Apple Intelligence isn't available right now.")
            @unknown default:
                return .unavailable(reason: "Apple Intelligence isn't available right now.")
            }
        } else {
            return .unavailable(reason: "Requires iOS 26 or later.")
        }
        #else
        return .unavailable(reason: "Not available in this build.")
        #endif
    }
}
