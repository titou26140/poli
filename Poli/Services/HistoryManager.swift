import Foundation

@MainActor
final class HistoryManager {

    static let shared = HistoryManager()

    private let baseURL: URL = Constants.apiBaseURL
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 30
        return URLSession(configuration: config)
    }()

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
        var components = URLComponents(url: baseURL.appendingPathComponent("api/history"), resolvingAgainstBaseURL: false)!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "per_page", value: String(perPage))
        ]
        if let type, !type.isEmpty {
            queryItems.append(URLQueryItem(name: "type", value: type))
        }
        if let search, !search.isEmpty {
            queryItems.append(URLQueryItem(name: "search", value: search))
        }
        components.queryItems = queryItems

        let data = try await performRequest(url: components.url!, method: "GET")
        let response = try decoder.decode(HistoryResponse.self, from: data)
        return response.history
    }

    func toggleFavorite(type: String, id: Int) async throws -> Bool {
        let url = baseURL.appendingPathComponent("api/history/\(type)/\(id)/favorite")
        let data = try await performRequest(url: url, method: "PATCH")
        let response = try decoder.decode(FavoriteResponse.self, from: data)
        return response.is_favorite
    }

    func deleteEntry(type: String, id: Int) async throws {
        let url = baseURL.appendingPathComponent("api/history/\(type)/\(id)")
        _ = try await performRequest(url: url, method: "DELETE")
    }

    // MARK: - Private

    private func performRequest(url: URL, method: String) async throws -> Data {
        guard let token = KeychainHelper.shared.read(key: Constants.keychainAuthTokenKey), !token.isEmpty else {
            throw PoliError.unauthorized
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        print("[API] \(method) \(url.absoluteString)")
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
            print("[API] Response: \(String(data: data, encoding: .utf8) ?? "<binary>")")
        } catch let urlError as URLError {
            switch urlError.code {
            case .timedOut:
                throw PoliError.networkError("The request timed out. Please try again.")
            case .notConnectedToInternet, .networkConnectionLost:
                throw PoliError.networkError("No internet connection.")
            default:
                throw PoliError.networkError(urlError.localizedDescription)
            }
        } catch {
            throw PoliError.networkError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PoliError.networkError("Invalid server response.")
        }

        switch httpResponse.statusCode {
        case 200...299:
            return data
        case 401:
            throw PoliError.unauthorized
        case 429:
            throw PoliError.usageLimitReached
        case 403:
            throw PoliError.notSubscribed
        default:
            let message = (try? JSONDecoder().decode([String: String].self, from: data))?["message"]
                ?? "Unexpected error (HTTP \(httpResponse.statusCode))."
            throw PoliError.apiError(statusCode: httpResponse.statusCode, message: message)
        }
    }
}
