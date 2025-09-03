import Foundation
import StoreKit
#if canImport(UIKit)
import UIKit
#endif

import StoreKit

// MARK: - Helper functions for ExpoModulesCore compatibility

// MARK: - Purchase Listeners

@available(iOS 15.0, macOS 12.0, *)
public typealias PurchaseUpdatedListener = (IapPurchase) -> Void

@available(iOS 15.0, macOS 12.0, *)
public typealias PurchaseErrorListener = (IapError) -> Void

// MARK: - Protocol

@available(iOS 15.0, macOS 12.0, *)
public protocol IapModuleProtocol {
    // Connection Management
    func initConnection() async throws -> Bool
    func endConnection() async throws -> Bool
    
    // Product Management
    func fetchProducts(skus: [String]) async throws -> [IapProductData]
    func getAvailableItems(alsoPublishToEventListenerIOS: Bool?, onlyIncludeActiveItemsIOS: Bool?) async throws -> [IapTransactionData]
    
    // Purchase Operations
    func requestPurchase(
        sku: String,
        andDangerouslyFinishTransactionAutomatically: Bool,
        appAccountToken: String?,
        quantity: Int,
        discountOffer: [String: String]?
    ) async throws -> IapTransactionData?
    
    // Transaction Management
    func finishTransaction(transactionIdentifier: String) async throws -> Bool
    func getPendingTransactionsIOS() async throws -> [IapTransactionData]
    func clearTransactionIOS() async throws
    func isTransactionVerifiedIOS(sku: String) async -> Bool
    
    // Validation
    func getReceiptDataIOS() async throws -> String?
    func getTransactionJwsIOS(sku: String) async throws -> String?
    func validateReceiptIOS(sku: String) async throws -> IapReceiptValidation
    
    // Store Information
    func getStorefront() async throws -> String
    @available(iOS 16.0, macOS 13.0, *)
    func getAppTransactionIOS() async throws -> IapAppTransaction?
    
    // Subscription Management
    func isEligibleForIntroOfferIOS(groupID: String) async -> Bool
    func subscriptionStatusIOS(sku: String) async throws -> [IapSubscriptionStatus]?
    func currentEntitlementIOS(sku: String) async throws -> IapTransactionData?
    func latestTransactionIOS(sku: String) async throws -> IapTransactionData?
    
    // Refunds (iOS 15+)
    func beginRefundRequestIOS(sku: String) async throws -> String?
    
    // Promoted Products
    func getPromotedProductIOS() async throws -> IapPromotedProduct?
    func requestPurchaseOnPromotedProductIOS() async throws
    
    // Legacy/Compatibility
    func syncIOS() async throws -> Bool
    func presentCodeRedemptionSheetIOS() async throws -> Bool
    func showManageSubscriptionsIOS() async throws -> Bool
}


// MARK: - IapModule Implementation

@available(iOS 15.0, macOS 12.0, *)
public final class IapModule: NSObject, IapModuleProtocol {
    public static let shared = IapModule()
    
    // Transaction management  
    private var transactions: [String: Transaction] = [:]
    private var pendingTransactions: [String: Transaction] = [:]
    private var updateListenerTask: Task<Void, Error>?
    
    // Product caching
    private var productStore: ProductStore?
    
    // Purchase listeners
    private var purchaseUpdatedListeners: [PurchaseUpdatedListener] = []
    private var purchaseErrorListeners: [PurchaseErrorListener] = []
    
    // State
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
        
        
        self.isInitialized = true
        return AppStore.canMakePayments
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
    
