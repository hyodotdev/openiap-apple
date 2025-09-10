import Foundation
import StoreKit
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Helper functions for ExpoModulesCore compatibility


// MARK: - OpenIapModule Implementation

@available(iOS 15.0, macOS 14.0, *)
public final class OpenIapModule: NSObject, OpenIapModuleProtocol {
    public static let shared = OpenIapModule()
    
    // Async state containers
    private var updateListenerTask: Task<Void, Error>?
    private var productManager: ProductManager?
    private let state = IapState()
    // Coalesce concurrent init attempts
    private var initTask: Task<Bool, Error>?

    // MARK: - Error helpers
    private func emitError(_ code: String, productId: String? = nil) {
        emitPurchaseError(OpenIapError.make(code: code, productId: productId))
    }
    
    private override init() {
        super.init()
    }
    
    deinit { updateListenerTask?.cancel() }
    
    
    // MARK: - Connection Management
    
    /// Ensure connection is initialized before operations
    private func ensureConnection() async throws {
        var ok = await state.isInitialized
        if !ok {
            // Coalesce with ongoing initialization
            _ = try await initConnection()
            ok = await state.isInitialized
        }
        guard ok else {
            emitError(OpenIapError.E_INIT_CONNECTION)
            throw OpenIapError.make(code: OpenIapError.E_INIT_CONNECTION)
        }
        guard AppStore.canMakePayments else {
            emitError(OpenIapError.E_IAP_NOT_AVAILABLE)
            throw OpenIapError.make(code: OpenIapError.E_IAP_NOT_AVAILABLE)
        }
    }
    
    public func initConnection() async throws -> Bool {
        if let task = initTask {
            return try await task.value
        }
        let task = Task { [weak self] () -> Bool in
            guard let self = self else { return false }
            return try await self.initConnectionInternal()
        }
        initTask = task
        do {
            let result = try await task.value
            initTask = nil
            return result
        } catch {
            initTask = nil
            throw error
        }
    }
    
    private func initConnectionInternal() async throws -> Bool {
        // Clean up any existing state first (important for hot reload)
        await cleanupExistingState()
        
        // Initialize fresh state
        self.productManager = ProductManager()
        
        // Check if IAP is available
        guard AppStore.canMakePayments else {
            emitError(OpenIapError.E_IAP_NOT_AVAILABLE)
            await state.setInitialized(false)
            return false
        }
        
        // Mark initialized before starting listeners to avoid pre-init events from causing errors
        await state.setInitialized(true)

        // Start listening for transaction updates
        startTransactionListener()
        
        // Process any unfinished transactions
        await processUnfinishedTransactions()
        return true
    }
    
    public func endConnection() async throws -> Bool {
        return try await endConnectionInternal()
    }
    
    private func endConnectionInternal() async throws -> Bool {
        // Cancel any in-flight initialization
        initTask?.cancel()
        initTask = nil
        await cleanupExistingState()
        return true
    }
    
    private func cleanupExistingState() async {
        // Cancel any existing tasks
        updateListenerTask?.cancel()
        updateListenerTask = nil
        
        // Clear collections
        await self.state.reset()
        
        // NOTE: DO NOT call removeAllListeners() here as it removes externally registered listeners
        // from ExpoIapModule or other consumers. Only clean up internal state.
        
        // Clear product manager
        if let manager = productManager { await manager.removeAll() }
        productManager = nil
    }
    
    // MARK: - Product Management
    
