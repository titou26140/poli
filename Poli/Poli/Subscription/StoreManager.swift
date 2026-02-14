import Combine
import Foundation
import StoreKit

/// Manages all StoreKit 2 interactions: loading products, purchasing,
/// restoring, and listening for transaction updates.
@MainActor
final class StoreManager: ObservableObject {

    // MARK: - Singleton

    static let shared = StoreManager()

    // MARK: - Product Identifiers

    enum ProductID {
        static let starterMonthly = "com.poli.starter.monthly"
        static let proMonthly = "com.poli.pro.monthly"

        static let all: [String] = [starterMonthly, proMonthly]
    }

    // MARK: - Published State

    /// Available subscription products fetched from the App Store.
    @Published var products: [Product] = []

    /// The set of product identifiers the user has currently purchased.
    @Published var purchasedProductIDs: Set<String> = []

    /// Whether a product load or purchase is in progress.
    @Published var isLoading: Bool = false

    /// Whether a backend sync is currently in progress.
    @Published var isSyncingWithBackend: Bool = false

    /// Error message from the last backend sync attempt, if any.
    @Published var backendSyncError: String?

    // MARK: - Private

    private var transactionListener: Task<Void, Never>?

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

    // MARK: - DTOs

    private struct VerifyRequest: Encodable {
        let transactionId: String
        let originalTransactionId: String
        let productId: String

        enum CodingKeys: String, CodingKey {
            case transactionId = "transaction_id"
            case originalTransactionId = "original_transaction_id"
            case productId = "product_id"
        }
    }

    private struct VerifyResponse: Decodable {
        let isPro: Bool
        let tier: String
        let plan: String
        let expiresAt: String
        let dailyLimit: Int
        let message: String
    }

    // MARK: - Init