    public func fetchProducts(skus: [String]) async throws -> [IapProductData] {
        try ensureConnection()
        
        let productStore = self.productStore!
        
        do {
            let fetchedProducts = try await Product.products(for: skus)
            fetchedProducts.forEach { product in
                productStore.addProduct(product)
            }
            let products = productStore.getAllProducts()
            return products.map { productToIapProductData($0) }
        } catch {
            print("Error fetching items: \(error)")
            throw error
        }
    }
    
    
    public func getAvailableItems(alsoPublishToEventListenerIOS: Bool?, onlyIncludeActiveItemsIOS: Bool?) async throws -> [IapTransactionData] {
        try ensureConnection()
        
        var purchasedItems: [IapTransactionData] = []
        
        for await verification in onlyIncludeActiveItemsIOS == true
            ? Transaction.currentEntitlements : Transaction.all
        {
            do {
                let transaction = try self.checkVerified(verification)
                if !(onlyIncludeActiveItemsIOS == true) {
                    let transactionData = transactionToIapTransactionData(transaction, jwsRepresentation: verification.jwsRepresentation)
                    purchasedItems.append(transactionData)
                    continue
                }
                
                // For active items only, check if transaction is still valid
                if let expirationDate = transaction.expirationDate {
                    if expirationDate > Date() {
                        let transactionData = transactionToIapTransactionData(transaction, jwsRepresentation: verification.jwsRepresentation)
                        purchasedItems.append(transactionData)
                    }
                } else {
                    // Non-subscription items (no expiration)
                    let transactionData = transactionToIapTransactionData(transaction, jwsRepresentation: verification.jwsRepresentation)
                    purchasedItems.append(transactionData)
                }
            } catch {
                // Handle verification errors silently for now
                continue
            }
        }
        return purchasedItems
    }
    
    public func getAvailablePurchases(alsoPublishToEventListenerIOS: Bool? = false, onlyIncludeActiveItems: Bool? = false) async throws -> [IapPurchase] {
        try ensureConnection()
        
        var purchases: [IapPurchase] = []
        
        // Choose transaction source based on onlyIncludeActiveItems
        let transactionSource = onlyIncludeActiveItems == true ? Transaction.currentEntitlements : Transaction.all
        
        for await result in transactionSource {
            do {
                let transaction = try checkVerified(result) as Transaction
                
                // If not filtering active items, add all transactions
                if onlyIncludeActiveItems != true {
                    let purchase = await IapPurchase(from: transaction, jwsRepresentation: result.jwsRepresentation)
                    purchases.append(purchase)
                    
                    // Event listeners removed - no notification needed
                    continue
                }
                
                // Filter active items based on product type
                var shouldInclude = false
                
                switch transaction.productType {
                case .consumable, .nonConsumable, .autoRenewable:
                    // Check if product exists in store
                    if let store = productStore, store.getProduct(productID: transaction.productID) != nil {
                        shouldInclude = true
                    } else {
                        // Try to fetch if not in cache
                        if let _ = try? await Product.products(for: [transaction.productID]).first {
                            shouldInclude = true
                        }
                    }
                    
                case .nonRenewable:
                    // Non-renewable subscriptions expire after 1 year
                    let currentDate = Date()
                    let calendar = Calendar(identifier: .gregorian)
                    if let expirationDate = calendar.date(byAdding: DateComponents(year: 1), to: transaction.purchaseDate) {
                        shouldInclude = currentDate < expirationDate
                    }
                    
                default:
                    shouldInclude = false
                }
                
                if shouldInclude {
                    let purchase = await IapPurchase(from: transaction, jwsRepresentation: result.jwsRepresentation)
                    purchases.append(purchase)
                    
                    // Event listeners removed - no notification needed
                }
                
            } catch {
                // Handle verification errors silently for now
                continue
            }
        }
        
        return purchases
    }
    
    public func getPurchaseHistories(alsoPublishToEventListener: Bool? = false, onlyIncludeActiveItems: Bool? = false) async throws -> [IapPurchase] {
        // iOS returns all purchase history
        let purchases = try await getAvailablePurchases(onlyIncludeActiveItems: false)
        
        // Event listeners removed - no notification needed
        
        if onlyIncludeActiveItems == true {
            // Filter only active items
            return purchases.filter { $0.purchaseState == .purchased || $0.purchaseState == .restored }
        }
        
        return purchases
    }
    
    // MARK: - Purchase Operations
    
