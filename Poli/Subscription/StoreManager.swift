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
    private var initTask: Task<Void, Never>?

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    private let encoder = JSONEncoder()

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
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
        let usageLimit: Int
        let remainingActions: Int?
        let message: String
        let status: String?
        let cancelledAt: String?
    }

    // MARK: - Init

    private init() {
        transactionListener = listenForTransactionUpdates()

        initTask = Task {
            await loadProducts()
            await updatePurchasedProducts()
            await retrySyncUnsyncedTransactions()
        }
    }

    deinit {
        transactionListener?.cancel()
        initTask?.cancel()
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
            #if DEBUG
            print("[StoreManager] Failed to load products: \(error)")
            #endif
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
            #if DEBUG
            print("[StoreManager] Purchase failed: \(error)")
            #endif
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
            #if DEBUG
            print("[StoreManager] Restore failed: \(error)")
            #endif
        }
    }

    // MARK: - Update Purchased Products

    func updatePurchasedProducts() async {
        var purchased: Set<String> = []

        #if DEBUG
        print("[StoreManager] Checking currentEntitlements...")
        #endif

        for await result in Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction):
                #if DEBUG
                print("[StoreManager] Found entitlement: \(transaction.productID), revocationDate: \(String(describing: transaction.revocationDate)), expirationDate: \(String(describing: transaction.expirationDate))")
                #endif
                purchased.insert(transaction.productID)
            case .unverified(let transaction, let error):
                #if DEBUG
                print("[StoreManager] Unverified entitlement: \(transaction.productID), error: \(error)")
                #endif
            }
        }

        #if DEBUG
        print("[StoreManager] Purchased products after check: \(purchased)")
        #endif
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
        guard KeychainHelper.shared.read(key: Constants.keychainAuthTokenKey) != nil else {
            #if DEBUG
            print("[StoreManager] No auth token — skipping backend sync")
            #endif
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
                let verifyResponse: VerifyResponse = try await APIClient.shared.request(
                    path: "api/subscription/verify",
                    body: requestBody,
                    decoder: decoder
                )

                let tier = SubscriptionTier.from(backendPlan: verifyResponse.tier)
                let subscriptionStatus = SubscriptionStatus(rawValue: verifyResponse.status ?? "") ?? .active
                let cancelledAt = verifyResponse.cancelledAt.flatMap { Self.isoFormatter.date(from: $0) }
                let expiresAtDate = Self.isoFormatter.date(from: verifyResponse.expiresAt)

                EntitlementManager.shared.updateFromBackend(
                    tier: tier,
                    remainingActions: verifyResponse.remainingActions ?? verifyResponse.usageLimit,
                    status: subscriptionStatus,
                    expiresAt: expiresAtDate,
                    cancelledAt: cancelledAt
                )

                removeUnsyncedTransaction(transactionID: String(transaction.id))

                #if DEBUG
                print("[StoreManager] Backend sync successful: \(verifyResponse.plan)")
                #endif
                return

            } catch {
                lastError = error
                #if DEBUG
                print("[StoreManager] Backend sync attempt \(attempt + 1)/\(maxRetries) failed: \(error)")
                #endif

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
        #if DEBUG
        print("[StoreManager] Backend sync failed after \(maxRetries) attempts, persisted for retry")
        #endif
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
        return (try? decoder.decode([UnsyncedTransaction].self, from: data)) ?? []
    }

    private func saveUnsyncedTransactions(_ transactions: [UnsyncedTransaction]) {
        if let data = try? encoder.encode(transactions) {
            UserDefaults.standard.set(data, forKey: Constants.UserDefaultsKey.unsyncedTransactionIDs)
        }
    }

    private func retrySyncUnsyncedTransactions() async {
        let unsynced = loadUnsyncedTransactions()
        guard !unsynced.isEmpty else { return }
        guard KeychainHelper.shared.read(key: Constants.keychainAuthTokenKey) != nil else { return }

        #if DEBUG
        print("[StoreManager] Retrying \(unsynced.count) unsynced transaction(s)")
        #endif

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
            #if DEBUG
            print("[StoreManager] Unverified transaction: \(error)")
            #endif
            return nil
        case .verified(let transaction):
            return transaction
        }
    }
}
