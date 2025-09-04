import Foundation
import StoreKit
#if canImport(UIKit)
import UIKit
#endif

import StoreKit

// MARK: - Helper functions for ExpoModulesCore compatibility

// MARK: - Event Listeners

@available(iOS 15.0, macOS 14.0, *)
public typealias PurchaseUpdatedListener = (OpenIapPurchase) -> Void

@available(iOS 15.0, macOS 14.0, *)
public typealias PurchaseErrorListener = (PurchaseError) -> Void

@available(iOS 15.0, macOS 14.0, *)
public typealias PromotedProductListener = (String) -> Void

// MARK: - Protocol

@available(iOS 15.0, macOS 14.0, *)
public protocol OpenIapModuleProtocol {
    // Connection Management
    func initConnection() async throws -> Bool
    func endConnection() async throws -> Bool
    
    // Product Management
    func fetchProducts(_ params: ProductRequest) async throws -> [OpenIapProduct]
    func getAvailablePurchases(_ options: PurchaseOptions?) async throws -> [OpenIapPurchase]
    
    // Purchase Operations
    func requestPurchase(_ props: RequestPurchaseProps) async throws -> OpenIapPurchase
    
    // Transaction Management
    func finishTransaction(transactionIdentifier: String) async throws -> Bool
    func getPendingTransactionsIOS() async throws -> [OpenIapPurchase]
    func clearTransactionIOS() async throws
    func isTransactionVerifiedIOS(sku: String) async -> Bool
    
    // Validation
    func getReceiptDataIOS() async throws -> String?
    func getTransactionJwsIOS(sku: String) async throws -> String?
    func validateReceiptIOS(_ props: ReceiptValidationProps) async throws -> ReceiptValidationResult
    
    // Store Information
    func getStorefrontIOS() async throws -> String
    @available(iOS 16.0, macOS 14.0, *)
    func getAppTransactionIOS() async throws -> OpenIapAppTransaction?
    
    // Subscription Management
    func isEligibleForIntroOfferIOS(groupID: String) async -> Bool
    func subscriptionStatusIOS(sku: String) async throws -> [OpenIapSubscriptionStatus]?
    func currentEntitlementIOS(sku: String) async throws -> OpenIapPurchase?
    func latestTransactionIOS(sku: String) async throws -> OpenIapPurchase?
    
    // Refunds (iOS 15+)
    func beginRefundRequestIOS(sku: String) async throws -> String?
    
    // Promoted Products
    func getPromotedProductIOS() async throws -> OpenIapPromotedProduct?
    func requestPurchaseOnPromotedProductIOS() async throws
    
    // Legacy/Compatibility
    func syncIOS() async throws -> Bool
    func presentCodeRedemptionSheetIOS() async throws -> Bool
    func showManageSubscriptionsIOS() async throws -> Bool
}


// MARK: - OpenIapModule Implementation

@available(iOS 15.0, macOS 14.0, *)
@MainActor
public final class OpenIapModule: NSObject, OpenIapModuleProtocol {
    public static let shared = OpenIapModule()
    
    // Transaction management - all accessed on MainActor
    private var transactions: [String: Transaction] = [:]
    private var pendingTransactions: [String: Transaction] = [:]
    private var updateListenerTask: Task<Void, Error>?
    
    // Product caching - thread safe via actor
    private var productStore: ProductStore?
    
    // Event listeners - all accessed on MainActor
    private var purchaseUpdatedListeners: [(id: UUID, listener: PurchaseUpdatedListener)] = []
    private var purchaseErrorListeners: [(id: UUID, listener: PurchaseErrorListener)] = []
    private var promotedProductListeners: [(id: UUID, listener: PromotedProductListener)] = []
    
    // State - all accessed on MainActor
    private var isInitialized = false
    