    public func requestPurchase(
        sku: String,
        andDangerouslyFinishTransactionAutomatically: Bool,
        appAccountToken: String?,
        quantity: Int,
        discountOffer: [String: String]?
    ) async throws -> IapTransactionData? {
        try ensureConnection()
        
        // Get product from cache or fetch
        var product = productStore!.getProduct(productID: sku)
        if product == nil {
            let products = try await Product.products(for: [sku])
            product = products.first
            if let product = product {
                productStore!.addProduct(product)
            }
        }
        
        guard let product = product else {
            throw IapError.productNotFound(productId: sku)
        }
        
        // Build purchase options
        var options: Set<Product.PurchaseOption> = []
        
        // Add quantity option
        if quantity > 1 {
            options.insert(.quantity(quantity))
        }
        
        // Add promotional offer if provided
        if let offerID = discountOffer?["identifier"],
           let keyID = discountOffer?["keyIdentifier"],
           let nonce = discountOffer?["nonce"],
           let signature = discountOffer?["signature"],
           let timestamp = discountOffer?["timestamp"],
           let uuidNonce = UUID(uuidString: nonce),
           let signatureData = Data(base64Encoded: signature),
           let timestampInt = Int(timestamp) {
            options.insert(
                .promotionalOffer(
                    offerID: offerID,
                    keyID: keyID,
                    nonce: uuidNonce,
                    signature: signatureData,
                    timestamp: timestampInt
                )
            )
        }
        
        // Add app account token if provided
        if let appAccountToken = appAccountToken,
           let appAccountUUID = UUID(uuidString: appAccountToken) {
            options.insert(.appAccountToken(appAccountUUID))
        }
        
        // Perform purchase with appropriate method based on iOS version
        let result: Product.PurchaseResult
        
        #if canImport(UIKit)
        if #available(iOS 17.0, *) {
            guard let scene = await UIApplication.shared.connectedScenes.first as? UIWindowScene else {
                throw IapError.purchaseFailed(reason: "Could not find window scene")
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
            let transactionData = transactionToIapTransactionData(transaction, jwsRepresentation: verification.jwsRepresentation)
            
            // Convert to IapPurchase for listener
            let purchase = await IapPurchase(from: transaction, jwsRepresentation: verification.jwsRepresentation)
            
            // Notify listeners
            for listener in purchaseUpdatedListeners {
                listener(purchase)
            }
            
            // Store transaction if not finishing automatically
            if !andDangerouslyFinishTransactionAutomatically {
                pendingTransactions[String(transaction.id)] = transaction
            } else {
                await transaction.finish()
                // Still return the transaction data even when finishing automatically
            }
            
            return transactionData
            
        case .userCancelled:
            let error = IapError.purchaseCancelled
            for listener in purchaseErrorListeners {
                listener(error)
            }
            throw error
            
        case .pending:
            // For deferred payments, we don't call error listeners
            throw IapError.purchaseDeferred
            
        @unknown default:
            let error = IapError.unknownError
            for listener in purchaseErrorListeners {
                listener(error)
            }
            throw error
        }
    }
    
    // MARK: - Transaction Management
    
