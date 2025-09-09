import Foundation
import StoreKit

/// Convenience store for OpenIapModule with managed listeners and state
/// Requires explicit initConnection() and endConnection() calls
@available(iOS 15.0, macOS 14.0, *)
@MainActor
public final class OpenIapStore: ObservableObject {
    
    // MARK: - Published Properties for SwiftUI
    
    @Published public private(set) var isConnected: Bool = false
    @Published public private(set) var products: [OpenIapProduct] = []
    @Published public private(set) var availablePurchases: [OpenIapPurchase] = []
    @Published public private(set) var currentPurchase: OpenIapPurchase?
    @Published public private(set) var currentPurchaseError: OpenIapError?
    @Published public private(set) var activeSubscriptions: [OpenIapActiveSubscription] = []
    @Published public private(set) var promotedProduct: String?
    
    // MARK: - UI Status Management (Proposed OpenIAP Standard)
    
    @Published public var status: IapStatus = IapStatus()
    
    // MARK: - Private Properties
    
    private let module = OpenIapModule.shared
    private var subscriptions: [Subscription] = []
    
    // MARK: - Callbacks
    
    public var onPurchaseSuccess: ((OpenIapPurchase) -> Void)?
    public var onPurchaseError: ((OpenIapError) -> Void)?
    public var onPromotedProduct: ((String) -> Void)?
    
    // MARK: - Initialization
    
    public init(
        onPurchaseSuccess: ((OpenIapPurchase) -> Void)? = nil,
        onPurchaseError: ((OpenIapError) -> Void)? = nil,
        onPromotedProduct: ((String) -> Void)? = nil
    ) {
        self.onPurchaseSuccess = onPurchaseSuccess
        self.onPurchaseError = onPurchaseError
        self.onPromotedProduct = onPromotedProduct
        
        // Setup listeners (connection must be initialized separately)
        setupListeners()
    }
    
    deinit {
        // Clean up all subscriptions
        subscriptions.removeAll()
    }
    
    // MARK: - Setup and Teardown
    
    private func setupListeners() {
        // Setup purchase updated listener
        let purchaseUpdateSub = module.purchaseUpdatedListener { [weak self] purchase in
            Task { @MainActor in
                self?.handlePurchaseUpdate(purchase)
            }
        }
        subscriptions.append(purchaseUpdateSub)
        
        // Setup purchase error listener
        let purchaseErrorSub = module.purchaseErrorListener { [weak self] error in
            Task { @MainActor in
                self?.handlePurchaseError(error)
            }
        }
        subscriptions.append(purchaseErrorSub)
        
        // Setup promoted product listener (iOS only)
        #if os(iOS)
        let promotedProductSub = module.promotedProductListenerIOS { [weak self] productId in
            Task { @MainActor in
                self?.handlePromotedProduct(productId)
            }
        }
        subscriptions.append(promotedProductSub)
        #endif
    }
    
    private func removeAllListeners() {
        for subscription in subscriptions {
            module.removeListener(subscription)
        }
        subscriptions.removeAll()
    }
    
    // MARK: - Connection Management
    
    /// Initialize connection to the App Store
    public func initConnection() async throws {
        status.loadings.initConnection = true
        defer {
            status.loadings.initConnection = false
        }
        isConnected = try await module.initConnection()
    }
    
    /// End connection to the App Store
    public func endConnection() async throws {
        _ = try await module.endConnection()
        isConnected = false
    }
    
    // MARK: - Event Handlers
    
    private func handlePurchaseUpdate(_ purchase: OpenIapPurchase) {
        currentPurchase = purchase
        currentPurchaseError = nil
        status.loadings.purchasing.remove(purchase.productId)
        
        // Store purchase result data
        let transactionDate = Date(timeIntervalSince1970: purchase.transactionDate / 1000)
        status.lastPurchaseResult = PurchaseResultData(
            productId: purchase.productId,
            transactionId: purchase.id,
            timestamp: transactionDate,
            message: "Purchase successful"
        )
        
        onPurchaseSuccess?(purchase)
        
        // Refresh purchases if it's a subscription
        if purchase.expirationDateIOS != nil {
            Task {
                await refreshPurchases()
            }
        }
    }
    
    private func handlePurchaseError(_ error: OpenIapError) {
        currentPurchase = nil
        currentPurchaseError = error
        if let productId = error.productId {
            status.loadings.purchasing.remove(productId)
        }
        
        // Store error data
        status.lastError = ErrorData(
            code: error.code,
            message: error.message,
            productId: error.productId
        )
        
        onPurchaseError?(error)
    }
    
    private func handlePromotedProduct(_ productId: String) {
        promotedProduct = productId
        onPromotedProduct?(productId)
    }
    
