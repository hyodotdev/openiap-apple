import Foundation
import StoreKit
#if canImport(UIKit)
import UIKit
#endif

@available(iOS 15.0, macOS 14.0, *)
public final class OpenIapModule: NSObject, OpenIapModuleProtocol {
    public static let shared = OpenIapModule()

    private var updateListenerTask: Task<Void, Error>?
    private var productManager: ProductManager?
    private let state = IapState()
    private var initTask: Task<Bool, Error>?
    #if os(iOS)
    private var didRegisterPaymentQueueObserver = false
    #endif

    private override init() {
        super.init()
    }

    deinit { updateListenerTask?.cancel() }

    // MARK: - Connection Management

    private func ensureConnection() async throws {
        if await state.isInitialized == false {
            _ = try await initConnection()
        }

        guard await state.isInitialized else {
            let error = makePurchaseError(code: .initConnection)
            emitPurchaseError(error)
            throw error
        }

        guard AppStore.canMakePayments else {
            let error = makePurchaseError(code: .iapNotAvailable)
            emitPurchaseError(error)
            throw error
        }
    }

    public func initConnection() async throws -> Bool {
        if let task = initTask {
            return try await task.value
        }

        let task = Task { [weak self] () -> Bool in
            guard let self else { return false }
            return try await self.initConnectionInternal()
        }
        initTask = task

        do {
            let value = try await task.value
            initTask = nil
            return value
        } catch {
            initTask = nil
            throw error
        }
    }

    private func initConnectionInternal() async throws -> Bool {
        await cleanupExistingState()
        productManager = ProductManager()

        #if os(iOS)
        if !didRegisterPaymentQueueObserver {
            await MainActor.run {
                SKPaymentQueue.default().add(self)
            }
            didRegisterPaymentQueueObserver = true
        }
        #endif

        guard AppStore.canMakePayments else {
            emitPurchaseError(makePurchaseError(code: .iapNotAvailable))
            await state.setInitialized(false)
            return false
        }

        await state.setInitialized(true)
        startTransactionListener()
        await processUnfinishedTransactions()
        return true
    }

    public func endConnection() async throws -> Bool {
        return try await endConnectionInternal()
    }

    private func endConnectionInternal() async throws -> Bool {
        initTask?.cancel()
        initTask = nil
        await cleanupExistingState()
        return true
    }

    private func cleanupExistingState() async {
        updateListenerTask?.cancel()
        updateListenerTask = nil
        await state.reset()
        #if os(iOS)
        if didRegisterPaymentQueueObserver {
            await MainActor.run {
                SKPaymentQueue.default().remove(self)
            }
            didRegisterPaymentQueueObserver = false
        }
        #endif
        if let manager = productManager { await manager.removeAll() }
        productManager = nil
    }

    // MARK: - Product Management

    public func fetchProducts(_ params: ProductRequest) async throws -> FetchProductsResult {
        guard !params.skus.isEmpty else {
            let error = makePurchaseError(code: .emptySkuList)
            emitPurchaseError(error)
            throw error
        }

        try await ensureConnection()
        guard let productManager else {
            let error = makePurchaseError(code: .notPrepared)
            emitPurchaseError(error)
            throw error
        }

        do {
            let fetched = try await StoreKit.Product.products(for: params.skus)
            for product in fetched {
                await productManager.addProduct(product)
            }
        } catch {
            let purchaseError = makePurchaseError(code: .queryProduct, message: error.localizedDescription)
            emitPurchaseError(purchaseError)
            throw purchaseError
        }

        let storedProducts = await productManager.getAllProducts()
        var productEntries: [OpenIAP.Product] = []
        var subscriptionEntries: [OpenIAP.ProductSubscription] = []

        for product in storedProducts {
            productEntries.append(await StoreKitTypesBridge.product(from: product))
            if let subscription = await StoreKitTypesBridge.productSubscription(from: product) {
                subscriptionEntries.append(subscription)
            }
        }

        switch params.type ?? .all {
        case .subs:
            return .subscriptions(subscriptionEntries.isEmpty ? nil : subscriptionEntries)
        case .inApp:
            let inApp = productEntries.compactMap { entry -> OpenIAP.Product? in
                guard case let .productIos(value) = entry, value.type == .inApp else { return nil }
                return entry
            }
            return .products(inApp.isEmpty ? nil : inApp)
        case .all:
            return .products(productEntries.isEmpty ? nil : productEntries)
        }
    }