    private override init() {
        super.init()
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - Connection Management
    
    public func initConnection() async throws -> Bool {
        // Clean up any existing state first (important for hot reload)
        cleanupExistingState()
        
        // Initialize fresh state
        self.productStore = ProductStore()
        
        // Check if IAP is available
        guard AppStore.canMakePayments else {
            let error = PurchaseError(
                code: PurchaseError.E_IAP_NOT_AVAILABLE,
                message: "In-app purchase not allowed on this device"
            )
            emitPurchaseError(error)
            self.isInitialized = false
            return false
        }
        
        // Start listening for transaction updates
        startTransactionListener()
        
        // Process any unfinished transactions
        await processUnfinishedTransactions()
        
        self.isInitialized = true
        return true
    }
    
    public func endConnection() async throws -> Bool {
        cleanupExistingState()
        return true
    }
    
    private func cleanupExistingState() {
        // Cancel any existing tasks
        updateListenerTask?.cancel()
        updateListenerTask = nil
        
        // Clear collections
        transactions.removeAll()
        
        
        // Clear product store
        if let store = productStore {
            store.removeAll()
        }
        productStore = nil
        
        isInitialized = false
    }
    
    // MARK: - Product Management
    
    /// Fetch products following OpenIAP specification
    public func fetchProducts(_ params: ProductRequest) async throws -> [OpenIapProduct] {
        // Check for empty SKU list
        guard !params.skus.isEmpty else {
            let error = PurchaseError.emptySkuList()
            emitPurchaseError(error)
            throw OpenIapError.purchaseFailed(reason: error.message)
        }
        
        try ensureConnection()
        
        let productStore = self.productStore!
        
        do {
            let fetchedProducts = try await Product.products(for: params.skus)
            fetchedProducts.forEach { product in
                productStore.addProduct(product)
            }
            let products = productStore.getAllProducts()
            var openIapProducts = await withTaskGroup(of: OpenIapProduct.self) { group in
                for product in products {
                    group.addTask {
                        await OpenIapProduct(from: product)
                    }
                }
                
                var results: [OpenIapProduct] = []
                for await result in group {
                    results.append(result)
                }
                return results
            }
            
            // Filter by type using enum
            switch params.requestType {
            case .inapp:
                openIapProducts = openIapProducts.filter { product in
                    product.productType == .inapp
                }
            case .subs:
                openIapProducts = openIapProducts.filter { product in
                    product.productType == .subs
                }
            case .all:
                // Return all products without filtering
                break
            }
            
            return openIapProducts
        } catch {
            let purchaseError = PurchaseError(
                code: PurchaseError.E_QUERY_PRODUCT,
                message: "Failed to query product details: \(error.localizedDescription)"
            )
            emitPurchaseError(purchaseError)
            throw OpenIapError.productNotFound(id: params.skus.joined(separator: ", "))
        }
    }
    
    
    
    @available(iOS 15.0, macOS 14.0, *)
    public func getAvailablePurchases(_ options: PurchaseOptions?) async throws -> [OpenIapPurchase] {
        let onlyIncludeActiveItemsIOS = options?.onlyIncludeActiveItemsIOS ?? false
        try ensureConnection()
        
        var purchasedItems: [OpenIapPurchase] = []
        
        for await verification in onlyIncludeActiveItemsIOS == true
            ? Transaction.currentEntitlements : Transaction.all
        {
            do {
                let transaction = try self.checkVerified(verification)
                if !(onlyIncludeActiveItemsIOS == true) {
                    let purchase = await OpenIapPurchase(from: transaction, jwsRepresentation: verification.jwsRepresentation)
                    purchasedItems.append(purchase)
                    continue
                }
                
                // For active items only, check if transaction is still valid
                if let expirationDate = transaction.expirationDate {
                    if expirationDate > Date() {
                        let purchase = await OpenIapPurchase(from: transaction, jwsRepresentation: verification.jwsRepresentation)
                        purchasedItems.append(purchase)
                    }
                } else {
                    // Non-subscription items (no expiration)
                    let purchase = await OpenIapPurchase(from: transaction, jwsRepresentation: verification.jwsRepresentation)
                    purchasedItems.append(purchase)
                }
            } catch {
                // Handle verification errors silently for now
                continue
            }
        }
        return purchasedItems
    }
    
    @available(iOS 15.0, macOS 14.0, *)
    public func getPurchaseHistories(alsoPublishToEventListener: Bool? = false, onlyIncludeActiveItems: Bool? = false) async throws -> [OpenIapPurchase] {
        // iOS returns all purchase history
        let options = PurchaseOptions(
            alsoPublishToEventListenerIOS: alsoPublishToEventListener,
            onlyIncludeActiveItemsIOS: false  // Always include all history
        )
        let purchases = try await getAvailablePurchases(options)
        
        return purchases
    }
    
    // MARK: - Purchase Operations
    
    @available(iOS 15.0, macOS 14.0, *)
    @available(iOS 15.0, macOS 14.0, *)
    public func requestPurchase(_ props: RequestPurchaseProps) async throws -> OpenIapPurchase {
        try ensureConnection()
        
        // Get product from cache or fetch
        var product = productStore!.getProduct(productID: props.sku)
        if product == nil {
            let products = try await Product.products(for: [props.sku])
            product = products.first
            if let product = product {
                productStore!.addProduct(product)
            }
        }
        
        guard let product = product else {
            let error = PurchaseError(
                code: PurchaseError.E_SKU_NOT_FOUND,
                message: "SKU not found: \(props.sku)",
                productId: props.sku
            )
            emitPurchaseError(error)
            throw OpenIapError.productNotFound(id: props.sku)
        }
        
        // Build purchase options using RequestPurchaseProps
        let options = Set(props.toPurchaseOptions())
        
        // Perform purchase with appropriate method based on iOS version
        let result: Product.PurchaseResult
        
        #if canImport(UIKit)
        if #available(iOS 17.0, *) {
            guard let scene = await UIApplication.shared.connectedScenes.first as? UIWindowScene else {
                throw OpenIapError.purchaseFailed(reason: "Could not find window scene")
            }
            result = try await product.purchase(confirmIn: scene, options: options)
        } else {
            result = try await product.purchase(options: options)
        }
        #else
        result = try await product.purchase(options: options)
        #endif
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            
            // Convert to OpenIapPurchase for listener and return
            let purchase = await OpenIapPurchase(from: transaction, jwsRepresentation: verification.jwsRepresentation)
            
            // Emit purchase update event
            emitPurchaseUpdate(purchase)
            
            // Store transaction if not finishing automatically
            if props.andDangerouslyFinishTransactionAutomatically == true {
                await transaction.finish()
                // Still return the transaction data even when finishing automatically
            } else {
                pendingTransactions[String(transaction.id)] = transaction
            }
            
            return purchase
            
        case .userCancelled:
            let error = PurchaseError(
                code: PurchaseError.E_USER_CANCELLED,
                message: "Purchase cancelled by user",
                productId: props.sku
            )
            emitPurchaseError(error)
            throw OpenIapError.purchaseCancelled
            
        case .pending:
            // For deferred payments, emit appropriate event
            let error = PurchaseError(
                code: PurchaseError.E_DEFERRED_PAYMENT,
                message: "Payment was deferred (pending family approval, etc.)",
                productId: props.sku
            )
            emitPurchaseError(error)
            throw OpenIapError.purchaseDeferred
            
        @unknown default:
            let error = PurchaseError(
                code: PurchaseError.E_UNKNOWN,
                message: "Unknown error occurred",
                productId: props.sku
            )
            emitPurchaseError(error)
            throw OpenIapError.unknownError
        }
    }
    
    // MARK: - Transaction Management
    
    public func finishTransaction(transactionIdentifier: String) async throws -> Bool {
        // Thread-safe read of pending transactions
        let transaction = await MainActor.run {
            pendingTransactions[transactionIdentifier]
        }
        
        // Check pending transactions first
        if let transaction = transaction {
            await transaction.finish()
            pendingTransactions.removeValue(forKey: transactionIdentifier)
            return true
        }
        
        // Otherwise search in current entitlements (more efficient than Transaction.all)
        guard let id = UInt64(transactionIdentifier) else {
            throw OpenIapError.purchaseFailed(reason: "Invalid transaction ID")
        }
        
        // Search in current entitlements first (active purchases)
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result) as Transaction
                if transaction.id == id {
                    await transaction.finish()
                    return true
                }
            } catch {
                continue
            }
        }
        
        // If not found in entitlements, search in unfinished
        for await result in Transaction.unfinished {
            do {
                let transaction = try checkVerified(result) as Transaction
                if transaction.id == id {
                    await transaction.finish()
                    return true
                }
            } catch {
                continue
            }
        }
        
        throw OpenIapError.purchaseFailed(reason: "Transaction not found")
    }
    
    @available(iOS 15.0, macOS 14.0, *)
    @available(iOS 15.0, macOS 14.0, *)
    public func getPendingTransactionsIOS() async throws -> [OpenIapPurchase] {
        var purchaseArray: [OpenIapPurchase] = []
        for (_, transaction) in pendingTransactions {
            let purchase = await OpenIapPurchase(from: transaction, jwsRepresentation: nil)
            purchaseArray.append(purchase)
        }
        return purchaseArray
    }
    
    public func clearTransactionIOS() async throws {
        // Clear all pending transactions
        for await result in Transaction.unfinished {
            do {
                let transaction = try checkVerified(result) as Transaction
                await transaction.finish()
                pendingTransactions.removeValue(forKey: String(transaction.id))
            } catch {
                continue
            }
        }
    }
    
    public func isTransactionVerifiedIOS(sku: String) async -> Bool {
        guard let product = productStore!.getProduct(productID: sku) else {
            return false
        }
        
        if let result = await product.latestTransaction {
            do {
                _ = try checkVerified(result) as Transaction
                return true
            } catch {
                return false
            }
        }
        return false
    }
    
    // MARK: - Validation
    
    public func getReceiptDataIOS() async throws -> String? {
        guard let appStoreReceiptURL = Bundle.main.appStoreReceiptURL,
              FileManager.default.fileExists(atPath: appStoreReceiptURL.path) else {
            return nil
        }
        
        let receiptData = try Data(contentsOf: appStoreReceiptURL)
        return receiptData.base64EncodedString(options: [])
    }
    
    public func getTransactionJwsIOS(sku: String) async throws -> String? {
        var product = productStore!.getProduct(productID: sku)
        if product == nil {
            product = try? await Product.products(for: [sku]).first
        }
        
        guard let product = product,
              let result = await product.latestTransaction else {
            throw OpenIapError.productNotFound(id: sku)
        }
        
        return result.jwsRepresentation
    }
    
    @available(iOS 15.0, macOS 14.0, *)
    public func validateReceiptIOS(_ props: ReceiptValidationProps) async throws -> ReceiptValidationResult {
        let receiptData = (try? await getReceiptDataIOS()) ?? ""
        
        var isValid = false
        var jwsRepresentation: String = ""
        var latestTransaction: OpenIapPurchase? = nil
        
        var product = productStore!.getProduct(productID: props.sku)
        if product == nil {
            product = try? await Product.products(for: [props.sku]).first
        }
        
        if let product = product,
           let result = await product.latestTransaction {
            jwsRepresentation = result.jwsRepresentation
            
            do {
                let transaction = try checkVerified(result) as Transaction
                isValid = true
                latestTransaction = await OpenIapPurchase(from: transaction, jwsRepresentation: result.jwsRepresentation)
            } catch {
                isValid = false
            }
        }
        
        return ReceiptValidationResult(
            isValid: isValid,
            receiptData: receiptData,
            jwsRepresentation: jwsRepresentation,
            latestTransaction: latestTransaction
        )
    }
    
    // MARK: - Store Information
    
    public func getStorefrontIOS() async throws -> String {
        if #available(iOS 13.0, *) {
            guard let storefront = await Storefront.current else {
                throw OpenIapError.unknownError
            }
            return storefront.countryCode
        } else {
            throw OpenIapError.notSupported
        }
    }
    
    @available(iOS 16.0, macOS 14.0, *)
    public func getAppTransactionIOS() async throws -> OpenIapAppTransaction? {
        if #available(iOS 16.0, *) {
            #if compiler(>=5.7)
            let verificationResult = try await AppTransaction.shared
            
            switch verificationResult {
            case .verified(let appTransaction):
                return OpenIapAppTransaction(from: appTransaction)
            case .unverified(_, _):
                return nil
            }
            #else
            throw OpenIapError.notSupported
            #endif
        } else {
            throw OpenIapError.notSupported
        }
    }
    
    // MARK: - Subscription Management
    
    public func getActiveSubscriptions(subscriptionIds: [String]? = nil) async throws -> [ActiveSubscription] {
        var activeSubscriptions: [ActiveSubscription] = []
        
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result) as Transaction
                
                // Filter by subscription IDs if provided
                if let ids = subscriptionIds, !ids.contains(transaction.productID) {
                    continue
                }
                
                // Check if it's a subscription and still active
                if transaction.productType == .autoRenewable {
                    let isActive = transaction.expirationDate.map { $0 > Date() } ?? false
                    let daysUntilExpiration = transaction.expirationDate.map { expirationDate in
                        Calendar.current.dateComponents([.day], from: Date(), to: expirationDate).day ?? 0
                    }
                    let willExpireSoon = daysUntilExpiration.map { $0 < 7 } ?? false
                    
                    var environmentValue: String? = nil
                    if #available(iOS 16.0, macOS 13.0, *) {
                        environmentValue = transaction.environment.rawValue
                    }
                    
                    let subscription = ActiveSubscription(
                        productId: transaction.productID,
                        isActive: isActive,
                        expirationDateIOS: transaction.expirationDate,
                        autoRenewingAndroid: nil,
                        environmentIOS: environmentValue,
                        willExpireSoon: willExpireSoon,
                        daysUntilExpirationIOS: daysUntilExpiration
                    )
                    
                    activeSubscriptions.append(subscription)
                }
            } catch {
                continue
            }
        }
        
        return activeSubscriptions
    }
    
    public func hasActiveSubscriptions(subscriptionIds: [String]? = nil) async throws -> Bool {
        let activeSubscriptions = try await getActiveSubscriptions(subscriptionIds: subscriptionIds)
        return activeSubscriptions.contains { $0.isActive }
    }
    
    public func deepLinkToSubscriptions() async throws {
        #if canImport(UIKit)
        if #available(iOS 15.0, *) {
            // Open subscription management in App Store
            guard let scene = await UIApplication.shared.connectedScenes.first as? UIWindowScene else {
                throw OpenIapError.unknownError
            }
            
            try await AppStore.showManageSubscriptions(in: scene)
        } else {
            // Fallback for older iOS versions
            guard let url = URL(string: "https://apps.apple.com/account/subscriptions") else {
                throw OpenIapError.unknownError
            }
            
            await UIApplication.shared.open(url, options: [:])
        }
        #else
        throw OpenIapError.notSupported
        #endif
    }
    
    
    public func subscriptionStatusIOS(sku: String) async throws -> [OpenIapSubscriptionStatus]? {
        try ensureConnection()
        
        var product = productStore!.getProduct(productID: sku)
        if product == nil {
            product = try? await Product.products(for: [sku]).first
        }
        
        guard let product = product,
              let subscription = product.subscription else {
            throw OpenIapError.productNotFound(id: sku)
        }
        
        do {
            let status = try await subscription.status
            return status.map { status in
                var renewalInfo: OpenIapRenewalInfo? = nil
                
                switch status.renewalInfo {
                case .verified(let info):
                    renewalInfo = OpenIapRenewalInfo(
                        autoRenewStatus: info.willAutoRenew,
                        autoRenewPreference: info.autoRenewPreference,
                        expirationReason: info.expirationReason?.rawValue,
                        deviceVerification: info.deviceVerification.base64EncodedString(),
                        currentProductID: info.currentProductID,
                        gracePeriodExpirationDate: info.gracePeriodExpirationDate
                    )
                case .unverified:
                    renewalInfo = nil
                }
                
                return OpenIapSubscriptionStatus(
                    state: status.state.rawValue.description,
                    renewalInfo: renewalInfo
                )
            }
        } catch {
            throw OpenIapError.storeKitError(error: error)
        }
    }
    
    @available(iOS 15.0, macOS 14.0, *)
    public func currentEntitlementIOS(sku: String) async throws -> OpenIapPurchase? {
        try ensureConnection()
        
        var product = productStore!.getProduct(productID: sku)
        if product == nil {
            product = try? await Product.products(for: [sku]).first
        }
        
        guard let product = product else {
            throw OpenIapError.productNotFound(id: sku)
        }
        
        if let result = await product.currentEntitlement {
            do {
                let transaction = try checkVerified(result) as Transaction
                return await OpenIapPurchase(from: transaction, jwsRepresentation: result.jwsRepresentation)
            } catch {
                throw OpenIapError.verificationFailed(reason: error.localizedDescription)
            }
        }
        
        return nil
    }
    
    @available(iOS 15.0, macOS 14.0, *)
    public func latestTransactionIOS(sku: String) async throws -> OpenIapPurchase? {
        try ensureConnection()
        
        var product = productStore!.getProduct(productID: sku)
        if product == nil {
            product = try? await Product.products(for: [sku]).first
        }
        
        guard let product = product else {
            throw OpenIapError.productNotFound(id: sku)
        }
        
        if let result = await product.latestTransaction {
            do {
                let transaction = try checkVerified(result) as Transaction
                return await OpenIapPurchase(from: transaction, jwsRepresentation: result.jwsRepresentation)
            } catch {
                throw OpenIapError.verificationFailed(reason: error.localizedDescription)
            }
        }
        
        return nil
    }
    
    // MARK: - Refunds (iOS 15+)
    
    public func beginRefundRequestIOS(sku: String) async throws -> String? {
        #if canImport(UIKit)
        var product = productStore?.getProduct(productID: sku)
        if product == nil {
            product = try? await Product.products(for: [sku]).first
        }
        
        guard let product = product,
              let result = await product.latestTransaction else {
            throw OpenIapError.productNotFound(id: sku)
        }
        
        do {
            let transaction = try checkVerified(result)
            
            guard let windowScene = await UIApplication.shared.connectedScenes.first as? UIWindowScene else {
                throw OpenIapError.purchaseFailed(reason: "Cannot find window scene")
            }
            
            let refundStatus = try await transaction.beginRefundRequest(in: windowScene)
            
            switch refundStatus {
            case .success:
                return "success"
            case .userCancelled:
                return "userCancelled"
            @unknown default:
                return nil
            }
        } catch {
            throw OpenIapError.purchaseFailed(reason: error.localizedDescription)
        }
        #else
        throw OpenIapError.notSupported
        #endif
    }
    
    // MARK: - Subscription Management
    
    public func isEligibleForIntroOfferIOS(groupID: String) async -> Bool {
        // Check eligibility for introductory offers
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result) as Transaction
                if transaction.subscriptionGroupID == groupID {
                    return false // Already has subscription in this group
                }
            } catch {
                continue
            }
        }
        return true
    }
    
    
    // MARK: - Promoted Products (Stubs)
    
    public func getPromotedProductIOS() async throws -> OpenIapPromotedProduct? {
        // Not implemented without Event Listeners system
        return nil
    }
    
    public func requestPurchaseOnPromotedProductIOS() async throws {
        // Not implemented without Event Listeners system
        throw OpenIapError.notSupported
    }
    
    // MARK: - Legacy/Compatibility
    
    public func syncIOS() async throws -> Bool {
        do {
            try await AppStore.sync()
            return true
        } catch {
            throw OpenIapError.storeKitError(error: error)
        }
    }
    
    public func presentCodeRedemptionSheetIOS() async throws -> Bool {
        #if canImport(UIKit)
        if #available(iOS 14.0, *) {
            await MainActor.run {
                SKPaymentQueue.default().presentCodeRedemptionSheet()
            }
            return true
        } else {
            throw OpenIapError.notSupported
        }
        #else
        throw OpenIapError.notSupported
        #endif
    }
    
    public func showManageSubscriptionsIOS() async throws -> Bool {
        #if canImport(UIKit)
        if #available(iOS 15.0, *) {
            guard let scene = await UIApplication.shared.connectedScenes.first as? UIWindowScene else {
                throw OpenIapError.unknownError
            }
            
            try await AppStore.showManageSubscriptions(in: scene)
            return true
        } else {
            // Fallback for older iOS versions
            guard let url = URL(string: "https://apps.apple.com/account/subscriptions") else {
                throw OpenIapError.unknownError
            }
            
            await UIApplication.shared.open(url, options: [:])
            return true
        }
        #else
        throw OpenIapError.notSupported
        #endif
    }
    
    
    // MARK: - Listener Management
    
    // MARK: - Private Methods
    
    private func ensureConnection() throws {
        guard isInitialized else {
            let error = PurchaseError(
                code: PurchaseError.E_INIT_CONNECTION,
                message: "Connection not initialized. Call initConnection() first."
            )
            emitPurchaseError(error)
            throw OpenIapError.purchaseFailed(reason: error.message)
        }
    }
    
    private func startTransactionListener() {
        updateListenerTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result) as Transaction
                    let transactionId = String(transaction.id)
                    
                    // Store pending transaction - already on MainActor
                    self.pendingTransactions[transactionId] = transaction
                    
                    // Emit purchase updated event for real-time updates
                    let purchase = await OpenIapPurchase(from: transaction, jwsRepresentation: result.jwsRepresentation)
                    self.emitPurchaseUpdate(purchase)
                    
                } catch {
                    // Emit purchase error when transaction verification fails
                    print("⚠️ Transaction verification failed: \(error)")
                    
                    let purchaseError: PurchaseError
                    if let openIapError = error as? OpenIapError {
                        purchaseError = PurchaseError(from: openIapError, productId: nil)
                    } else {
                        purchaseError = PurchaseError(
                            code: PurchaseError.E_TRANSACTION_VALIDATION_FAILED,
                            message: "Transaction verification failed: \(error.localizedDescription)",
                            productId: nil
                        )
                    }
                    self.emitPurchaseError(purchaseError)
                }
            }
        }
    }
    
    private func processUnfinishedTransactions() async {
        for await result in Transaction.unfinished {
            do {
                let transaction = try checkVerified(result) as Transaction
                let transactionId = String(transaction.id)
                
                // Store pending transaction - method is already on MainActor
                pendingTransactions[transactionId] = transaction
                
                // Auto-finish non-consumable transactions
                if transaction.productType == .nonConsumable || 
                   transaction.productType == .autoRenewable {
                    await transaction.finish()
                }
            } catch {
                print("⚠️ Failed to process unfinished transaction: \(error)")
                
                // Emit purchase error for unfinished transaction processing failure
                let purchaseError: PurchaseError
                if let openIapError = error as? OpenIapError {
                    purchaseError = PurchaseError(from: openIapError, productId: nil)
                } else {
                    purchaseError = PurchaseError(
                        code: PurchaseError.E_TRANSACTION_VALIDATION_FAILED,
                        message: "Failed to process unfinished transaction: \(error.localizedDescription)",
                        productId: nil
                    )
                }
                emitPurchaseError(purchaseError)
                continue
            }
        }
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw OpenIapError.verificationFailed(reason: "Transaction verification failed")
        case .verified(let safe):
            return safe
        }
    }
    
    // productToOpenIapProductData is deprecated - OpenIapProduct.init(from:) is used instead
    // This provides better type safety and includes all StoreKit 2 properties
    
    // transactionToIapTransactionData is deprecated - OpenIapPurchase.init(from:) is used instead
    // This provides better type safety and includes all StoreKit 2 properties
    
    // MARK: - Event Listeners
    
    /// Register a listener for purchase updated events
    public func purchaseUpdatedListener(_ listener: @escaping PurchaseUpdatedListener) -> Subscription {
        let subscription = Subscription(eventType: .PURCHASE_UPDATED)
        purchaseUpdatedListeners.append((id: subscription.id, listener: listener))
        return subscription
    }
    
    /// Register a listener for purchase error events
    public func purchaseErrorListener(_ listener: @escaping PurchaseErrorListener) -> Subscription {
        let subscription = Subscription(eventType: .PURCHASE_ERROR)
        purchaseErrorListeners.append((id: subscription.id, listener: listener))
        return subscription
    }
    
    /// Register a listener for promoted product events (iOS only)
    public func promotedProductListenerIOS(_ listener: @escaping PromotedProductListener) -> Subscription {
        let subscription = Subscription(eventType: .PROMOTED_PRODUCT_IOS)
        promotedProductListeners.append((id: subscription.id, listener: listener))
        return subscription
    }
    
    /// Remove a listener by subscription
    public func removeListener(_ subscription: Subscription) {
        switch subscription.eventType {
        case .PURCHASE_UPDATED:
            purchaseUpdatedListeners.removeAll { $0.id == subscription.id }
        case .PURCHASE_ERROR:
            purchaseErrorListeners.removeAll { $0.id == subscription.id }
        case .PROMOTED_PRODUCT_IOS:
            promotedProductListeners.removeAll { $0.id == subscription.id }
        }
    }
    
    /// Remove all listeners
    public func removeAllListeners() {
        purchaseUpdatedListeners.removeAll()
        purchaseErrorListeners.removeAll()
        promotedProductListeners.removeAll()
    }
    
    // MARK: - Event Emission (Private)
    
    private func emitPurchaseUpdate(_ purchase: OpenIapPurchase) {
        for (_, listener) in purchaseUpdatedListeners {
            listener(purchase)
        }
    }
    
    private func emitPurchaseError(_ error: PurchaseError) {
        for (_, listener) in purchaseErrorListeners {
            listener(error)
        }
    }
    
    private func emitPromotedProduct(_ sku: String) {
        for (_, listener) in promotedProductListeners {
            listener(sku)
        }
    }
    
}