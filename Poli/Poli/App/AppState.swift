import Foundation

/// The type of action being performed by the app.
enum ActionType: String, Sendable {
    case correction
    case translation
}

/// Observable application state shared across the app.
///
/// This class holds the current UI state for loading indicators, results, errors,
/// and the active action type. It is designed to be owned by the `AppDelegate` and
/// passed to SwiftUI views.
@Observable
@MainActor
final class AppState {

    // MARK: - Published State

    /// Whether an asynchronous operation (correction or translation) is currently in progress.
    var isLoading: Bool = false

    /// The most recent result text from a correction or translation, if any.
    var lastResult: String?

    /// A human-readable description of the most recent error, if any.
    var lastError: String?

    /// The type of action currently being performed, or `nil` when idle.
    var currentAction: ActionType?

    /// Shared input text for correction and translation tabs, synchronized
    /// between both. Pre-filled from selection or clipboard when the popover opens.
    var inputText: String = ""

    // MARK: - State Updates

    /// Marks the beginning of an asynchronous action.
    ///
    /// - Parameter action: The type of action being started.
    func startAction(_ action: ActionType) {
        isLoading = true
        currentAction = action
        lastError = nil
        lastResult = nil
    }

    /// Records the successful result of an action and clears the loading state.
    ///
    /// - Parameter result: The output text from the completed action.
    func completeAction(with result: String) {
        isLoading = false
        lastResult = result
        currentAction = nil
    }

    /// Records a failed action and clears the loading state.
    ///
    /// - Parameter error: The error that caused the failure.
    func failAction(with error: Error) {
        isLoading = false
        lastError = error.localizedDescription
        currentAction = nil
    }

    /// Resets all state to the idle defaults.
    func reset() {
        isLoading = false
        lastResult = nil
        lastError = nil
        currentAction = nil
    }
}