    public func getPromotedProductIOS() async throws -> ProductIOS? {
        #if os(iOS)
        let sku = await state.promotedProductIdentifier()
        guard let sku else { return nil }

        do {
            try await ensureConnection()
        } catch let purchaseError as PurchaseError {
            throw purchaseError
        }

        await state.setPromotedProductId(sku)

        do {
            let product = try await storeProduct(for: sku)
            return await StoreKitTypesBridge.productIOS(from: product)
        } catch let purchaseError as PurchaseError {
            await state.setPromotedProductId(nil)
            throw purchaseError
        } catch {
            let wrapped = makePurchaseError(code: .queryProduct, productId: sku, message: error.localizedDescription)
            emitPurchaseError(wrapped)
            await state.setPromotedProductId(nil)
            throw wrapped
        }
        #else
        return nil
        #endif
    }

    // MARK: - Purchase Management

    public func requestPurchase(_ params: RequestPurchaseProps) async throws -> RequestPurchaseResult? {
        try await ensureConnection()
        let iosProps = try resolveIosPurchaseProps(from: params)
        let sku = iosProps.sku
        let product = try await storeProduct(for: sku)
        let options = iosProps.storeKitPurchaseOptions()

        let result: StoreKit.Product.PurchaseResult
        #if canImport(UIKit)
        if #available(iOS 17.0, *) {
            let scene: UIWindowScene? = await MainActor.run {
                UIApplication.shared.connectedScenes.first as? UIWindowScene
            }
            guard let scene else {
                let error = makePurchaseError(code: .purchaseError, message: "Could not find window scene")
                emitPurchaseError(error)
                throw error
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
            let purchase = await StoreKitTypesBridge.purchase(from: transaction, jwsRepresentation: verification.jwsRepresentation)
            let transactionId = String(transaction.id)
            let shouldAutoFinish = iosProps.andDangerouslyFinishTransactionAutomatically == true

            if await state.isProcessed(transactionId) == false {
                await state.markProcessed(transactionId)
                emitPurchaseUpdate(purchase)
            }

            if shouldAutoFinish {
                await transaction.finish()
            } else {
                await state.storePending(id: transactionId, transaction: transaction)
            }

            return .purchase(purchase)

        case .userCancelled:
            let error = makePurchaseError(code: .userCancelled, productId: sku)
            emitPurchaseError(error)
            throw error

        case .pending:
            let error = makePurchaseError(code: .deferredPayment, productId: sku)
            emitPurchaseError(error)
            throw error

        @unknown default:
            let error = makePurchaseError(code: .unknown, productId: sku)
            emitPurchaseError(error)
            throw error
        }
    }

    public func requestPurchaseOnPromotedProductIOS() async throws -> Bool {
        throw makePurchaseError(code: .featureNotSupported)
    }

    public func restorePurchases() async throws -> Void {
        _ = try await syncIOS()
    }

    public func getAvailablePurchases(_ options: PurchaseOptions?) async throws -> [Purchase] {
        try await ensureConnection()
        let onlyActive = options?.onlyIncludeActiveItemsIOS ?? false
        var purchasedItems: [Purchase] = []

        OpenIapLog.debug("🔍 getAvailablePurchases called. onlyActive=\(onlyActive)")

        for await verification in (onlyActive ? Transaction.currentEntitlements : Transaction.all) {
            do {
                let transaction = try checkVerified(verification)

                if onlyActive, let expirationDate = transaction.expirationDate, expirationDate <= Date() {
                    continue
                }

                let purchase = await StoreKitTypesBridge.purchase(
                    from: transaction,
                    jwsRepresentation: verification.jwsRepresentation
                )
                purchasedItems.append(purchase)
            } catch {
                OpenIapLog.error("getAvailablePurchases: failed to verify transaction: \(error)")
                continue
            }
        }

        OpenIapLog.debug("🔍 getAvailablePurchases returning \(purchasedItems.count) purchases")
        return purchasedItems
    }

