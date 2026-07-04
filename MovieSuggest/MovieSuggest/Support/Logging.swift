import Foundation
import os

/// Centralized `os.Logger` instances, one per functional area, so output is
/// filterable by category in Xcode's console or Console.app. Unlike
/// `print()`, these are visible live while running from Xcode, persist in
/// the unified logging system, and can be inspected later on the device
/// itself via Console.app (Mac) > your iPhone > this app's subsystem.
enum Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "MovieSuggest"

    static let network = Logger(subsystem: subsystem, category: "network")
    static let recommendation = Logger(subsystem: subsystem, category: "recommendation")
    static let library = Logger(subsystem: subsystem, category: "library")
    static let settings = Logger(subsystem: subsystem, category: "settings")
    static let app = Logger(subsystem: subsystem, category: "app")
}
