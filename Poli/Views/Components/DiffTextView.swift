import SwiftUI

// MARK: - Data Types

/// Describes whether a word was unchanged, removed, or added during correction.
enum DiffType {
    case unchanged
    case removed
    case added
}

/// A segment of text with its associated diff type.
struct DiffSegment {
    let text: String
    let type: DiffType
}

// MARK: - DiffTextView

/// Displays a visual word-level diff between an original and corrected string.
///
/// - Removed words appear in red with strikethrough.
/// - Added words appear in green with a green background tint.
/// - Unchanged words render normally.
struct DiffTextView: View {

    let original: String
    let corrected: String

    var body: some View {
        let segments = computeWordDiff(original: original, corrected: corrected)
        let attributed = buildAttributedString(from: segments)

        ScrollView {
            Text(attributed)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Attributed String Builder

    private func buildAttributedString(from segments: [DiffSegment]) -> AttributedString {
        var result = AttributedString()

        for (index, segment) in segments.enumerated() {
            var part = AttributedString(segment.text)

            switch segment.type {
            case .unchanged:
                part.foregroundColor = .primary

            case .removed:
                part.foregroundColor = Color(hex: "FF3B30")
                part.strikethroughStyle = .single
                // Strikethrough color follows foregroundColor

            case .added:
                part.foregroundColor = Color(hex: "34C759")
                part.backgroundColor = Color(hex: "34C759").opacity(0.12)
            }

            result.append(part)

            // Add space between segments unless it's the last one.
            if index < segments.count - 1 {
                result.append(AttributedString(" "))
            }
        }

        return result
    }
}

// MARK: - Word-Level Diff (LCS)

/// Computes a word-level diff between two strings using a Longest Common Subsequence approach.
///
/// - Parameters:
///   - original: The original text before correction.
///   - corrected: The corrected text after correction.
/// - Returns: An array of `DiffSegment` values representing unchanged, removed, and added words.
func computeWordDiff(original: String, corrected: String) -> [DiffSegment] {
    let originalWords = original.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
    let correctedWords = corrected.split(separator: " ", omittingEmptySubsequences: true).map(String.init)

    let m = originalWords.count
    let n = correctedWords.count

    // Build LCS table.
    var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)

    for i in 1...max(m, 1) {
        guard i <= m else { break }
        for j in 1...max(n, 1) {
            guard j <= n else { break }
            if originalWords[i - 1] == correctedWords[j - 1] {
                dp[i][j] = dp[i - 1][j - 1] + 1
            } else {
                dp[i][j] = max(dp[i - 1][j], dp[i][j - 1])
            }
        }
    }

    // Backtrack to produce diff segments.
    var segments: [DiffSegment] = []
    var i = m
    var j = n

    // Collect in reverse, then reverse at the end.
    var reversed: [DiffSegment] = []

    while i > 0 || j > 0 {
        if i > 0 && j > 0 && originalWords[i - 1] == correctedWords[j - 1] {
            reversed.append(DiffSegment(text: originalWords[i - 1], type: .unchanged))
            i -= 1
            j -= 1
        } else if j > 0 && (i == 0 || dp[i][j - 1] >= dp[i - 1][j]) {
            reversed.append(DiffSegment(text: correctedWords[j - 1], type: .added))
            j -= 1
        } else if i > 0 {
            reversed.append(DiffSegment(text: originalWords[i - 1], type: .removed))
            i -= 1
        }
    }

    segments = reversed.reversed()

    // Merge consecutive segments of the same type for cleaner display.
    var merged: [DiffSegment] = []
    for segment in segments {
        if let last = merged.last, last.type == segment.type {
            merged[merged.count - 1] = DiffSegment(
                text: last.text + " " + segment.text,
                type: segment.type
            )
        } else {
            merged.append(segment)
        }
    }

    return merged
}

// MARK: - Color Hex Initializer

private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: Double
        switch hex.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255
            g = Double((int >> 8) & 0xFF) / 255
            b = Double(int & 0xFF) / 255
        default:
            r = 1; g = 1; b = 1
        }
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Preview

#Preview {
    DiffTextView(
        original: "Je suis alle a la maison hier soir",
        corrected: "Je suis alle a la maison hier soir."
    )
    .frame(width: 340, height: 200)
    .padding()
}