    // MARK: - Transaction Management

    public func finishTransaction(purchase: PurchaseInput, isConsumable: Bool?) async throws -> Void {
        try await finishTransaction(byIdentifier: purchase.id)
    }

    public func getPendingTransactionsIOS() async throws -> [PurchaseIOS] {
        let snapshot = await state.pendingSnapshot()
        var purchases: [PurchaseIOS] = []
        for transaction in snapshot {
            purchases.append(await StoreKitTypesBridge.purchaseIOS(from: transaction, jwsRepresentation: nil))
        }
        return purchases
    }

    public func clearTransactionIOS() async throws -> Bool {
        for await result in Transaction.unfinished {
            do {
                let transaction = try checkVerified(result)
                await transaction.finish()
                await state.removePending(id: String(transaction.id))
            } catch {
                continue
            }
        }
        return true
    }

    public func isTransactionVerifiedIOS(sku: String) async throws -> Bool {
        let product = try await storeProduct(for: sku)
        guard let result = await product.latestTransaction else { return false }
        do {
            _ = try checkVerified(result)
            return true
        } catch {
            return false
        }
    }

    public func getTransactionJwsIOS(sku: String) async throws -> String? {
        let product = try await storeProduct(for: sku)
        guard let result = await product.latestTransaction else {
            let error = makePurchaseError(code: .skuNotFound, productId: sku)
            emitPurchaseError(error)
            throw error
        }
        return result.jwsRepresentation
    }