    // MARK: - Public Methods
    
    /// Fetch products from the store
    public func fetchProducts(skus: [String], type: OpenIapRequestProductType = .all) async throws {
        status.loadings.fetchProducts = true
        defer {
            status.loadings.fetchProducts = false
        }
        
        let request = OpenIapProductRequest(skus: skus, type: type)
        products = try await module.fetchProducts(request)
    }
    
    /// Get available purchases (restore purchases)
    public func getAvailablePurchases() async throws {
        status.loadings.restorePurchases = true
        defer {
            status.loadings.restorePurchases = false
        }
        let options = OpenIapGetAvailablePurchasesProps(
            alsoPublishToEventListenerIOS: false,
            onlyIncludeActiveItemsIOS: false
        )
        let allPurchases = try await module.getAvailablePurchases(options)
        
        // Remove duplicates only for subscriptions by keeping the most recent active subscription for each productId
        var filteredPurchases: [OpenIapPurchase] = []
        var seenSubscriptionIds: Set<String> = Set()
        
        // Sort by transaction date (most recent first) to keep the latest purchase
        let sortedPurchases = allPurchases.sorted { $0.transactionDate > $1.transactionDate }
        
        for purchase in sortedPurchases {
            // Check if this is a subscription (has expiration date or auto-renewing)
            let isSubscription = purchase.expirationDateIOS != nil || purchase.isAutoRenewing
            
            if isSubscription {
                // For subscriptions: only keep one active subscription per productId
                if !seenSubscriptionIds.contains(purchase.productId) {
                    // Check if subscription is active
                    let isActive: Bool
                    if let expiryTime = purchase.expirationDateIOS {
                        let expiryDate = Date(timeIntervalSince1970: expiryTime / 1000)
                        isActive = expiryDate > Date() || purchase.isAutoRenewing
                    } else {
                        isActive = purchase.isAutoRenewing
                    }
                    
                    if isActive {
                        filteredPurchases.append(purchase)
                        seenSubscriptionIds.insert(purchase.productId)
                    }
                }
            } else {
                // For non-subscriptions (consumables, non-consumables): keep all
                filteredPurchases.append(purchase)
            }
        }
        
        availablePurchases = filteredPurchases
    }
    
    /// Get available purchases with options (restore purchases)
    public func getAvailablePurchases(_ options: OpenIapGetAvailablePurchasesProps) async throws {
        let allPurchases = try await module.getAvailablePurchases(options)
        
        // Remove duplicates only for subscriptions by keeping the most recent active subscription for each productId
        var filteredPurchases: [OpenIapPurchase] = []
        var seenSubscriptionIds: Set<String> = Set()
        
        // Sort by transaction date (most recent first) to keep the latest purchase
        let sortedPurchases = allPurchases.sorted { $0.transactionDate > $1.transactionDate }
        
        for purchase in sortedPurchases {
            // Check if this is a subscription (has expiration date or auto-renewing)
            let isSubscription = purchase.expirationDateIOS != nil || purchase.isAutoRenewing
            
            if isSubscription {
                // For subscriptions: only keep one active subscription per productId
                if !seenSubscriptionIds.contains(purchase.productId) {
                    // Check if subscription is active
                    let isActive: Bool
                    if let expiryTime = purchase.expirationDateIOS {
                        let expiryDate = Date(timeIntervalSince1970: expiryTime / 1000)
                        isActive = expiryDate > Date() || purchase.isAutoRenewing
                    } else {
                        isActive = purchase.isAutoRenewing
                    }
                    
                    if isActive {
                        filteredPurchases.append(purchase)
                        seenSubscriptionIds.insert(purchase.productId)
                    }
                }
            } else {
                // For non-subscriptions (consumables, non-consumables): keep all
                filteredPurchases.append(purchase)
            }
        }
        
        availablePurchases = filteredPurchases
    }
    
    /// Request a purchase
    public func requestPurchase(_ params: OpenIapRequestPurchaseProps) async throws -> OpenIapPurchase {
        clearCurrentPurchase()
        clearCurrentPurchaseError()
        
        // Set processing status
        status.loadings.purchasing.insert(params.sku)
        
        defer {
            status.loadings.purchasing.remove(params.sku)
        }
        
        return try await module.requestPurchase(params)
    }
    
    /// Finish a transaction
    public func finishTransaction(purchase: OpenIapPurchase, isConsumable: Bool = false) async throws -> Bool {
        let result = try await module.finishTransaction(transactionIdentifier: purchase.id)
        
        // Clear current purchase and error if this was the current purchase
        if purchase.id == currentPurchase?.id {
            clearCurrentPurchase()
            clearCurrentPurchaseError()
        }
        
        return result
    }
    
