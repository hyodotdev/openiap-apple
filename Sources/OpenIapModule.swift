import Foundation
import StoreKit
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Helper functions for ExpoModulesCore compatibility


// MARK: - OpenIapModule Implementation

@available(iOS 15.0, macOS 14.0, *)
@MainActor
public final class OpenIapModule: NSObject, OpenIapModuleProtocol {
    public static let shared = OpenIapModule()
    
    // Transaction management - all accessed on MainActor
    private var transactions: [String: Transaction] = [:]
    private var pendingTransactions: [String: Transaction] = [:]
    private var processedTransactionIds: Set<String> = []  // Track already emitted transactions
    private var updateListenerTask: Task<Void, Error>?
    
    // Product caching - thread safe via actor
    private var productManager: ProductManager?
    
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
    
    /// Ensure connection is initialized before operations
    private func ensureConnection() throws {
        guard isInitialized else {
            let error = PurchaseError(
                code: PurchaseError.E_INIT_CONNECTION,
                message: "Connection not initialized. Call initConnection() first."
            )
            emitPurchaseError(error)
            throw OpenIapError.purchaseFailed(reason: error.message)
        }
        
        guard AppStore.canMakePayments else {
            let error = PurchaseError(
                code: PurchaseError.E_IAP_NOT_AVAILABLE,
                message: "In-app purchases are not available on this device"
            )
            emitPurchaseError(error)
            throw OpenIapError.paymentNotAllowed
        }
    }
    
    public func initConnection() async throws -> Bool {
        return try await initConnectionInternal()
    }
    
    private func initConnectionInternal() async throws -> Bool {
        // Clean up any existing state first (important for hot reload)
        cleanupExistingState()
        
        // Initialize fresh state
        self.productManager = ProductManager()
        
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
        return try await endConnectionInternal()
    }
    
    private func endConnectionInternal() async throws -> Bool {
        cleanupExistingState()
        return true
    }
    