    private func finishTransaction(byIdentifier identifier: String) async throws {
        if let pending = await state.getPending(id: identifier) {
            await pending.finish()
            await state.removePending(id: identifier)
            return
        }

        guard let numericId = UInt64(identifier) else {
            let error = makePurchaseError(code: .purchaseError, message: "Invalid transaction identifier")
            emitPurchaseError(error)
            throw error
        }

        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                if transaction.id == numericId {
                    await transaction.finish()
                    return
                }
            } catch {
                continue
            }
        }

        for await result in Transaction.unfinished {
            do {
                let transaction = try checkVerified(result)
                if transaction.id == numericId {
                    await transaction.finish()
                    return
                }
            } catch {
                continue
            }
        }

        let error = makePurchaseError(code: .purchaseError, message: "Transaction not found")
        emitPurchaseError(error)
        throw error
    }

    // MARK: - Validation

    public func getReceiptDataIOS() async throws -> String? {
        guard let receiptURL = Bundle.main.appStoreReceiptURL,
              FileManager.default.fileExists(atPath: receiptURL.path) else {
            return nil
        }
        let data = try Data(contentsOf: receiptURL)
        return data.base64EncodedString()
    }

    public func validateReceiptIOS(_ props: ReceiptValidationProps) async throws -> ReceiptValidationResultIOS {
        let receiptData = (try? await getReceiptDataIOS()) ?? ""
        var latestPurchase: Purchase? = nil
        var jws: String = ""
        var isValid = false

        do {
            let product = try await storeProduct(for: props.sku)
            if let result = await product.latestTransaction {
                jws = result.jwsRepresentation
                let transaction = try checkVerified(result)
                latestPurchase = .purchaseIos(await StoreKitTypesBridge.purchaseIOS(from: transaction, jwsRepresentation: result.jwsRepresentation))
                isValid = true
            }
        } catch {
            isValid = false
        }

        return ReceiptValidationResultIOS(
            isValid: isValid,
            jwsRepresentation: jws,
            latestTransaction: latestPurchase,
            receiptData: receiptData
        )
    }

    public func validateReceipt(_ props: ReceiptValidationProps) async throws -> ReceiptValidationResult {
        let iosResult = try await validateReceiptIOS(props)
        return .receiptValidationResultIos(iosResult)
    }

    // MARK: - Store Information

    public func getStorefrontIOS() async throws -> String {
        guard let storefront = await Storefront.current else {
            let error = makePurchaseError(code: .unknown)
            emitPurchaseError(error)
            throw error
        }
        return storefront.countryCode
    }

    @available(iOS 16.0, macOS 14.0, *)
    public func getAppTransactionIOS() async throws -> AppTransaction? {
        let verification = try await StoreKit.AppTransaction.shared
        switch verification {
        case .verified(let transaction):
            return mapAppTransaction(transaction)
        case .unverified:
            return nil
        }
    }

    // MARK: - Subscription Management

    public func getActiveSubscriptions(_ subscriptionIds: [String]?) async throws -> [ActiveSubscription] {
        var subscriptions: [ActiveSubscription] = []
        for await verification in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(verification)
                guard transaction.productType == .autoRenewable else { continue }
                if let ids = subscriptionIds, ids.contains(transaction.productID) == false {
                    continue
                }
                let expiration = transaction.expirationDate
                let isActive = expiration.map { $0 > Date() } ?? true
                let dayDelta = expiration.map { Calendar.current.dateComponents([.day], from: Date(), to: $0).day ?? 0 }
                let daysUntilExpiration = dayDelta.map { Double($0) }
                let willExpireSoon = dayDelta.map { $0 < 7 } ?? false
                let environment: String?
                if #available(iOS 16.0, *) {
                    environment = transaction.environment.rawValue
                } else {
                    environment = nil
                }

                subscriptions.append(
                    ActiveSubscription(
                        autoRenewingAndroid: nil,
                        daysUntilExpirationIOS: daysUntilExpiration,
                        environmentIOS: environment,
                        expirationDateIOS: expiration?.milliseconds,
                        isActive: isActive,
                        productId: transaction.productID,
                        purchaseToken: verification.jwsRepresentation,
                        transactionDate: transaction.purchaseDate.milliseconds,
                        transactionId: String(transaction.id),
                        willExpireSoon: willExpireSoon
                    )
                )
            } catch {
                continue
            }
        }
        return subscriptions
    }

    public func hasActiveSubscriptions(_ subscriptionIds: [String]?) async throws -> Bool {
        let subscriptions = try await getActiveSubscriptions(subscriptionIds)
        return subscriptions.contains { $0.isActive }
    }

    public func deepLinkToSubscriptions(_ options: DeepLinkOptions?) async throws -> Void {
        #if canImport(UIKit)
        let scene: UIWindowScene? = await MainActor.run {
            UIApplication.shared.connectedScenes.first as? UIWindowScene
        }
        guard let scene else {
            throw makePurchaseError(code: .unknown)
        }
        try await AppStore.showManageSubscriptions(in: scene)
        #else
        throw makePurchaseError(code: .featureNotSupported)
        #endif
    }

    public func subscriptionStatusIOS(sku: String) async throws -> [SubscriptionStatusIOS] {
        let product = try await storeProduct(for: sku)
        guard let subscription = product.subscription else {
            let error = makePurchaseError(code: .skuNotFound, productId: sku)
            emitPurchaseError(error)
            throw error
        }

        do {
            let statuses = try await subscription.status
            return statuses.map { status in
                let renewalInfo: RenewalInfoIOS?
                switch status.renewalInfo {
                case .verified(let info):
                    let jsonString = String(data: info.jsonRepresentation, encoding: .utf8) ?? info.jsonRepresentation.base64EncodedString()
                    renewalInfo = RenewalInfoIOS(
                        autoRenewPreference: info.autoRenewPreference,
                        jsonRepresentation: jsonString,
                        willAutoRenew: info.willAutoRenew
                    )
                case .unverified:
                    renewalInfo = nil
                }
                return SubscriptionStatusIOS(
                    renewalInfo: renewalInfo,
                    state: String(describing: status.state)
                )
            }
        } catch {
            let purchaseError = makePurchaseError(code: .serviceError, message: error.localizedDescription)
            emitPurchaseError(purchaseError)
            throw purchaseError
        }
    }

    public func currentEntitlementIOS(sku: String) async throws -> PurchaseIOS? {
        let product = try await storeProduct(for: sku)
        guard let result = await product.currentEntitlement else { return nil }
        do {
            let transaction = try checkVerified(result)
            return await StoreKitTypesBridge.purchaseIOS(from: transaction, jwsRepresentation: result.jwsRepresentation)
        } catch {
            let error = makePurchaseError(code: .transactionValidationFailed, message: error.localizedDescription)
            emitPurchaseError(error)
            throw error
        }
    }

    public func latestTransactionIOS(sku: String) async throws -> PurchaseIOS? {
        let product = try await storeProduct(for: sku)
        guard let result = await product.latestTransaction else { return nil }
        do {
            let transaction = try checkVerified(result)
            return await StoreKitTypesBridge.purchaseIOS(from: transaction, jwsRepresentation: result.jwsRepresentation)
        } catch {
            let error = makePurchaseError(code: .transactionValidationFailed, message: error.localizedDescription)
            emitPurchaseError(error)
            throw error
        }
    }

    // MARK: - Refunds

    public func beginRefundRequestIOS(sku: String) async throws -> String? {
        #if canImport(UIKit)
        let product = try await storeProduct(for: sku)
        guard let result = await product.latestTransaction else {
            let error = makePurchaseError(code: .skuNotFound, productId: sku)
            emitPurchaseError(error)
            throw error
        }

        let transaction = try checkVerified(result)
        let scene: UIWindowScene? = await MainActor.run {
            UIApplication.shared.connectedScenes.first as? UIWindowScene
        }
        guard let scene else {
            let error = makePurchaseError(code: .purchaseError, message: "Cannot find window scene")
            emitPurchaseError(error)
            throw error
        }

        let status = try await transaction.beginRefundRequest(in: scene)
        switch status {
        case .success:
            return "success"
        case .userCancelled:
            return "userCancelled"
        @unknown default:
            return nil
        }
        #else
        throw makePurchaseError(code: .featureNotSupported)
        #endif
    }

    // MARK: - Misc

    public func isEligibleForIntroOfferIOS(groupID: String) async throws -> Bool {
        for await verification in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(verification)
                if transaction.subscriptionGroupID == groupID {
                    return false
                }
            } catch {
                continue
            }
        }
        return true
    }

    public func syncIOS() async throws -> Bool {
        do {
            try await AppStore.sync()
            return true
        } catch {
            throw makePurchaseError(code: .serviceError, message: error.localizedDescription)
        }
    }

    public func presentCodeRedemptionSheetIOS() async throws -> Bool {
        #if canImport(UIKit)
        await MainActor.run {
            SKPaymentQueue.default().presentCodeRedemptionSheet()
        }
        return true
        #else
        throw makePurchaseError(code: .featureNotSupported)
        #endif
    }

    public func showManageSubscriptionsIOS() async throws -> [PurchaseIOS] {
        try await deepLinkToSubscriptions(nil)
        return []
    }

    // MARK: - Event Listener Registration

    public func purchaseUpdatedListener(_ listener: @escaping PurchaseUpdatedListener) -> Subscription {
        let subscription = Subscription(eventType: .purchaseUpdated)
        Task { await state.addPurchaseUpdatedListener((subscription.id, listener)) }
        return subscription
    }

    public func purchaseErrorListener(_ listener: @escaping PurchaseErrorListener) -> Subscription {
        let subscription = Subscription(eventType: .purchaseError)
        Task { await state.addPurchaseErrorListener((subscription.id, listener)) }
        return subscription
    }

    public func promotedProductListenerIOS(_ listener: @escaping PromotedProductListener) -> Subscription {
        let subscription = Subscription(eventType: .promotedProductIos)
        Task { await state.addPromotedProductListener((subscription.id, listener)) }
        return subscription
    }

    public func removeListener(_ subscription: Subscription) {
        Task { await state.removeListener(id: subscription.id, type: subscription.eventType) }
        Task { await MainActor.run { subscription.onRemove?() } }
    }

    public func removeAllListeners() {
        Task { await state.removeAllListeners() }
    }

    // MARK: - Private Helpers

    private func storeProduct(for sku: String) async throws -> StoreKit.Product {
        guard let productManager else {
            let error = makePurchaseError(code: .notPrepared)
            emitPurchaseError(error)
            throw error
        }

        if let product = await productManager.getProduct(productID: sku) {
            return product
        }

        let products = try await StoreKit.Product.products(for: [sku])
        guard let first = products.first else {
            let error = makePurchaseError(code: .skuNotFound, productId: sku)
            emitPurchaseError(error)
            throw error
        }
        await productManager.addProduct(first)
        return first
    }

    private func resolveIosPurchaseProps(from params: RequestPurchaseProps) throws -> RequestPurchaseIosProps {
        switch params.request {
        case let .purchase(platforms):
            if let ios = platforms.ios {
                return ios
            }
        case let .subscription(platforms):
            if let ios = platforms.ios {
                return RequestPurchaseIosProps(
                    andDangerouslyFinishTransactionAutomatically: ios.andDangerouslyFinishTransactionAutomatically,
                    appAccountToken: ios.appAccountToken,
                    quantity: ios.quantity,
                    sku: ios.sku,
                    withOffer: ios.withOffer
                )
            }
        }
        throw makePurchaseError(code: .purchaseError, message: "Missing iOS purchase parameters")
    }

    private func startTransactionListener() {
        updateListenerTask = Task { [weak self] in
            guard let self else { return }
            for await verification in Transaction.updates {
                do {
                    guard await self.state.isInitialized else { continue }
                    let transaction = try self.checkVerified(verification)
                    let transactionId = String(transaction.id)

                    if await self.state.isProcessed(transactionId) {
                        await self.state.unmarkProcessed(transactionId)
                        continue
                    }

                    await self.state.markProcessed(transactionId)
                    await self.state.storePending(id: transactionId, transaction: transaction)
                    let purchase = await StoreKitTypesBridge.purchase(from: transaction, jwsRepresentation: verification.jwsRepresentation)
                    self.emitPurchaseUpdate(purchase)

                    Task {
                        try? await Task.sleep(nanoseconds: 5_000_000_000)
                        await self.state.unmarkProcessed(transactionId)
                    }
                } catch {
                    let purchaseError: PurchaseError
                    if let existing = error as? PurchaseError {
                        purchaseError = existing
                    } else {
                        purchaseError = makePurchaseError(code: .transactionValidationFailed, message: error.localizedDescription)
                    }
                    self.emitPurchaseError(purchaseError)
                }
            }
        }
    }

    private func processUnfinishedTransactions() async {
        for await verification in Transaction.unfinished {
            do {
                let transaction = try checkVerified(verification)
                await state.storePending(id: String(transaction.id), transaction: transaction)
            } catch {
                continue
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value):
            return value
        case .unverified:
            throw makePurchaseError(code: .transactionValidationFailed, message: "Transaction verification failed")
        }
    }

    private func emitPurchaseUpdate(_ purchase: Purchase) {
        Task { [state] in
            let listeners = await state.snapshotPurchaseUpdated()
            await MainActor.run {
                listeners.forEach { $0(purchase) }
            }
        }
    }

    private func emitPurchaseError(_ error: PurchaseError) {
        Task { [state] in
            let listeners = await state.snapshotPurchaseError()
            await MainActor.run {
                listeners.forEach { $0(error) }
            }
        }
    }

    private func emitPromotedProduct(_ sku: String) {
        Task { [state] in
            let listeners = await state.snapshotPromoted()
            await MainActor.run {
                listeners.forEach { $0(sku) }
            }
        }
    }