    /// Fetch products following OpenIAP specification
    public func fetchProducts(_ params: OpenIapProductRequest) async throws -> [OpenIapProduct] {
        OpenIapLog.debug("🔷 [OpenIapModule] fetchProducts called with skus: \(params.skus), type: \(params.requestType)")
        
        // Check for empty SKU list
        guard !params.skus.isEmpty else {
            let error = OpenIapError.emptySkuList()
            emitPurchaseError(error)
            throw error
        }
        
        try await ensureConnection()
        
        let productManager = self.productManager!
        
        do {
            OpenIapLog.debug("🔷 [OpenIapModule] Fetching products from StoreKit for SKUs: \(params.skus)")
            let fetchedProducts = try await Product.products(for: params.skus)
            OpenIapLog.debug("🔷 [OpenIapModule] StoreKit returned \(fetchedProducts.count) products")
            
            for product in fetchedProducts {
                OpenIapLog.debug("🔷 [OpenIapModule] Product from StoreKit: id=\(product.id), type=\(product.type)")
                await productManager.addProduct(product)
            }
            let products = await productManager.getAllProducts()
            OpenIapLog.debug("🔷 [OpenIapModule] ProductManager has \(products.count) total products")
            
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
            
            OpenIapLog.debug("🔷 [OpenIapModule] Created \(openIapProducts.count) OpenIapProduct objects")
            
            // Filter by type using enum
            switch params.requestType {
            case .inapp:
                OpenIapLog.debug("🔷 [OpenIapModule] Filtering for inapp products")
                openIapProducts = openIapProducts.filter { product in
                    let isInApp = product.productType == .inapp
                    OpenIapLog.debug("🔷 [OpenIapModule] Product \(product.id): productType=\(product.productType), isInApp=\(isInApp)")
                    return isInApp
                }
            case .subs:
                OpenIapLog.debug("🔷 [OpenIapModule] Filtering for subscription products")
                openIapProducts = openIapProducts.filter { product in
                    product.productType == .subs
                }
            case .all:
                OpenIapLog.debug("🔷 [OpenIapModule] Returning all products without filtering")
                // Return all products without filtering
                break
            }
            
            OpenIapLog.debug("🔷 [OpenIapModule] After filtering: \(openIapProducts.count) products")
            return openIapProducts
        } catch {
            let purchaseError = OpenIapError.make(code: OpenIapError.E_QUERY_PRODUCT)
            emitPurchaseError(purchaseError)
            throw purchaseError
        }
    }
    
    
    