    /// Get active subscriptions
    public func getActiveSubscriptions(subscriptionIds: [String]? = nil) async throws {
        activeSubscriptions = try await module.getActiveSubscriptions(subscriptionIds: subscriptionIds)
    }
    
    /// Check if user has active subscriptions
    public func hasActiveSubscriptions(subscriptionIds: [String]? = nil) async throws -> Bool {
        return try await module.hasActiveSubscriptions(subscriptionIds: subscriptionIds)
    }
    
    /// Refresh purchases
    /// - Parameter forceSync: when true, performs AppStore sync before fetching
    public func refreshPurchases(forceSync: Bool = false) async throws {
        if forceSync {
            status.loadings.restorePurchases = true
            defer { status.loadings.restorePurchases = false }
            _ = try await module.syncIOS()
        }
        try await getAvailablePurchases()
    }

    
    
    /// Validate a receipt
    public func validateReceipt(sku: String) async throws -> OpenIapReceiptValidationResult {
        let props = OpenIapReceiptValidationProps(sku: sku)
        return try await module.validateReceiptIOS(props)
    }
    
    /// Validate a receipt with props (iOS only)
    public func validateReceiptIOS(_ props: OpenIapReceiptValidationProps) async throws -> OpenIapReceiptValidationResult {
        return try await module.validateReceiptIOS(props)
    }
    
    /// Get promoted product (iOS only)
    public func getPromotedProductIOS() async throws -> OpenIapPromotedProduct? {
        return try await module.getPromotedProductIOS()
    }
    
    /// Request purchase on promoted product (iOS only)
    public func requestPurchaseOnPromotedProductIOS() async throws {
        try await module.requestPurchaseOnPromotedProductIOS()
    }
    
    /// Clear current purchase
    private func clearCurrentPurchase() {
        currentPurchase = nil
    }
    
    /// Clear current purchase error
    private func clearCurrentPurchaseError() {
        currentPurchaseError = nil
    }
    
    /// Present code redemption sheet (iOS only)
    public func presentCodeRedemptionSheetIOS() async throws {
        _ = try await module.presentCodeRedemptionSheetIOS()
    }
    
    /// Show manage subscriptions (iOS only)
    public func showManageSubscriptionsIOS() async throws {
        _ = try await module.showManageSubscriptionsIOS()
    }
    
    /// Deep link to subscriptions management (iOS only)
    public func deepLinkToSubscriptionsIOS() async throws {
        try await module.deepLinkToSubscriptions()
    }
    
    /// Clear pending transactions (iOS only)
    public func clearTransactionIOS() async throws {
        try await module.clearTransactionIOS()
    }
    
    /// Get pending transactions (iOS only)
    public func getPendingTransactionsIOS() async throws -> [OpenIapPurchase] {
        return try await module.getPendingTransactionsIOS()
    }
    
    /// Get receipt data (iOS only)
    public func getReceiptDataIOS() async throws -> String? {
        return try await module.getReceiptDataIOS()
    }
    
    /// Get transaction JWS (iOS only)
    public func getTransactionJwsIOS(sku: String) async throws -> String? {
        return try await module.getTransactionJwsIOS(sku: sku)
    }
    
    /// Get storefront information (iOS only)
    public func getStorefrontIOS() async throws -> String {
        return try await module.getStorefrontIOS()
    }
    
    /// Get app transaction (iOS 16.0+ only)
    @available(iOS 16.0, macOS 14.0, *)
    public func getAppTransactionIOS() async throws -> OpenIapAppTransaction? {
        return try await module.getAppTransactionIOS()
    }
    
    /// Check if eligible for intro offer (iOS only)
    public func isEligibleForIntroOfferIOS(groupID: String) async -> Bool {
        return await module.isEligibleForIntroOfferIOS(groupID: groupID)
    }
    
    /// Get subscription status (iOS only)
    public func subscriptionStatusIOS(sku: String) async throws -> [OpenIapSubscriptionStatus]? {
        return try await module.subscriptionStatusIOS(sku: sku)
    }
    
    /// Get current entitlement (iOS only)
    public func currentEntitlementIOS(sku: String) async throws -> OpenIapPurchase? {
        return try await module.currentEntitlementIOS(sku: sku)
    }
    
    /// Get latest transaction (iOS only)
    public func latestTransactionIOS(sku: String) async throws -> OpenIapPurchase? {
        return try await module.latestTransactionIOS(sku: sku)
    }
    
    /// Begin refund request (iOS only)
    public func beginRefundRequestIOS(sku: String) async throws -> String? {
        return try await module.beginRefundRequestIOS(sku: sku)
    }
    