private func makePurchaseError(code: ErrorCode, productId: String? = nil, message: String? = nil) -> PurchaseError {
        PurchaseError(
            code: code,
            message: message ?? defaultMessage(for: code),
            productId: productId
        )
    }

    private func defaultMessage(for code: ErrorCode) -> String {
        switch code {
        case .unknown: return "Unknown error occurred"
        case .userCancelled: return "User cancelled the purchase flow"
        case .userError: return "User action error"
        case .itemUnavailable: return "Item unavailable"
        case .remoteError: return "Remote service error"
        case .networkError: return "Network connection error"
        case .serviceError: return "Store service error"
        case .receiptFailed: return "Receipt validation failed"
        case .receiptFinished: return "Receipt already finished"
        case .receiptFinishedFailed: return "Receipt finish failed"
        case .notPrepared: return "Billing is not prepared"
        case .notEnded: return "Billing connection not ended"
        case .alreadyOwned: return "Item already owned"
        case .developerError: return "Developer configuration error"
        case .billingResponseJsonParseError: return "Failed to parse billing response"
        case .deferredPayment: return "Payment was deferred (pending approval)"
        case .interrupted: return "Purchase flow interrupted"
        case .iapNotAvailable: return "In-app purchases not available on this device"
        case .purchaseError: return "Purchase error"
        case .syncError: return "Sync error"
        case .transactionValidationFailed: return "Transaction validation failed"
        case .activityUnavailable: return "Required activity is unavailable"
        case .alreadyPrepared: return "Billing already prepared"
        case .pending: return "Transaction pending"
        case .connectionClosed: return "Connection closed"
        case .initConnection: return "Failed to initialize billing connection"
        case .serviceDisconnected: return "Billing service disconnected"
        case .queryProduct: return "Failed to query product"
        case .skuNotFound: return "SKU not found"
        case .skuOfferMismatch: return "SKU offer mismatch"
        case .itemNotOwned: return "Item not owned"
        case .billingUnavailable: return "Billing unavailable"
        case .featureNotSupported: return "Feature not supported on this platform"
        case .emptySkuList: return "Empty SKU list provided"
        }
    }

    @available(iOS 16.0, macOS 14.0, *)
    private func mapAppTransaction(_ transaction: StoreKit.AppTransaction) -> AppTransaction {
        let appVersionId = transaction.appVersionID.map(Double.init) ?? 0
        let appVersion = transaction.appVersion
        let originalPlatform: String?
        if #available(iOS 18.4, macOS 15.4, *) {
            originalPlatform = transaction.originalPlatform.rawValue
        } else {
            originalPlatform = nil
        }

        let appId = transaction.appID.map(Double.init) ?? 0

        return AppTransaction(
            appId: appId,
            appTransactionId: transaction.appTransactionID,
            appVersion: appVersion,
            appVersionId: appVersionId,
            bundleId: transaction.bundleID,
            deviceVerification: transaction.deviceVerification.base64EncodedString(),
            deviceVerificationNonce: transaction.deviceVerificationNonce.uuidString,
            environment: transaction.environment.rawValue,
            originalAppVersion: transaction.originalAppVersion,
            originalPlatform: originalPlatform,
            originalPurchaseDate: transaction.originalPurchaseDate.milliseconds,
            preorderDate: transaction.preorderDate?.milliseconds,
            signedDate: transaction.signedDate.milliseconds
        )
    }
}

#if os(iOS)
extension OpenIapModule: SKPaymentTransactionObserver {
    public func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        // StoreKit 2 handles transactions via Transaction.updates; nothing to do here.
    }

    public func paymentQueue(_ queue: SKPaymentQueue, shouldAddStorePayment payment: SKPayment, for product: SKProduct) -> Bool {
        Task { [weak self] in
            guard let self else { return }
            await self.state.setPromotedProductId(product.productIdentifier)
            self.emitPromotedProduct(product.productIdentifier)
        }
        return false
    }
}
#endif

@available(iOS 15.0, macOS 14.0, *)
private extension Date {
    var milliseconds: Double { timeIntervalSince1970 * 1000 }
}
