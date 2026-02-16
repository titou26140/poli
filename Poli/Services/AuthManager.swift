import Foundation
import Combine

/// Manages user authentication state and communicates with the Poli backend
/// for login, registration, and logout operations.
///
/// Stores the authentication token in the Keychain under `"auth_token"`,
/// which is the same key used by ``AIService`` — so authenticated API calls
/// work automatically once the user signs in.
@MainActor
final class AuthManager: ObservableObject {

    // MARK: - Singleton

    static let shared = AuthManager()

    // MARK: - Published State

    @Published var isAuthenticated: Bool = false
    @Published var currentUser: User?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // MARK: - Private

    private let baseURL: URL = Constants.apiBaseURL
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        return URLSession(configuration: config)
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()
    private let encoder = JSONEncoder()

    // MARK: - DTOs

    struct User: Codable {
        let id: Int
        let name: String
        let email: String
        let isPro: Bool?
        let tier: String?
        let remainingActions: Int?
        let usageLimit: Int?
        let isLifetimeLimit: Bool?
        // No CodingKeys needed — the decoder uses .convertFromSnakeCase
        // which automatically maps remaining_actions → remainingActions, etc.
    }

    private struct LoginRequest: Encodable {
        let email: String
        let password: String
    }

    private struct RegisterRequest: Encodable {
        let name: String
        let email: String
        let password: String
        let password_confirmation: String
    }

    private struct AuthResponse: Decodable {
        let token: String
        let user: User
    }

    private struct UserResponse: Decodable {
        let user: User
    }

    private struct APIErrorBody: Decodable {
        let message: String?
        let errors: [String: [String]]?
    }

    // MARK: - Init

    private init() {
        // Do NOT read keychain here — it triggers a system prompt.
        // Call restoreSession() explicitly after onboarding is complete.
    }

    /// Restores the authentication session from the Keychain.
    /// Must be called explicitly (e.g. after onboarding) to avoid
    /// triggering a keychain prompt before the user expects it.
    func restoreSession() {
        guard !isAuthenticated else { return }
        if let token = KeychainHelper.shared.read(key: Constants.keychainAuthTokenKey), !token.isEmpty {
            isAuthenticated = true
            Task { await fetchCurrentUser() }
        }
    }

    // MARK: - Public API

