import Foundation
import StoreKit

@available(iOS 15.0, macOS 14.0, *)
actor IapState {
    private(set) var isInitialized: Bool = false
    private var processedTransactionIds: Set<String> = []
    private var pendingTransactions: [String: Transaction] = [:]
    private var promotedProductId: String?

    // Track latest transaction date per subscription group to filter out superseded transactions
    private var latestTransactionDateByGroup: [String: Date] = [:]

    // Event listeners
    private var purchaseUpdatedListeners: [(id: UUID, listener: PurchaseUpdatedListener)] = []
    private var purchaseErrorListeners: [(id: UUID, listener: PurchaseErrorListener)] = []
    private var promotedProductListeners: [(id: UUID, listener: PromotedProductListener)] = []

    // MARK: - Init flag
    func setInitialized(_ value: Bool) { isInitialized = value }
    func reset() {
        processedTransactionIds.removeAll()
        pendingTransactions.removeAll()
        latestTransactionDateByGroup.removeAll()
        isInitialized = false
        promotedProductId = nil
    }

    // MARK: - Transactions
    func isProcessed(_ id: String) -> Bool { processedTransactionIds.contains(id) }
    func markProcessed(_ id: String) { processedTransactionIds.insert(id) }
    func unmarkProcessed(_ id: String) { processedTransactionIds.remove(id) }

    func storePending(id: String, transaction: Transaction) { pendingTransactions[id] = transaction }
    func getPending(id: String) -> Transaction? { pendingTransactions[id] }
    func removePending(id: String) { pendingTransactions.removeValue(forKey: id) }
    func pendingSnapshot() -> [Transaction] { Array(pendingTransactions.values) }

    // MARK: - Subscription Group Tracking
    func shouldProcessSubscriptionTransaction(_ transaction: Transaction) -> Bool {
        guard let groupId = transaction.subscriptionGroupID else {
            // Not a subscription, always process
            return true
        }

        let transactionDate = transaction.purchaseDate

        if let latestDate = latestTransactionDateByGroup[groupId] {
            // If this transaction is older than or equal to the latest we've seen, skip it
            if transactionDate <= latestDate {
                return false
            }
        }

        // Update latest transaction date for this group
        latestTransactionDateByGroup[groupId] = transactionDate
        return true
    }

    // MARK: - Promoted Products
    func setPromotedProductId(_ id: String?) { promotedProductId = id }
    func promotedProductIdentifier() -> String? { promotedProductId }

    // MARK: - Listeners
    func addPurchaseUpdatedListener(_ pair: (UUID, PurchaseUpdatedListener)) {
        purchaseUpdatedListeners.append((id: pair.0, listener: pair.1))
    }
    func addPurchaseErrorListener(_ pair: (UUID, PurchaseErrorListener)) {
        purchaseErrorListeners.append((id: pair.0, listener: pair.1))
    }
    func addPromotedProductListener(_ pair: (UUID, PromotedProductListener)) {
        promotedProductListeners.append((id: pair.0, listener: pair.1))
    }

    func removeListener(id: UUID, type: IapEvent) {
        switch type {
        case .purchaseUpdated:
            purchaseUpdatedListeners.removeAll { $0.id == id }
        case .purchaseError:
            purchaseErrorListeners.removeAll { $0.id == id }
        case .promotedProductIos:
            promotedProductListeners.removeAll { $0.id == id }
        case .userChoiceBillingAndroid:
            // Android-only event, no-op on iOS
            break
        @unknown default:
            break
        }
    }

    func removeAllListeners() {
        purchaseUpdatedListeners.removeAll()
        purchaseErrorListeners.removeAll()
        promotedProductListeners.removeAll()
    }

    func snapshotPurchaseUpdated() -> [PurchaseUpdatedListener] {
        purchaseUpdatedListeners.map { $0.listener }
    }
    func snapshotPurchaseError() -> [PurchaseErrorListener] {
        purchaseErrorListeners.map { $0.listener }
    }
    func snapshotPromoted() -> [PromotedProductListener] {
        promotedProductListeners.map { $0.listener }
    }
}
