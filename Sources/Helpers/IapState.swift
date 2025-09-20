import Foundation
import StoreKit

@available(iOS 15.0, macOS 14.0, *)
actor IapState {
    private(set) var isInitialized: Bool = false
    private var processedTransactionIds: Set<String> = []
    private var pendingTransactions: [String: Transaction] = [:]

    // Event listeners
    private var purchaseUpdatedListeners: [(id: UUID, listener: PurchaseUpdatedListener)] = []
    private var purchaseErrorListeners: [(id: UUID, listener: PurchaseErrorListener)] = []
    private var promotedProductListeners: [(id: UUID, listener: PromotedProductListener)] = []

    // MARK: - Init flag
    func setInitialized(_ value: Bool) { isInitialized = value }
    func reset() {
        processedTransactionIds.removeAll()
        pendingTransactions.removeAll()
        isInitialized = false
    }

    // MARK: - Transactions
    func isProcessed(_ id: String) -> Bool { processedTransactionIds.contains(id) }
    func markProcessed(_ id: String) { processedTransactionIds.insert(id) }
    func unmarkProcessed(_ id: String) { processedTransactionIds.remove(id) }

    func storePending(id: String, transaction: Transaction) { pendingTransactions[id] = transaction }
    func getPending(id: String) -> Transaction? { pendingTransactions[id] }
    func removePending(id: String) { pendingTransactions.removeValue(forKey: id) }
    func pendingSnapshot() -> [Transaction] { Array(pendingTransactions.values) }

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
        default:
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