    /// Check if transaction is verified (iOS only)
    public func isTransactionVerifiedIOS(sku: String) async -> Bool {
        return await module.isTransactionVerifiedIOS(sku: sku)
    }
    
    /// Sync with App Store (iOS only)
    public func syncIOS() async throws -> Bool {
        return try await module.syncIOS()
    }
    
    // MARK: - Private Helpers
    
    private func refreshPurchases() async {
        do {
            try await getAvailablePurchases()
        } catch {
            OpenIapLog.error("Failed to refresh purchases: \(error)")
        }
    }
}

// MARK: - SwiftUI View Extension

// MARK: - Nested UI Status Types

@available(iOS 15.0, macOS 14.0, *)
public extension OpenIapStore {
    /// Standard status management for OpenIAP (SwiftUI-facing)
    struct IapStatus {
        // MARK: - Loading States
        public var loadings: LoadingStates = LoadingStates()

        // MARK: - Data States
        public var lastPurchaseResult: PurchaseResultData?
        public var lastError: ErrorData?

        // MARK: - Operation Tracking
        public var currentOperation: IapOperation?
        public var operationHistory: [IapOperation] = []

        public init() {}

        // Check if a specific product is being purchased
        public func isPurchasing(_ productId: String) -> Bool {
            return loadings.purchasing.contains(productId)
        }

        // Check if any loading operation is in progress
        public var isLoading: Bool {
            return loadings.initConnection ||
                   loadings.fetchProducts ||
                   loadings.restorePurchases ||
                   !loadings.purchasing.isEmpty
        }

        // Add operation to history (maintains max 10 items)
        public mutating func addToHistory(_ operation: IapOperation) {
            operationHistory.insert(operation, at: 0)
            if operationHistory.count > 10 {
                operationHistory.removeLast()
            }
        }

        // Reset all states to initial values
        public mutating func reset() {
            loadings = LoadingStates()
            lastPurchaseResult = nil
            lastError = nil
            currentOperation = nil
            operationHistory.removeAll()
        }
    }

    /// Structured loading states for different IAP operations
    struct LoadingStates {
        public var initConnection: Bool = false
        public var fetchProducts: Bool = false
        public var restorePurchases: Bool = false
        public var purchasing: Set<String> = []

        public init() {}
    }

    /// Purchase result data
    struct PurchaseResultData {
        public let productId: String
        public let transactionId: String
        public let timestamp: Date
        public let message: String

        public init(
            productId: String,
            transactionId: String,
            timestamp: Date = Date(),
            message: String
        ) {
            self.productId = productId
            self.transactionId = transactionId
            self.timestamp = timestamp
            self.message = message
        }
    }

    /// Error data
    struct ErrorData {
        public let code: String
        public let message: String
        public let productId: String?
        public let timestamp: Date

        public init(
            code: String,
            message: String,
            productId: String? = nil,
            timestamp: Date = Date()
        ) {
            self.code = code
            self.message = message
            self.productId = productId
            self.timestamp = timestamp
        }
    }

    /// Represents an IAP operation for tracking
    struct IapOperation: Identifiable, Equatable {
        public let id = UUID()
        public let type: IapOperationType
        public let productId: String?
        public let timestamp: Date
        public let result: IapOperationResult?

        public init(
            type: IapOperationType,
            productId: String? = nil,
            result: IapOperationResult? = nil
        ) {
            self.type = type
            self.productId = productId
            self.timestamp = Date()
            self.result = result
        }
    }

    /// Types of IAP operations
    enum IapOperationType: String, CaseIterable {
        case initConnection = "init_connection"
        case endConnection = "end_connection"
        case fetchProducts = "fetch_products"
        case requestPurchase = "request_purchase"
        case finishTransaction = "finish_transaction"
        case restorePurchases = "restore_purchases"
        case validateReceipt = "validate_receipt"
    }

    /// Result of an IAP operation
    enum IapOperationResult: Equatable {
        case success
        case failure(String)
        case cancelled
    }
}

#if canImport(SwiftUI)
import SwiftUI

@available(iOS 15.0, macOS 14.0, *)
public struct OpenIapStoreEnvironmentKey: EnvironmentKey {
    public static let defaultValue: OpenIapStore? = nil
}

@available(iOS 15.0, macOS 14.0, *)
public extension EnvironmentValues {
    var openIapStore: OpenIapStore? {
        get { self[OpenIapStoreEnvironmentKey.self] }
        set { self[OpenIapStoreEnvironmentKey.self] = newValue }
    }
}

@available(iOS 15.0, macOS 14.0, *)
public extension View {
    /// Attach an OpenIapStore to the view hierarchy
    func withOpenIapStore(_ store: OpenIapStore) -> some View {
        self.environment(\.openIapStore, store)
    }
}
#endif