    @available(iOS 15.0, macOS 14.0, *)
    public func getAvailablePurchases(_ options: OpenIapGetAvailablePurchasesProps?) async throws -> [OpenIapPurchase] {
        let onlyIncludeActiveItemsIOS = options?.onlyIncludeActiveItemsIOS ?? false
        try await ensureConnection()
        
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
    
    public func requestPurchase(_ props: OpenIapRequestPurchaseProps) async throws -> OpenIapPurchase {
        try await ensureConnection()
        
        // Get product from cache or fetch
        var product = await productManager!.getProduct(productID: props.sku)
        if product == nil {
            let products = try await Product.products(for: [props.sku])
            product = products.first
            if let product = product {
                await productManager!.addProduct(product)
            }
        }
        
        guard let product = product else {
            let error = OpenIapError.make(code: OpenIapError.E_SKU_NOT_FOUND, productId: props.sku)
            emitPurchaseError(error)
            throw error
        }
        
        // Build purchase options using RequestPurchaseProps
        let options = Set(props.toPurchaseOptions())
        
        // Perform purchase with appropriate method based on iOS version
        let result: Product.PurchaseResult
        
        #if canImport(UIKit)
        if #available(iOS 17.0, *) {
            let scene: UIWindowScene? = await MainActor.run {
                UIApplication.shared.connectedScenes.first as? UIWindowScene
            }
            guard let scene else {
                throw OpenIapError.make(code: OpenIapError.E_PURCHASE_ERROR, message: "Could not find window scene")
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
            
            if await state.isProcessed(transactionId) {
                OpenIapLog.debug("🔵 [requestPurchase] Transaction already processed by listener: \(transactionId)")
                // Don't emit duplicate event, but still handle the transaction
            } else {
                // Mark this transaction as processed to avoid duplicate events
                await state.markProcessed(transactionId)
                OpenIapLog.debug("🔵 [requestPurchase] Processing transaction: \(transactionId)")
                
                // Emit purchase update event
                // Note: This is necessary for consumables which don't always trigger Transaction.updates
                OpenIapLog.debug("🔵 [requestPurchase] Emitting event for: \(transactionId)")
                emitPurchaseUpdate(purchase)
            }
            
            // Store transaction if not finishing automatically
            if props.andDangerouslyFinishTransactionAutomatically == true {
                await transaction.finish()
                // Still return the transaction data even when finishing automatically
            } else {
                await state.storePending(id: transactionId, transaction: transaction)
            }
            
            return purchase
            
        case .userCancelled:
            let error = OpenIapError.make(code: OpenIapError.E_USER_CANCELLED, productId: props.sku)
            emitPurchaseError(error)
            throw error
            
        case .pending:
            // For deferred payments, emit appropriate event
            let error = OpenIapError.make(code: OpenIapError.E_DEFERRED_PAYMENT, productId: props.sku)
            emitPurchaseError(error)
            throw error
            
        @unknown default:
            let error = OpenIapError.make(code: OpenIapError.E_UNKNOWN, productId: props.sku)
            emitPurchaseError(error)
            throw error
        }
    }
    
    // MARK: - Transaction Management
    
    public func finishTransaction(transactionIdentifier: String) async throws -> Bool {
        // Thread-safe read of pending transactions
        let transaction: Transaction? = await state.getPending(id: transactionIdentifier)
        
        // Check pending transactions first
        if let transaction = transaction {
            await transaction.finish()
            await state.removePending(id: transactionIdentifier)
            return true
        }
        
        // Otherwise search in current entitlements (more efficient than Transaction.all)
        guard let id = UInt64(transactionIdentifier) else {
            throw OpenIapError.make(code: OpenIapError.E_PURCHASE_ERROR, message: "Invalid transaction ID")
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
        
        throw OpenIapError.make(code: OpenIapError.E_PURCHASE_ERROR, message: "Transaction not found")
    }
    
    @available(iOS 15.0, macOS 14.0, *)
    @available(iOS 15.0, macOS 14.0, *)
    public func getPendingTransactionsIOS() async throws -> [OpenIapPurchase] {
        // Snapshot pending transactions safely
        let snapshot: [Transaction] = await state.pendingSnapshot()
        var purchaseArray: [OpenIapPurchase] = []
        for transaction in snapshot {
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
                await state.removePending(id: String(transaction.id))
            } catch {
                continue
            }
        }
    }
    
    public func isTransactionVerifiedIOS(sku: String) async -> Bool {
        guard let product = await productManager!.getProduct(productID: sku) else {
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
        var product = await productManager!.getProduct(productID: sku)
        if product == nil {
            product = try? await Product.products(for: [sku]).first
        }
        
        guard let product = product,
              let result = await product.latestTransaction else {
            throw OpenIapError.make(code: OpenIapError.E_SKU_NOT_FOUND, productId: sku)
        }
        
        return result.jwsRepresentation
    }
    
    @available(iOS 15.0, macOS 14.0, *)
    public func validateReceiptIOS(_ props: OpenIapReceiptValidationProps) async throws -> OpenIapReceiptValidationResult {
        let receiptData = (try? await getReceiptDataIOS()) ?? ""
        
        var isValid = false
        var jwsRepresentation: String = ""
        var latestTransaction: OpenIapPurchase? = nil
        
        var product = await productManager!.getProduct(productID: props.sku)
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
        
        return OpenIapReceiptValidationResult(
            isValid: isValid,
            receiptData: receiptData,
            jwsRepresentation: jwsRepresentation,
            latestTransaction: latestTransaction
        )
    }
    
    // MARK: - Store Information
    
    public func getStorefrontIOS() async throws -> String {
        guard let storefront = await Storefront.current else {
            throw OpenIapError.make(code: OpenIapError.E_UNKNOWN)
        }
        return storefront.countryCode
    }
    
    @available(iOS 16.0, macOS 14.0, *)
    public func getAppTransactionIOS() async throws -> OpenIapAppTransaction? {
        #if compiler(>=5.7)
        let verificationResult = try await AppTransaction.shared
        switch verificationResult {
        case .verified(let appTransaction):
            return OpenIapAppTransaction(from: appTransaction)
        case .unverified(_, _):
            return nil
        }
        #else
        throw OpenIapError.make(code: OpenIapError.E_FEATURE_NOT_SUPPORTED)
        #endif
    }
    
    // MARK: - Subscription Management
    
    public func getActiveSubscriptions(subscriptionIds: [String]? = nil) async throws -> [OpenIapActiveSubscription] {
        var activeSubscriptions: [OpenIapActiveSubscription] = []
        
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
                    
                    let subscription = OpenIapActiveSubscription(
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
        // Open subscription management in App Store
        let scene: UIWindowScene? = await MainActor.run {
            UIApplication.shared.connectedScenes.first as? UIWindowScene
        }
        guard let scene else { throw OpenIapError.make(code: OpenIapError.E_UNKNOWN) }
        try await AppStore.showManageSubscriptions(in: scene)
        #else
        throw OpenIapError.make(code: OpenIapError.E_FEATURE_NOT_SUPPORTED)
        #endif
    }
    
    
    public func subscriptionStatusIOS(sku: String) async throws -> [OpenIapSubscriptionStatus]? {
        try await ensureConnection()
        
        var product = await productManager!.getProduct(productID: sku)
        if product == nil {
            product = try? await Product.products(for: [sku]).first
        }
        
        guard let product = product,
              let subscription = product.subscription else {
            throw OpenIapError.make(code: OpenIapError.E_SKU_NOT_FOUND, productId: sku)
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
                    state: status.state,
                    renewalInfo: renewalInfo
                )
            }
        } catch {
            throw OpenIapError.make(code: OpenIapError.E_SERVICE_ERROR, message: error.localizedDescription)
        }
    }
    
    @available(iOS 15.0, macOS 14.0, *)
    public func currentEntitlementIOS(sku: String) async throws -> OpenIapPurchase? {
        try await ensureConnection()
        
        var product = await productManager!.getProduct(productID: sku)
        if product == nil {
            product = try? await Product.products(for: [sku]).first
        }
        
        guard let product = product else {
            throw OpenIapError.make(code: OpenIapError.E_SKU_NOT_FOUND, productId: sku)
        }
        
        if let result = await product.currentEntitlement {
            do {
                let transaction = try checkVerified(result) as Transaction
                return await OpenIapPurchase(from: transaction, jwsRepresentation: result.jwsRepresentation)
            } catch {
                throw OpenIapError.make(code: OpenIapError.E_TRANSACTION_VALIDATION_FAILED, message: error.localizedDescription)
            }
        }
        
        return nil
    }
    
    @available(iOS 15.0, macOS 14.0, *)
    public func latestTransactionIOS(sku: String) async throws -> OpenIapPurchase? {
        try await ensureConnection()
        
        var product = await productManager!.getProduct(productID: sku)
        if product == nil {
            product = try? await Product.products(for: [sku]).first
        }
        
        guard let product = product else {
            throw OpenIapError.make(code: OpenIapError.E_SKU_NOT_FOUND, productId: sku)
        }
        
        if let result = await product.latestTransaction {
            do {
                let transaction = try checkVerified(result) as Transaction
                return await OpenIapPurchase(from: transaction, jwsRepresentation: result.jwsRepresentation)
            } catch {
                throw OpenIapError.make(code: OpenIapError.E_TRANSACTION_VALIDATION_FAILED, message: error.localizedDescription)
            }
        }
        
        return nil
    }
    
    // MARK: - Refunds (iOS 15+)
    
    public func beginRefundRequestIOS(sku: String) async throws -> String? {
        #if canImport(UIKit)
        var product = await productManager?.getProduct(productID: sku)
        if product == nil {
            product = try? await Product.products(for: [sku]).first
        }
        
        guard let product = product,
              let result = await product.latestTransaction else {
            throw OpenIapError.make(code: OpenIapError.E_SKU_NOT_FOUND, productId: sku)
        }
        
        do {
            let transaction = try checkVerified(result)
            
        let windowScene: UIWindowScene? = await MainActor.run {
            UIApplication.shared.connectedScenes.first as? UIWindowScene
        }
        guard let windowScene else { throw OpenIapError.make(code: OpenIapError.E_PURCHASE_ERROR, message: "Cannot find window scene") }
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
            throw OpenIapError.make(code: OpenIapError.E_PURCHASE_ERROR, message: error.localizedDescription)
        }
        #else
        throw OpenIapError.make(code: OpenIapError.E_FEATURE_NOT_SUPPORTED)
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
        throw OpenIapError.make(code: OpenIapError.E_FEATURE_NOT_SUPPORTED)
    }
    
    // MARK: - Legacy/Compatibility
    
    public func syncIOS() async throws -> Bool {
        do {
            try await AppStore.sync()
            return true
        } catch {
            throw OpenIapError.make(code: OpenIapError.E_SERVICE_ERROR, message: error.localizedDescription)
        }
    }
    
    public func presentCodeRedemptionSheetIOS() async throws -> Bool {
        #if canImport(UIKit)
        await MainActor.run {
            SKPaymentQueue.default().presentCodeRedemptionSheet()
        }
        return true
        #else
        throw OpenIapError.make(code: OpenIapError.E_FEATURE_NOT_SUPPORTED)
        #endif
    }
    
    public func showManageSubscriptionsIOS() async throws -> [[String: Any?]] {
        #if !os(tvOS)
        #if canImport(UIKit)
        let windowScene: UIWindowScene? = await MainActor.run {
            UIApplication.shared.connectedScenes.first as? UIWindowScene
        }
        guard let windowScene else {
            throw OpenIapError.make(code: OpenIapError.E_UNKNOWN)
        }
            
            // Get current subscription statuses before showing UI
            var beforeStatuses: [String: Bool] = [:]
            let subscriptionSkus = await getAllSubscriptionProductIds()
            
            for sku in subscriptionSkus {
                if let product = await productManager?.getProduct(productID: sku),
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
                if let product = await productManager?.getProduct(productID: sku),
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
        
        #else
        throw OpenIapError.make(code: OpenIapError.E_FEATURE_NOT_SUPPORTED)
        #endif
        #else
        throw OpenIapError.make(code: OpenIapError.E_FEATURE_NOT_SUPPORTED)
        #endif
    }
    
    
    // MARK: - Listener Management
    
    // MARK: - Private Methods
    
    private func startTransactionListener() {
        updateListenerTask = Task { [weak self] in
            guard let self = self else { return }
            
            for await result in Transaction.updates {
                do {
                    // Ensure initialized before emitting/handling
                    if await self.state.isInitialized == false {
                        OpenIapLog.debug("🟡 [Transaction.updates] Skipping event before init")
                        continue
                    }

                    let transaction = try self.checkVerified(result) as Transaction
                    let transactionId = String(transaction.id)
                    
                    // Skip if already processed by requestPurchase
                    if await self.state.isProcessed(transactionId) {
                    OpenIapLog.debug("🟡 [Transaction.updates] Skipping already processed: \(transactionId)")
                        // Remove from processed set for future updates (e.g., subscription renewals)
                        await self.state.unmarkProcessed(transactionId)
                        continue
                    }
                    
                    OpenIapLog.debug("🟢 [Transaction.updates] Processing new transaction: \(transactionId)")
                    
                    // Mark as processed to prevent duplicate from requestPurchase
                    await self.state.markProcessed(transactionId)
                    
                    // Store pending transaction - already on MainActor
                    await self.state.storePending(id: transactionId, transaction: transaction)
                    
                    // Emit purchase updated event for real-time updates
                    let purchase = await OpenIapPurchase(from: transaction, jwsRepresentation: result.jwsRepresentation)
                    OpenIapLog.debug("🟢 [Transaction.updates] Emitting event for: \(transactionId)")
                    self.emitPurchaseUpdate(purchase)
                    
                    // Clean up processed ID after a delay to allow for renewals
                    Task {
                        try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                        await self.state.unmarkProcessed(transactionId)
                    }
                    
                } catch {
                    // Emit purchase error when transaction verification fails
                    OpenIapLog.error("⚠️ Transaction verification failed: \(error)")
                    
                    let purchaseError: OpenIapError
                    if let openIapError = error as? OpenIapError {
                        purchaseError = openIapError
                    } else {
                        purchaseError = OpenIapError.make(code: OpenIapError.E_TRANSACTION_VALIDATION_FAILED)
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
                
                // Store pending transaction
                await self.state.storePending(id: transactionId, transaction: transaction)
                
                // Auto-finish non-consumable transactions
                if transaction.productType == .nonConsumable || 
                   transaction.productType == .autoRenewable {
                    await transaction.finish()
                }
            } catch {
                OpenIapLog.error("⚠️ Failed to process unfinished transaction: \(error)")
                
                // Emit purchase error for unfinished transaction processing failure
                let purchaseError: OpenIapError
                if let openIapError = error as? OpenIapError {
                    purchaseError = openIapError
                } else {
                    purchaseError = OpenIapError.make(code: OpenIapError.E_TRANSACTION_VALIDATION_FAILED)
                }
                emitPurchaseError(purchaseError)
                continue
            }
        }
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw OpenIapError.make(code: OpenIapError.E_TRANSACTION_VALIDATION_FAILED, message: "Transaction verification failed")
        case .verified(let safe):
            return safe
        }
    }
    
    @available(iOS 15.0, macOS 14.0, *)
    private func getAllSubscriptionProductIds() async -> [String] {
        // Get all subscription product IDs from the product store
        var subscriptionIds: [String] = []
        
        // Get all products and filter for subscriptions
        if let productManager = productManager {
            let products = await productManager.getAllProducts()
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
        Task { await state.addPurchaseUpdatedListener((subscription.id, listener)) }
        return subscription
    }
    
    /// Register a listener for purchase error events
    public func purchaseErrorListener(_ listener: @escaping PurchaseErrorListener) -> Subscription {
        let subscription = Subscription(eventType: .PURCHASE_ERROR)
        Task { await state.addPurchaseErrorListener((subscription.id, listener)) }
        return subscription
    }
    
    /// Register a listener for promoted product events (iOS only)
    public func promotedProductListenerIOS(_ listener: @escaping PromotedProductListener) -> Subscription {
        let subscription = Subscription(eventType: .PROMOTED_PRODUCT_IOS)
        Task { await state.addPromotedProductListener((subscription.id, listener)) }
        return subscription
    }
    
    /// Remove a listener by subscription
    public func removeListener(_ subscription: Subscription) {
        Task { await state.removeListener(id: subscription.id, type: subscription.eventType) }
        Task { await MainActor.run { subscription.onRemove?() } } // Trigger release for auto-disconnect on main
    }
    
    /// Remove all listeners
    public func removeAllListeners() {
        Task { await state.removeAllListeners() }
    }
    
    // MARK: - Event Emission (Private)
    
    private func emitPurchaseUpdate(_ purchase: OpenIapPurchase) {
        Task { [state] in
            let listeners: [PurchaseUpdatedListener] = await state.snapshotPurchaseUpdated()
            OpenIapLog.debug("🔵 [OpenIapModule] emitPurchaseUpdate called with \(listeners.count) listeners")
            await MainActor.run {
                for (index, listener) in listeners.enumerated() {
                    OpenIapLog.debug("  • Calling listener \(index + 1)")
                    listener(purchase)
                }
            }
        }
    }
    
    private func emitPurchaseError(_ error: OpenIapError) {
        Task { [state] in
            let listeners: [PurchaseErrorListener] = await state.snapshotPurchaseError()
            await MainActor.run {
                for listener in listeners { listener(error) }
            }
        }
    }
    
    private func emitPromotedProduct(_ sku: String) {
        Task { [state] in
            let listeners: [PromotedProductListener] = await state.snapshotPromoted()
            await MainActor.run {
                for listener in listeners { listener(sku) }
            }
        }
    }
    
}
