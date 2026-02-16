import Foundation

extension String {

    /// Returns a truncated copy of the string, appending an ellipsis if it exceeds the given limit.
    ///
    /// - Parameter maxLength: The maximum number of characters before truncation.
    /// - Returns: The original string if it fits within the limit, or a truncated version with "..." appended.
    func truncated(to maxLength: Int) -> String {
        guard count > maxLength else { return self }
        let endIndex = index(startIndex, offsetBy: maxLength)
        return String(self[startIndex..<endIndex]) + "\u{2026}"
    }

    /// Whether the string is empty or contains only whitespace and newline characters.
    var isBlank: Bool {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