    private init() {
        transactionListener = listenForTransactionUpdates()

        Task {
            await loadProducts()
            await updatePurchasedProducts()
            await retrySyncUnsyncedTransactions()
        }
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Load Products

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let storeProducts = try await Product.products(for: ProductID.all)
            // Sort so Starter (cheaper) appears first.
            products = storeProducts.sorted { $0.price < $1.price }
        } catch {
            print("[StoreManager] Failed to load products: \(error)")
        }
    }

    // MARK: - Purchase

    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                if let transaction = checkVerified(verification) {
                    await transaction.finish()
                    await updatePurchasedProducts()
                    await syncTransactionWithBackend(transaction)
                    return true
                }
                return false

            case .userCancelled:
                return false

            case .pending:
                return false

            @unknown default:
                return false
            }
        } catch {
            print("[StoreManager] Purchase failed: \(error)")
            return false
        }
    }

    // MARK: - Restore

    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await AppStore.sync()
            await updatePurchasedProducts()

            for await result in Transaction.currentEntitlements {
                if let transaction = checkVerified(result) {
                    await syncTransactionWithBackend(transaction)
                }
            }
        } catch {
            print("[StoreManager] Restore failed: \(error)")
        }
    }

    // MARK: - Update Purchased Products

    func updatePurchasedProducts() async {
        var purchased: Set<String> = []

        print("[StoreManager] Checking currentEntitlements...")

        for await result in Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction):
                print("[StoreManager] Found entitlement: \(transaction.productID), revocationDate: \(String(describing: transaction.revocationDate)), expirationDate: \(String(describing: transaction.expirationDate))")
                purchased.insert(transaction.productID)
            case .unverified(let transaction, let error):
                print("[StoreManager] Unverified entitlement: \(transaction.productID), error: \(error)")
            }
        }

        print("[StoreManager] Purchased products after check: \(purchased)")
        purchasedProductIDs = purchased
    }

    // MARK: - Transaction Updates

    private func listenForTransactionUpdates() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                if let transaction = await self?.checkVerified(result) {
                    await transaction.finish()
                    await self?.updatePurchasedProducts()
                    await self?.syncTransactionWithBackend(transaction)
                }
            }
        }
    }

    // MARK: - Backend Sync

    /// Sends the verified transaction to the backend for server-side activation.
    /// Retries up to 3 times with exponential backoff (1s, 2s, 4s).
    func syncTransactionWithBackend(_ transaction: Transaction) async {
        guard let token = KeychainHelper.shared.read(key: Constants.keychainAuthTokenKey),
              !token.isEmpty else {
            print("[StoreManager] No auth token — skipping backend sync")
            persistUnsyncedTransaction(
                transactionID: String(transaction.id),
                originalTransactionID: String(transaction.originalID),
                productID: transaction.productID
            )
            return
        }

        isSyncingWithBackend = true
        backendSyncError = nil
        defer { isSyncingWithBackend = false }

        let requestBody = VerifyRequest(
            transactionId: String(transaction.id),
            originalTransactionId: String(transaction.originalID),
            productId: transaction.productID
        )

        let maxRetries = 3
        var lastError: Error?

        for attempt in 0..<maxRetries {
            do {
                let url = Constants.apiBaseURL.appendingPathComponent("api/subscription/verify")
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("application/json", forHTTPHeaderField: "Accept")
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                request.httpBody = try JSONEncoder().encode(requestBody)

                print("[API] POST \(url.absoluteString)")
                let (data, response) = try await session.data(for: request)
                print("[API] Response: \(String(data: data, encoding: .utf8) ?? "<binary>")")

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw PoliError.networkError("Reponse serveur invalide.")
                }

                guard (200...299).contains(httpResponse.statusCode) else {
                    throw PoliError.apiError(
                        statusCode: httpResponse.statusCode,
                        message: "Backend verify failed (HTTP \(httpResponse.statusCode))"
                    )
                }

                let verifyResponse = try decoder.decode(VerifyResponse.self, from: data)

                let tier = SubscriptionTier.from(backendPlan: verifyResponse.tier)
                EntitlementManager.shared.updateFromBackend(
                    tier: tier,
                    remainingActions: verifyResponse.dailyLimit
                )

                removeUnsyncedTransaction(transactionID: String(transaction.id))

                print("[StoreManager] Backend sync successful: \(verifyResponse.plan)")
                return

            } catch {
                lastError = error
                print("[StoreManager] Backend sync attempt \(attempt + 1)/\(maxRetries) failed: \(error)")

                if attempt < maxRetries - 1 {
                    let delay = UInt64(pow(2.0, Double(attempt))) * 1_000_000_000
                    try? await Task.sleep(nanoseconds: delay)
                }
            }
        }

        backendSyncError = lastError?.localizedDescription ?? "Sync failed"
        persistUnsyncedTransaction(
            transactionID: String(transaction.id),
            originalTransactionID: String(transaction.originalID),
            productID: transaction.productID
        )
        print("[StoreManager] Backend sync failed after \(maxRetries) attempts, persisted for retry")
    }

    // MARK: - Unsynced Transaction Persistence

    private struct UnsyncedTransaction: Codable {
        let transactionID: String
        let originalTransactionID: String
        let productID: String
    }

    private func persistUnsyncedTransaction(transactionID: String, originalTransactionID: String, productID: String) {
        var transactions = loadUnsyncedTransactions()
        if transactions.contains(where: { $0.transactionID == transactionID }) { return }
        transactions.append(UnsyncedTransaction(
            transactionID: transactionID,
            originalTransactionID: originalTransactionID,
            productID: productID
        ))
        saveUnsyncedTransactions(transactions)
    }

    private func removeUnsyncedTransaction(transactionID: String) {
        var transactions = loadUnsyncedTransactions()
        transactions.removeAll { $0.transactionID == transactionID }
        saveUnsyncedTransactions(transactions)
    }

    private func loadUnsyncedTransactions() -> [UnsyncedTransaction] {
        guard let data = UserDefaults.standard.data(forKey: Constants.UserDefaultsKey.unsyncedTransactionIDs) else {
            return []
        }
        return (try? JSONDecoder().decode([UnsyncedTransaction].self, from: data)) ?? []
    }

    private func saveUnsyncedTransactions(_ transactions: [UnsyncedTransaction]) {
        if let data = try? JSONEncoder().encode(transactions) {
            UserDefaults.standard.set(data, forKey: Constants.UserDefaultsKey.unsyncedTransactionIDs)
        }
    }

    private func retrySyncUnsyncedTransactions() async {
        let unsynced = loadUnsyncedTransactions()
        guard !unsynced.isEmpty else { return }
        guard KeychainHelper.shared.read(key: Constants.keychainAuthTokenKey) != nil else { return }

        print("[StoreManager] Retrying \(unsynced.count) unsynced transaction(s)")

        for await result in Transaction.currentEntitlements {
            if let transaction = checkVerified(result) {
                let txID = String(transaction.id)
                if unsynced.contains(where: { $0.transactionID == txID }) {
                    await syncTransactionWithBackend(transaction)
                }
            }
        }
    }

    // MARK: - Verification Helper

    private func checkVerified(_ result: VerificationResult<Transaction>) -> Transaction? {
        switch result {
        case .unverified(_, let error):
            print("[StoreManager] Unverified transaction: \(error)")
            return nil
        case .verified(let transaction):
            return transaction
        }
    }
}
