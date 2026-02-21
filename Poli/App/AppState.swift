import Foundation

/// Observable application state shared across the app.
///
/// Holds shared text that is synchronized between the correction
/// and translation tabs in the popover.
@Observable
@MainActor
final class AppState {

    /// Shared input text for correction and translation tabs, synchronized
    /// between both. Pre-filled from selection or clipboard when the popover opens.
    var inputText: String = ""
}