    public func finishTransaction(transactionIdentifier: String) async throws -> Bool {
        // Check pending transactions first
        if let transaction = pendingTransactions[transactionIdentifier] {
            await transaction.finish()
            pendingTransactions.removeValue(forKey: transactionIdentifier)
            return true
        }
        
        // Otherwise search in all transactions
        guard let id = UInt64(transactionIdentifier) else {
            throw IapError.purchaseFailed(reason: "Invalid transaction ID")
        }
        
        for await result in Transaction.all {
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
        
        throw IapError.purchaseFailed(reason: "Transaction not found")
    }
    
    public func getPendingTransactions() async -> [IapPurchase] {
        var purchases: [IapPurchase] = []
        for (_, transaction) in pendingTransactions {
            let purchase = await IapPurchase(from: transaction)
            purchases.append(purchase)
        }
        return purchases
    }
    
    public func getPendingTransactionsIOS() async throws -> [IapTransactionData] {
        var transactionDataArray: [IapTransactionData] = []
        for (_, transaction) in pendingTransactions {
            let transactionData = transactionToIapTransactionData(transaction, jwsRepresentation: nil)
            transactionDataArray.append(transactionData)
        }
        return transactionDataArray
    }
    
    public func clearTransactions() async throws {
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
    
    public func clearTransactionIOS() async throws {
        try await clearTransactions()
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
    
    public func validateReceipt(productId: String? = nil) async throws -> IapReceipt {
        guard let appStoreReceiptURL = Bundle.main.appStoreReceiptURL,
              FileManager.default.fileExists(atPath: appStoreReceiptURL.path) else {
            throw IapError.invalidReceipt
        }
        
        let receiptData = try? Data(contentsOf: appStoreReceiptURL)
        
        guard receiptData != nil else {
            throw IapError.invalidReceipt
        }
        
        let purchases = try await getAvailablePurchases(onlyIncludeActiveItems: false)
        
        return IapReceipt(
            bundleId: Bundle.main.bundleIdentifier ?? "",
            applicationVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "",
            originalApplicationVersion: Bundle.main.infoDictionary?["CFBundleVersion"] as? String,
            creationDate: Date(),
            expirationDate: nil,
            inAppPurchases: purchases
        )
    }
    
    public func getReceiptData() async throws -> String {
        guard let appStoreReceiptURL = Bundle.main.appStoreReceiptURL,
              FileManager.default.fileExists(atPath: appStoreReceiptURL.path) else {
            throw IapError.invalidReceipt
        }
        
        let receiptData = try Data(contentsOf: appStoreReceiptURL)
        return receiptData.base64EncodedString(options: [])
    }
    
    public func getReceiptDataIOS() async throws -> String? {
        do {
            return try await getReceiptData()
        } catch {
            return nil
        }
    }
    
    public func getTransactionJws(productId: String) async throws -> String? {
        var product = productStore!.getProduct(productID: productId)
        if product == nil {
            product = try? await Product.products(for: [productId]).first
        }
        
        guard let product = product,
              let result = await product.latestTransaction else {
            throw IapError.productNotFound(productId: productId)
        }
        
        return result.jwsRepresentation
    }
    
    public func getTransactionJwsIOS(sku: String) async throws -> String? {
        return try await getTransactionJws(productId: sku)
    }
    
    public func validateReceiptIOS(sku: String) async throws -> IapReceiptValidation {
        var receiptData: String = ""
        do {
            receiptData = try await getReceiptData()
        } catch {
            // Continue with validation even if receipt retrieval fails
        }
        
        var isValid = false
        var jwsRepresentation: String = ""
        var latestTransaction: IapTransactionData? = nil
        
        var product = productStore!.getProduct(productID: sku)
        if product == nil {
            product = try? await Product.products(for: [sku]).first
        }
        
        if let product = product,
           let result = await product.latestTransaction {
            jwsRepresentation = result.jwsRepresentation
            
            do {
                let transaction = try checkVerified(result) as Transaction
                isValid = true
                latestTransaction = transactionToIapTransactionData(transaction, jwsRepresentation: result.jwsRepresentation)
            } catch {
                isValid = false
            }
        }
        
        return IapReceiptValidation(
            isValid: isValid,
            receiptData: receiptData,
            jwsRepresentation: jwsRepresentation,
            latestTransaction: latestTransaction
        )
    }
    
    // MARK: - Store Information
    
    public func getStorefront() async throws -> String {
        if #available(iOS 13.0, *) {
            guard let storefront = await Storefront.current else {
                throw IapError.unknownError
            }
            return storefront.countryCode
        } else {
            throw IapError.notSupported
        }
    }
    
    @available(iOS 16.0, macOS 13.0, *)
    public func getAppTransactionIOS() async throws -> IapAppTransaction? {
        if #available(iOS 16.0, *) {
            #if compiler(>=5.7)
            let verificationResult = try await AppTransaction.shared
            
            switch verificationResult {
            case .verified(let appTransaction):
                return IapAppTransaction(from: appTransaction)
            case .unverified(_, _):
                return nil
            }
            #else
            throw IapError.notSupported
            #endif
        } else {
            throw IapError.notSupported
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
                throw IapError.unknownError
            }
            
            try await AppStore.showManageSubscriptions(in: scene)
        } else {
            // Fallback for older iOS versions
            guard let url = URL(string: "https://apps.apple.com/account/subscriptions") else {
                throw IapError.unknownError
            }
            
            await UIApplication.shared.open(url, options: [:])
        }
        #else
        throw IapError.notSupported
        #endif
    }
    
    public func isEligibleForIntroOffer(groupId: String) async -> Bool {
        return await Product.SubscriptionInfo.isEligibleForIntroOffer(for: groupId)
    }
    
