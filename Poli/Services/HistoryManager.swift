import Foundation

@MainActor
final class HistoryManager {

    static let shared = HistoryManager()

    /// Custom decoder with a date format matching the Laravel backend's
    /// microsecond-precision timestamps (e.g. `2024-01-15T10:30:00.000000Z`).
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        d.dateDecodingStrategy = .formatted(formatter)
        return d
    }()

    private init() {}

    // MARK: - Response DTOs

    private struct HistoryResponse: Decodable {
        let history: [HistoryEntry]
    }

    private struct FavoriteResponse: Decodable {
        let is_favorite: Bool
    }

    // MARK: - Public API

    func fetchHistory(
        type: String? = nil,
        search: String? = nil,
        perPage: Int = 50
    ) async throws -> [HistoryEntry] {
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "per_page", value: String(perPage))
        ]
        if let type, !type.isEmpty {
            queryItems.append(URLQueryItem(name: "type", value: type))
        }
        if let search, !search.isEmpty {
            queryItems.append(URLQueryItem(name: "search", value: search))
        }

        var components = URLComponents(string: "api/history")!
        components.queryItems = queryItems

        let data = try await APIClient.shared.requestData(method: "GET", path: components.string!)
        return try decoder.decode(HistoryResponse.self, from: data).history
    }

    func toggleFavorite(type: String, id: Int) async throws -> Bool {
        let data = try await APIClient.shared.requestData(
            method: "PATCH",
            path: "api/history/\(type)/\(id)/favorite"
        )
        return try decoder.decode(FavoriteResponse.self, from: data).is_favorite
    }

    func deleteEntry(type: String, id: Int) async throws {
        _ = try await APIClient.shared.requestData(
            method: "DELETE",
            path: "api/history/\(type)/\(id)"
        )
    }
}
