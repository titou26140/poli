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

    private var sessionRestoreTask: Task<Void, Never>?

    /// AuthManager uses `.convertFromSnakeCase` for its response DTOs
    /// (e.g. `remaining_actions` -> `remainingActions`), unlike the default
    /// decoder in ``APIClient``.
    private let snakeCaseDecoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

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
        let status: String?
        let expiresAt: String?
        let cancelledAt: String?
        // No CodingKeys needed — the decoder uses .convertFromSnakeCase
        // which automatically maps remaining_actions -> remainingActions, etc.
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
        sessionRestoreTask?.cancel()
        if let token = KeychainHelper.shared.read(key: Constants.keychainAuthTokenKey), !token.isEmpty {
            isAuthenticated = true
            sessionRestoreTask = Task { await fetchCurrentUser() }
        }
    }

    // MARK: - Public API

    /// Authenticates the user with email and password.
    func login(email: String, password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let body = LoginRequest(email: email, password: password)
            let response: AuthResponse = try await APIClient.shared.request(
                path: "api/auth/login",
                body: body,
                authenticated: false,
                decoder: snakeCaseDecoder
            )

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
            let body = RegisterRequest(
                name: name,
                email: email,
                password: password,
                password_confirmation: passwordConfirmation
            )
            let response: AuthResponse = try await APIClient.shared.request(
                path: "api/auth/register",
                body: body,
                authenticated: false,
                decoder: snakeCaseDecoder
            )

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
        _ = try? await APIClient.shared.requestData(method: "POST", path: "api/auth/logout")

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
            let data = try await APIClient.shared.requestData(method: "GET", path: "api/auth/me")

            // Try decoding as { user: {...} } first, then as direct User object.
            if let userResponse = try? snakeCaseDecoder.decode(UserResponse.self, from: data) {
                currentUser = userResponse.user
            } else {
                currentUser = try snakeCaseDecoder.decode(User.self, from: data)
            }
            isAuthenticated = true

            if let user = currentUser {
                syncEntitlements(from: user)
            }
        } catch let error as PoliError {
            if case .unauthorized = error {
                // Token expired or invalid -- clean up.
                KeychainHelper.shared.delete(key: Constants.keychainAuthTokenKey)
                isAuthenticated = false
                currentUser = nil
            }
            // Other errors: keep current auth state silently.
        } catch {
            // Network error during fetch -- keep current auth state.
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

        // Parse subscription status and dates from backend.
        let subscriptionStatus = SubscriptionStatus(rawValue: user.status ?? "") ?? .none
        let expiresAt = user.expiresAt.flatMap { Self.isoFormatter.date(from: $0) }
        let cancelledAt = user.cancelledAt.flatMap { Self.isoFormatter.date(from: $0) }

        EntitlementManager.shared.updateFromBackend(
            tier: effectiveTier,
            remainingActions: remaining,
            status: subscriptionStatus,
            expiresAt: expiresAt,
            cancelledAt: cancelledAt
        )
        #if DEBUG
        print("[AuthManager] syncEntitlements: backend=\(backendTier.rawValue), storeKit=\(storeKitTier.rawValue), effective=\(effectiveTier.rawValue), remaining=\(remaining), status=\(subscriptionStatus.rawValue)")
        #endif
    }
}