    public func subscriptionStatusIOS(sku: String) async throws -> [IapSubscriptionStatus]? {
        try ensureConnection()
        
        var product = productStore!.getProduct(productID: sku)
        if product == nil {
            product = try? await Product.products(for: [sku]).first
        }
        
        guard let product = product,
              let subscription = product.subscription else {
            throw IapError.productNotFound(productId: sku)
        }
        
        do {
            let status = try await subscription.status
            return status.map { status in
                var renewalInfo: IapRenewalInfo? = nil
                
                switch status.renewalInfo {
                case .verified(let info):
                    renewalInfo = IapRenewalInfo(
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
                
                return IapSubscriptionStatus(
                    state: status.state.rawValue.description,
                    renewalInfo: renewalInfo
                )
            }
        } catch {
            throw IapError.storeKitError(error: error)
        }
    }
    
    public func currentEntitlementIOS(sku: String) async throws -> IapTransactionData? {
        try ensureConnection()
        
        var product = productStore!.getProduct(productID: sku)
        if product == nil {
            product = try? await Product.products(for: [sku]).first
        }
        
        guard let product = product else {
            throw IapError.productNotFound(productId: sku)
        }
        
        if let result = await product.currentEntitlement {
            do {
                let transaction = try checkVerified(result) as Transaction
                return transactionToIapTransactionData(transaction, jwsRepresentation: result.jwsRepresentation)
            } catch {
                throw IapError.verificationFailed(reason: error.localizedDescription)
            }
        }
        
        return nil
    }
    
    public func latestTransactionIOS(sku: String) async throws -> IapTransactionData? {
        try ensureConnection()
        
        var product = productStore!.getProduct(productID: sku)
        if product == nil {
            product = try? await Product.products(for: [sku]).first
        }
        
        guard let product = product else {
            throw IapError.productNotFound(productId: sku)
        }
        
        if let result = await product.latestTransaction {
            do {
                let transaction = try checkVerified(result) as Transaction
                return transactionToIapTransactionData(transaction, jwsRepresentation: result.jwsRepresentation)
            } catch {
                throw IapError.verificationFailed(reason: error.localizedDescription)
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
            throw IapError.productNotFound(productId: sku)
        }
        
        do {
            let transaction = try checkVerified(result)
            
            guard let windowScene = await UIApplication.shared.connectedScenes.first as? UIWindowScene else {
                throw IapError.purchaseFailed(reason: "Cannot find window scene")
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
            throw IapError.purchaseFailed(reason: error.localizedDescription)
        }
        #else
        throw IapError.notSupported
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
    
    public func getPromotedProductIOS() async throws -> IapPromotedProduct? {
        // Not implemented without Event Listeners system
        return nil
    }
    
    public func requestPurchaseOnPromotedProductIOS() async throws {
        // Not implemented without Event Listeners system
        throw IapError.notSupported
    }
    
    // MARK: - Legacy/Compatibility
    
    public func syncIOS() async throws -> Bool {
        do {
            try await AppStore.sync()
            return true
        } catch {
            throw IapError.storeKitError(error: error)
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
            throw IapError.notSupported
        }
        #else
        throw IapError.notSupported
        #endif
    }
    
    public func showManageSubscriptionsIOS() async throws -> Bool {
        #if canImport(UIKit)
        if #available(iOS 15.0, *) {
            guard let scene = await UIApplication.shared.connectedScenes.first as? UIWindowScene else {
                throw IapError.unknownError
            }
            
            try await AppStore.showManageSubscriptions(in: scene)
            return true
        } else {
            // Fallback for older iOS versions
            guard let url = URL(string: "https://apps.apple.com/account/subscriptions") else {
                throw IapError.unknownError
            }
            
            await UIApplication.shared.open(url, options: [:])
            return true
        }
        #else
        throw IapError.notSupported
        #endif
    }
    
    
    // MARK: - Listener Management
    
    public func addPurchaseUpdatedListener(_ listener: @escaping PurchaseUpdatedListener) {
        purchaseUpdatedListeners.append(listener)
    }
    
    public func removePurchaseUpdatedListener(_ listener: @escaping PurchaseUpdatedListener) {
        // Note: In Swift, comparing closures is not straightforward
        // For now, we provide a method to clear all listeners
        // In production, you might want to use a UUID-based system
    }
    
    public func removeAllPurchaseUpdatedListeners() {
        purchaseUpdatedListeners.removeAll()
    }
    
    public func addPurchaseErrorListener(_ listener: @escaping PurchaseErrorListener) {
        purchaseErrorListeners.append(listener)
    }
    
    public func removePurchaseErrorListener(_ listener: @escaping PurchaseErrorListener) {
        // Note: In Swift, comparing closures is not straightforward
        // For now, we provide a method to clear all listeners
    }
    
    public func removeAllPurchaseErrorListeners() {
        purchaseErrorListeners.removeAll()
    }
    
    // MARK: - Private Methods
    
    private func ensureConnection() throws {
        guard isInitialized else {
            throw IapError.purchaseFailed(reason: "Connection not initialized. Call initConnection() first.")
        }
    }
    
    private func startTransactionListener() {
        updateListenerTask = Task {
            for await result in Transaction.updates {
                do {
                    let transaction = try checkVerified(result) as Transaction
                    
                    // Store transaction temporarily for pending transactions tracking
                    pendingTransactions[String(transaction.id)] = transaction
                    
                } catch {
                    // Silent error handling - transaction verification failed
                }
            }
        }
    }
    
    private func processUnfinishedTransactions() async {
        for await result in Transaction.unfinished {
            do {
                let transaction = try checkVerified(result) as Transaction
                // Store as pending
                pendingTransactions[String(transaction.id)] = transaction
                
                // Simply store as pending - no notification needed
            } catch {
                continue
            }
        }
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw IapError.verificationFailed(reason: "Transaction verification failed")
        case .verified(let safe):
            return safe
        }
    }
    
    private func productToIapProductData(_ product: Product) -> IapProductData {
        let productType: String
        switch product.type {
        case .consumable:
            productType = "inapp"
        case .nonConsumable:
            productType = "inapp"  
        case .autoRenewable:
            productType = "subs"
        case .nonRenewable:
            productType = "inapp"
        default:
            productType = "inapp"
        }
        
        return IapProductData(
            id: product.id,
            title: product.displayName,
            description: product.description,
            price: product.price,
            displayPrice: product.displayPrice,
            currency: product.priceFormatStyle.currencyCode,
            type: productType,
            platform: "ios"
        )
    }
    
    private func transactionToIapTransactionData(_ transaction: Transaction, jwsRepresentation: String?) -> IapTransactionData {
        let productType: String
        switch transaction.productType {
        case .consumable:
            productType = "inapp"
        case .nonConsumable:
            productType = "inapp"
        case .autoRenewable:
            productType = "subs"
        case .nonRenewable:
            productType = "inapp"
        default:
            productType = "inapp"
        }
        
        let ownershipType: String
        switch transaction.ownershipType {
        case .purchased:
            ownershipType = "purchased"
        case .familyShared:
            ownershipType = "family_shared"
        default:
            ownershipType = "purchased"
        }
        
        return IapTransactionData(
            id: String(transaction.id),
            productId: transaction.productID,
            transactionId: String(transaction.id),
            transactionDate: transaction.purchaseDate.timeIntervalSince1970 * 1000,
            transactionReceipt: jwsRepresentation ?? "",
            platform: "ios",
            quantityIOS: transaction.purchasedQuantity,
            originalTransactionDateIOS: transaction.originalPurchaseDate.timeIntervalSince1970 * 1000,
            originalTransactionIdentifierIOS: String(transaction.originalID),
            appAccountToken: transaction.appAccountToken?.uuidString,
            productTypeIOS: productType,
            isUpgradedIOS: transaction.isUpgraded,
            ownershipTypeIOS: ownershipType,
            revocationDateIOS: transaction.revocationDate?.timeIntervalSince1970,
            revocationReasonIOS: transaction.revocationReason?.rawValue,
            expirationDateIOS: transaction.expirationDate?.timeIntervalSince1970,
            jwsRepresentationIOS: jwsRepresentation,
            purchaseToken: jwsRepresentation,
            environmentIOS: {
                if #available(iOS 16.0, macOS 13.0, *) {
                    return transaction.environment.rawValue
                } else {
                    return "production" // fallback for older versions
                }
            }()
        )
    }
    
}