    /// Authenticates the user with email and password.
    func login(email: String, password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let url = baseURL.appendingPathComponent("api/auth/login")
            let body = LoginRequest(email: email, password: password)
            let response: AuthResponse = try await performRequest(url: url, method: "POST", body: body)

            KeychainHelper.shared.save(key: Constants.keychainAuthTokenKey, value: response.token)
            currentUser = response.user
            isAuthenticated = true
            syncEntitlements(from: response.user)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// Creates a new account and authenticates the user.
    func register(name: String, email: String, password: String, passwordConfirmation: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let url = baseURL.appendingPathComponent("api/auth/register")
            let body = RegisterRequest(
                name: name,
                email: email,
                password: password,
                password_confirmation: passwordConfirmation
            )
            let response: AuthResponse = try await performRequest(url: url, method: "POST", body: body)

            KeychainHelper.shared.save(key: Constants.keychainAuthTokenKey, value: response.token)
            currentUser = response.user
            isAuthenticated = true
            syncEntitlements(from: response.user)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// Signs out the user and removes the stored token.
    func logout() async {
        isLoading = true

        // Best-effort server-side logout; ignore errors.
        if let token = KeychainHelper.shared.read(key: Constants.keychainAuthTokenKey) {
            let url = baseURL.appendingPathComponent("api/auth/logout")
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            print("[API] POST \(url.absoluteString)")
            if let (data, _) = try? await session.data(for: request) {
                print("[API] Response: \(String(data: data, encoding: .utf8) ?? "<binary>")")
            }
        }

        KeychainHelper.shared.delete(key: Constants.keychainAuthTokenKey)
        currentUser = nil
        isAuthenticated = false
        errorMessage = nil
        isLoading = false
    }

    /// Fetches the current user profile from the backend.
    func fetchCurrentUser() async {
        guard let token = KeychainHelper.shared.read(key: Constants.keychainAuthTokenKey), !token.isEmpty else {
            isAuthenticated = false
            return
        }

        do {
            let url = baseURL.appendingPathComponent("api/auth/me")
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            print("[API] GET \(url.absoluteString)")
            let (data, response) = try await session.data(for: request)
            print("[API] Response: \(String(data: data, encoding: .utf8) ?? "<binary>")")

            guard let httpResponse = response as? HTTPURLResponse else { return }

            if httpResponse.statusCode == 401 {
                // Token expired or invalid — clean up.
                KeychainHelper.shared.delete(key: Constants.keychainAuthTokenKey)
                isAuthenticated = false
                currentUser = nil
                return
            }

            guard (200...299).contains(httpResponse.statusCode) else { return }

            // Try decoding as { user: {...} } first, then as direct User object.
            if let userResponse = try? decoder.decode(UserResponse.self, from: data) {
                currentUser = userResponse.user
            } else {
                currentUser = try decoder.decode(User.self, from: data)
            }
            isAuthenticated = true

            if let user = currentUser {
                syncEntitlements(from: user)
            }
        } catch {
            // Network error during fetch — keep current auth state but don't crash.
        }
    }

    // MARK: - Private Helpers

    private func syncEntitlements(from user: User) {
        // Derive tier from the backend's "tier" field (free/starter/pro).
        let backendTier: SubscriptionTier
        if let tierString = user.tier {
            backendTier = SubscriptionTier.from(backendPlan: tierString)
        } else {
            backendTier = (user.isPro ?? false) ? .pro : .free
        }

        // Check actual StoreKit purchases (not the cached tier in EntitlementManager).
        let purchasedIDs = StoreManager.shared.purchasedProductIDs
        let storeKitTier: SubscriptionTier
        if purchasedIDs.contains(StoreManager.ProductID.proMonthly) {
            storeKitTier = .pro
        } else if purchasedIDs.contains(StoreManager.ProductID.starterMonthly) {
            storeKitTier = .starter
        } else {
            storeKitTier = .free
        }

        // Use the highest tier between StoreKit (local) and backend.
        let effectiveTier = storeKitTier.usageLimit >= backendTier.usageLimit ? storeKitTier : backendTier
        let remaining = user.remainingActions ?? effectiveTier.usageLimit
        EntitlementManager.shared.updateFromBackend(tier: effectiveTier, remainingActions: remaining)
        print("[AuthManager] syncEntitlements: backend=\(backendTier.rawValue), storeKit=\(storeKitTier.rawValue), effective=\(effectiveTier.rawValue), remaining=\(remaining)")
    }

    private func performRequest<RequestBody: Encodable, ResponseBody: Decodable>(
        url: URL,
        method: String,
        body: RequestBody
    ) async throws -> ResponseBody {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try encoder.encode(body)

        print("[API] \(method) \(url.absoluteString)")
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
            print("[API] Response: \(String(data: data, encoding: .utf8) ?? "<binary>")")
        } catch let urlError as URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                throw PoliError.networkError("Pas de connexion internet.")
            case .timedOut:
                throw PoliError.networkError("La requete a expire. Reessayez.")
            default:
                throw PoliError.networkError(urlError.localizedDescription)
            }
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PoliError.networkError("Reponse serveur invalide.")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = try? JSONDecoder().decode(APIErrorBody.self, from: data)
            let message: String
            if let validationErrors = errorBody?.errors {
                // Flatten validation errors into a single string.
                message = validationErrors.values.flatMap { $0 }.joined(separator: "\n")
            } else {
                message = errorBody?.message ?? "Erreur inattendue (HTTP \(httpResponse.statusCode))."
            }
            throw PoliError.apiError(statusCode: httpResponse.statusCode, message: message)
        }

        return try decoder.decode(ResponseBody.self, from: data)
    }
}
