import Foundation

extension Date {

    /// A human-readable relative description of the date (e.g. "2 minutes ago", "yesterday").
    ///
    /// Uses `RelativeDateTimeFormatter` with a natural, non-numeric style.
    var relativeFormatted: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.dateTimeStyle = .named
        return formatter.localizedString(for: self, relativeTo: .now)
    }
}