    private func cleanupExistingState() {
        // Cancel any existing tasks
        updateListenerTask?.cancel()
        updateListenerTask = nil
        
        // Clear collections
        transactions.removeAll()
        
        // NOTE: DO NOT call removeAllListeners() here as it removes externally registered listeners
        // from ExpoIapModule or other consumers. Only clean up internal state.
        
        // Clear product manager
        if let manager = productManager {
            manager.removeAll()
        }
        productManager = nil
        
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
        
        let productManager = self.productManager!
        
        do {
            let fetchedProducts = try await Product.products(for: params.skus)
            fetchedProducts.forEach { product in
                productManager.addProduct(product)
            }
            let products = productManager.getAllProducts()
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
    
    // MARK: - Purchase Operations
    
    public func requestPurchase(_ props: RequestPurchaseProps) async throws -> OpenIapPurchase {
        try ensureConnection()
        
        // Get product from cache or fetch
        var product = productManager!.getProduct(productID: props.sku)
        if product == nil {
            let products = try await Product.products(for: [props.sku])
            product = products.first
            if let product = product {
                productManager!.addProduct(product)
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
            
            // Check if already processed by Transaction.updates
            let transactionId = String(transaction.id)
            
            if processedTransactionIds.contains(transactionId) {
                print("🔵 [requestPurchase] Transaction already processed by listener: \(transactionId)")
                // Don't emit duplicate event, but still handle the transaction
            } else {
                // Mark this transaction as processed to avoid duplicate events
                processedTransactionIds.insert(transactionId)
                print("🔵 [requestPurchase] Processing transaction: \(transactionId)")
                
                // Emit purchase update event
                // Note: This is necessary for consumables which don't always trigger Transaction.updates
                print("🔵 [requestPurchase] Emitting event for: \(transactionId)")
                emitPurchaseUpdate(purchase)
            }
            
            // Store transaction if not finishing automatically
            if props.andDangerouslyFinishTransactionAutomatically == true {
                await transaction.finish()
                // Still return the transaction data even when finishing automatically
            } else {
                pendingTransactions[transactionId] = transaction
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
        guard let product = productManager!.getProduct(productID: sku) else {
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
        var product = productManager!.getProduct(productID: sku)
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
        
        var product = productManager!.getProduct(productID: props.sku)
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
                        transactionId: String(transaction.id),
                        purchaseToken: result.jwsRepresentation,
                        transactionDate: transaction.purchaseDate.timeIntervalSince1970 * 1000,
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
        
        var product = productManager!.getProduct(productID: sku)
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
        
        var product = productManager!.getProduct(productID: sku)
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
        
        var product = productManager!.getProduct(productID: sku)
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
        var product = productManager?.getProduct(productID: sku)
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
    
    public func showManageSubscriptionsIOS() async throws -> [[String: Any?]] {
        #if !os(tvOS)
        #if canImport(UIKit)
        if #available(iOS 15.0, *) {
            guard let windowScene = await UIApplication.shared.connectedScenes.first as? UIWindowScene else {
                throw OpenIapError.unknownError
            }
            
            // Get current subscription statuses before showing UI
            var beforeStatuses: [String: Bool] = [:]
            let subscriptionSkus = await getAllSubscriptionProductIds()
            
            for sku in subscriptionSkus {
                if let product = productManager?.getProduct(productID: sku),
                   let status = try? await product.subscription?.status.first {
                    var willAutoRenew = false
                    if case .verified(let info) = status.renewalInfo {
                        willAutoRenew = info.willAutoRenew
                    }
                    beforeStatuses[sku] = willAutoRenew
                }
            }
            
            // Show the management UI
            try await AppStore.showManageSubscriptions(in: windowScene)
            
            // Wait a bit for changes to propagate
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
            
            // Check for changes and return updated subscriptions
            var updatedSubscriptions: [[String: Any?]] = []
            
            for sku in subscriptionSkus {
                if let product = productManager?.getProduct(productID: sku),
                   let status = try? await product.subscription?.status.first,
                   let result = await product.latestTransaction {
                    
                    // Check current status
                    var currentWillAutoRenew = false
                    if case .verified(let info) = status.renewalInfo {
                        currentWillAutoRenew = info.willAutoRenew
                    }
                    
                    // Check if status changed
                    let previousWillAutoRenew = beforeStatuses[sku] ?? false
                    if previousWillAutoRenew != currentWillAutoRenew {
                        // Status changed, include in result
                        do {
                            let transaction = try checkVerified(result) as Transaction
                            var purchaseMap = await serializeTransaction(transaction, jwsRepresentationIOS: result.jwsRepresentation)
                            
                            // Add renewal info
                            if case .verified(let renewalInfo) = status.renewalInfo {
                                if let renewalInfoDict = serializeRenewalInfo(renewalInfo) {
                                    purchaseMap["renewalInfo"] = renewalInfoDict
                                }
                            }
                            
                            // Add status change info
                            purchaseMap["statusChanged"] = true
                            purchaseMap["willAutoRenew"] = currentWillAutoRenew
                            
                            updatedSubscriptions.append(purchaseMap)
                        } catch {
                            // Skip if verification fails
                        }
                    }
                }
            }
            
            return updatedSubscriptions
        } else {
            // Fallback for older iOS versions
            guard let url = URL(string: "https://apps.apple.com/account/subscriptions") else {
                throw OpenIapError.unknownError
            }
            
            await UIApplication.shared.open(url, options: [:])
            return []
        }
        #else
        throw OpenIapError.notSupported
        #endif
        #else
        throw OpenIapError.notSupported
        #endif
    }
    
    
    // MARK: - Listener Management
    
    // MARK: - Private Methods
    
    private func startTransactionListener() {
        updateListenerTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result) as Transaction
                    let transactionId = String(transaction.id)
                    
                    // Skip if already processed by requestPurchase
                    if self.processedTransactionIds.contains(transactionId) {
                        print("🟡 [Transaction.updates] Skipping already processed: \(transactionId)")
                        // Remove from processed set for future updates (e.g., subscription renewals)
                        self.processedTransactionIds.remove(transactionId)
                        continue
                    }
                    
                    print("🟢 [Transaction.updates] Processing new transaction: \(transactionId)")
                    
                    // Mark as processed to prevent duplicate from requestPurchase
                    self.processedTransactionIds.insert(transactionId)
                    
                    // Store pending transaction - already on MainActor
                    self.pendingTransactions[transactionId] = transaction
                    
                    // Emit purchase updated event for real-time updates
                    let purchase = await OpenIapPurchase(from: transaction, jwsRepresentation: result.jwsRepresentation)
                    print("🟢 [Transaction.updates] Emitting event for: \(transactionId)")
                    self.emitPurchaseUpdate(purchase)
                    
                    // Clean up processed ID after a delay to allow for renewals
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                        self.processedTransactionIds.remove(transactionId)
                    }
                    
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
    
    @available(iOS 15.0, macOS 14.0, *)
    private func getAllSubscriptionProductIds() async -> [String] {
        // Get all subscription product IDs from the product store
        var subscriptionIds: [String] = []
        
        // Get all products and filter for subscriptions
        if let products = productManager?.getAllProducts() {
            for product in products {
                if product.subscription != nil {
                    subscriptionIds.append(product.id)
                }
            }
        }
        
        return subscriptionIds
    }
    
    @available(iOS 15.0, macOS 14.0, *)
    private func serializeRenewalInfo(_ renewalInfo: Product.SubscriptionInfo.RenewalInfo) -> [String: Any?]? {
        var renewalDict: [String: Any?] = [:]
        
        renewalDict["willAutoRenew"] = renewalInfo.willAutoRenew
        renewalDict["autoRenewProductId"] = renewalInfo.autoRenewPreference
        
        if let expirationReason = renewalInfo.expirationReason {
            renewalDict["expirationReason"] = "\(expirationReason)"
        }
        
        if let gracePeriodExpirationDate = renewalInfo.gracePeriodExpirationDate {
            renewalDict["gracePeriodExpirationDate"] = gracePeriodExpirationDate.timeIntervalSince1970 * 1000
        }
        
        // priceIncreaseStatus is not optional in StoreKit 2
        renewalDict["priceIncreaseStatus"] = "\(renewalInfo.priceIncreaseStatus)"
        
        return renewalDict
    }
    
    @available(iOS 15.0, macOS 14.0, *)
    private func serializeTransaction(_ transaction: Transaction, jwsRepresentationIOS: String?) async -> [String: Any?] {
        let purchase = await OpenIapPurchase(from: transaction, jwsRepresentation: jwsRepresentationIOS)
        
        var dict: [String: Any?] = [
            "id": purchase.id,
            "productId": purchase.productId,
            "transactionDate": purchase.transactionDate,
            "transactionReceipt": purchase.transactionReceipt,
            "purchaseToken": purchase.purchaseToken,
            "quantity": purchase.quantity,
            "purchaseState": purchase.purchaseState.rawValue,
            "isAutoRenewing": purchase.isAutoRenewing,
            "platform": purchase.platform
        ]
        
        // Add iOS-specific fields
        dict["quantityIOS"] = purchase.quantityIOS
        dict["originalTransactionDateIOS"] = purchase.originalTransactionDateIOS
        dict["originalTransactionIdentifierIOS"] = purchase.originalTransactionIdentifierIOS
        dict["appAccountToken"] = purchase.appAccountToken
        dict["expirationDateIOS"] = purchase.expirationDateIOS
        dict["webOrderLineItemIdIOS"] = purchase.webOrderLineItemIdIOS
        dict["environmentIOS"] = purchase.environmentIOS
        dict["storefrontCountryCodeIOS"] = purchase.storefrontCountryCodeIOS
        dict["appBundleIdIOS"] = purchase.appBundleIdIOS
        dict["productTypeIOS"] = purchase.productTypeIOS
        dict["subscriptionGroupIdIOS"] = purchase.subscriptionGroupIdIOS
        dict["isUpgradedIOS"] = purchase.isUpgradedIOS
        dict["ownershipTypeIOS"] = purchase.ownershipTypeIOS
        dict["reasonIOS"] = purchase.reasonIOS
        dict["transactionReasonIOS"] = purchase.transactionReasonIOS
        dict["revocationDateIOS"] = purchase.revocationDateIOS
        dict["revocationReasonIOS"] = purchase.revocationReasonIOS
        dict["currencyCodeIOS"] = purchase.currencyCodeIOS
        dict["countryCodeIOS"] = purchase.countryCodeIOS
        
        if let offer = purchase.offerIOS {
            dict["offerIOS"] = [
                "id": offer.id,
                "type": offer.type,
                "paymentMode": offer.paymentMode
            ]
        }
        
        return dict
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
        subscription.onRemove?() // Trigger release for auto-disconnect
    }
    
    /// Remove all listeners
    public func removeAllListeners() {
        purchaseUpdatedListeners.removeAll()
        purchaseErrorListeners.removeAll()
        promotedProductListeners.removeAll()
    }
    
    // MARK: - Event Emission (Private)
    
    private func emitPurchaseUpdate(_ purchase: OpenIapPurchase) {
        print("🔵 [OpenIapModule] emitPurchaseUpdate called with \(purchaseUpdatedListeners.count) listeners")
        for (index, (_, listener)) in purchaseUpdatedListeners.enumerated() {
            print("  • Calling listener \(index + 1)")
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
