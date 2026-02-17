import Foundation

/// Unified HTTP client for the Poli backend API.
///
/// Centralizes request building, authentication, error handling, and
/// `remaining_actions` syncing that was previously duplicated across
/// ``AIService``, ``AuthManager``, ``HistoryManager``, and ``StoreManager``.
final class APIClient {

    // MARK: - Singleton

    static let shared = APIClient()

    // MARK: - Private

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 30
        return URLSession(configuration: config)
    }()

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {}

    // MARK: - Backend Metadata

    /// Extracts `remaining_actions` from any backend JSON response.
    private struct BackendMetadata: Decodable {
        let remaining_actions: Int?
    }

    /// Wrapper for backend error payloads.
    private struct APIErrorBody: Decodable {
        let message: String?
        let errors: [String: [String]]?
    }

    // MARK: - Public API

    /// Performs an authenticated JSON request and decodes the response.
    func request<T: Decodable>(
        method: String = "POST",
        path: String,
        body: (some Encodable)? = Optional<EmptyBody>.none,
        authenticated: Bool = true
    ) async throws -> T {
        let data = try await rawRequest(
            method: method,
            path: path,
            body: body,
            authenticated: authenticated
        )
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw PoliError.emptyResponse
        }
    }

    /// Performs an authenticated request and returns raw `Data`.
    func requestData(
        method: String = "GET",
        path: String,
        body: (some Encodable)? = Optional<EmptyBody>.none,
        authenticated: Bool = true
    ) async throws -> Data {
        try await rawRequest(
            method: method,
            path: path,
            body: body,
            authenticated: authenticated
        )
    }

    /// Performs an authenticated request using a custom decoder.
    func request<T: Decodable>(
        method: String = "POST",
        path: String,
        body: (some Encodable)? = Optional<EmptyBody>.none,
        authenticated: Bool = true,
        decoder customDecoder: JSONDecoder
    ) async throws -> T {
        let data = try await rawRequest(
            method: method,
            path: path,
            body: body,
            authenticated: authenticated
        )
        do {
            return try customDecoder.decode(T.self, from: data)
        } catch {
            throw PoliError.emptyResponse
        }
    }

    // MARK: - Private

    private func rawRequest(
        method: String,
        path: String,
        body: (some Encodable)?,
        authenticated: Bool
    ) async throws -> Data {
        let baseString = Constants.apiBaseURL.absoluteString.trimmingCharacters(
            in: CharacterSet(charactersIn: "/")
        )
        guard let url = URL(string: "\(baseString)/\(path)") else {
            throw PoliError.networkError("Invalid URL: \(path)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if authenticated {
            guard let token = KeychainHelper.shared.read(key: Constants.keychainAuthTokenKey),
                  !token.isEmpty else {
                throw PoliError.unauthorized
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            request.httpBody = try encoder.encode(body)
        }

        #if DEBUG
        print("[API] \(method) \(url.absoluteString)")
        #endif

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
            #if DEBUG
            print("[API] Response: \(String(data: data, encoding: .utf8) ?? "<binary>")")
            #endif
        } catch let urlError as URLError {
            switch urlError.code {
            case .timedOut:
                throw PoliError.networkError(String(localized: "error.network.timeout"))
            case .notConnectedToInternet, .networkConnectionLost:
                throw PoliError.networkError(String(localized: "error.network.no_connection"))
            default:
                throw PoliError.networkError(urlError.localizedDescription)
            }
        } catch {
            throw PoliError.networkError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PoliError.networkError(String(localized: "error.network.invalid_response"))
        }

        // Sync remaining actions from backend (source of truth).
        if let metadata = try? decoder.decode(BackendMetadata.self, from: data),
           let remaining = metadata.remaining_actions {
            await MainActor.run {
                UsageTracker.shared.syncFromBackend(remainingActions: remaining)
            }
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
            let errorBody = try? decoder.decode(APIErrorBody.self, from: data)
            let message: String
            if let validationErrors = errorBody?.errors {
                message = validationErrors.values.flatMap { $0 }.joined(separator: "\n")
            } else {
                message = errorBody?.message
                    ?? "Unexpected error (HTTP \(httpResponse.statusCode))."
            }
            throw PoliError.apiError(statusCode: httpResponse.statusCode, message: message)
        }
    }
}

/// Placeholder type used as the default for optional request bodies.
struct EmptyBody: Encodable {}
