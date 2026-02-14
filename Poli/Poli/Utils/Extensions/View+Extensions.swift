import SwiftUI

extension View {

    /// Applies the given transform only when the condition is `true`.
    ///
    /// This is useful for conditionally adding modifiers without breaking the view builder chain.
    ///
    /// ```swift
    /// Text("Hello")
    ///     .if(isHighlighted) { view in
    ///         view.foregroundStyle(.yellow)
    ///     }
    /// ```
    ///
    /// - Parameters:
    ///   - condition: A Boolean value that determines whether the transform is applied.
    ///   - transform: A closure that takes the current view and returns a modified view.
    /// - Returns: Either the transformed view or the original view, depending on the condition.
    @ViewBuilder
    func `if`<Content: View>(
        _ condition: Bool,
        transform: (Self) -> Content
    ) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
