import Foundation
import StoreKit

// MARK: - Objective-C Bridge for Kotlin Multiplatform

@available(iOS 15.0, macOS 14.0, *)
@objc public extension OpenIapModule {

    // MARK: - Connection Management

    @objc func initConnectionWithCompletion(_ completion: @escaping (Bool, Error?) -> Void) {
        Task {
            do {
                let result = try await initConnection()
                completion(result, nil)
            } catch {
                completion(false, error)
            }
        }
    }

    @objc func endConnectionWithCompletion(_ completion: @escaping (Bool, Error?) -> Void) {
        Task {
            do {
                let result = try await endConnection()
                completion(result, nil)
            } catch {
                completion(false, error)
            }
        }
    }

    // MARK: - Product Management

    @objc func fetchProductsWithSkus(
        _ skus: [String],
        type: String?,
        completion: @escaping ([Any]?, Error?) -> Void
    ) {
        Task {
            do {
                let productType = type.flatMap { ProductQueryType(rawValue: $0) }
                let request = ProductRequest(skus: skus, type: productType)
                let result = try await fetchProducts(request)

                switch result {
                case .products(let products):
                    // Extract ProductIOS from Product enum and convert to dictionaries
                    let productIOS = (products ?? []).compactMap { product -> ProductIOS? in
                        guard case let .productIos(value) = product else { return nil }
                        return value
                    }
                    print("[OpenIAP] Fetched \(productIOS.count) products")
                    let dictionaries = productIOS.map { OpenIapSerialization.encode($0) }
                    completion(dictionaries, nil)

                case .subscriptions(let subscriptions):
                    // Extract ProductSubscriptionIOS from ProductSubscription enum and convert to dictionaries
                    let subscriptionIOS = (subscriptions ?? []).compactMap { subscription -> ProductSubscriptionIOS? in
                        guard case let .productSubscriptionIos(value) = subscription else { return nil }
                        return value
                    }
                    print("[OpenIAP] Fetched \(subscriptionIOS.count) subscriptions")
                    let dictionaries = subscriptionIOS.map { OpenIapSerialization.encode($0) }
                    completion(dictionaries, nil)
                }
            } catch {
                completion(nil, error)
            }
        }
    }

    @objc func getPromotedProductIOSWithCompletion(_ completion: @escaping (Any?, Error?) -> Void) {
        Task {
            do {
                let product = try await getPromotedProductIOS()
                if let productIOS = product {
                    // Convert ProductIOS to dictionary
                    let dictionary = OpenIapSerialization.encode(productIOS)
                    completion(dictionary, nil)
                } else {
                    completion(nil, nil)
                }
            } catch {
                completion(nil, error)
            }
        }
    }

    // MARK: - Purchase Management

    @objc func requestPurchaseWithSku(
        _ sku: String,
        quantity: Int,
        type: String?,
        completion: @escaping (Any?, Error?) -> Void
    ) {
        Task {
            do {
                // For purchase request, type must be .inApp
                let iosProps = RequestPurchaseIosProps(
                    andDangerouslyFinishTransactionAutomatically: nil,
                    appAccountToken: nil,
                    quantity: quantity,
                    sku: sku,
                    withOffer: nil
                )
                let props = RequestPurchaseProps(
                    request: .purchase(
                        RequestPurchasePropsByPlatforms(android: nil, ios: iosProps)
                    ),
                    type: .inApp
                )

                let result = try await requestPurchase(props)

                switch result {
                case .purchase(let purchase):
                    if let purchase = purchase {
                        let dictionary = OpenIapSerialization.purchase(purchase)
                        completion(dictionary, nil)
                    } else {
                        completion(nil, nil)
                    }
                case .purchases(let purchases):
                    if let firstPurchase = purchases?.first {
                        let dictionary = OpenIapSerialization.purchase(firstPurchase)
                        completion(dictionary, nil)
                    } else {
                        completion(nil, nil)
                    }
                case .none:
                    completion(nil, nil)
                }
            } catch {
                completion(nil, error)
            }
        }
    }

    @objc func requestSubscriptionWithSku(
        _ sku: String,
        offer: [String: Any]?,
        completion: @escaping (Any?, Error?) -> Void
    ) {
        Task {
            do {
                // For subscription request, type must be .subs
                let discountOffer: DiscountOfferInputIOS? = if let offer = offer,
                    let identifier = offer["identifier"] as? String,
                    let keyIdentifier = offer["keyIdentifier"] as? String,
                    let nonce = offer["nonce"] as? String,
                    let signature = offer["signature"] as? String,
                    let timestamp = offer["timestamp"] as? Double {
                    DiscountOfferInputIOS(
                        identifier: identifier,
                        keyIdentifier: keyIdentifier,
                        nonce: nonce,
                        signature: signature,
                        timestamp: timestamp
                    )
                } else {
                    nil
                }

                let iosProps = RequestSubscriptionIosProps(
                    andDangerouslyFinishTransactionAutomatically: nil,
                    appAccountToken: nil,
                    sku: sku,
                    withOffer: discountOffer
                )
                let props = RequestPurchaseProps(
                    request: .subscription(
                        RequestSubscriptionPropsByPlatforms(android: nil, ios: iosProps)
                    ),
                    type: .subs
                )

                let result = try await requestPurchase(props)

                switch result {
                case .purchase(let purchase):
                    if let purchase = purchase {
                        let dictionary = OpenIapSerialization.purchase(purchase)
                        completion(dictionary, nil)
                    } else {
                        completion(nil, nil)
                    }
                case .purchases(let purchases):
                    if let firstPurchase = purchases?.first {
                        let dictionary = OpenIapSerialization.purchase(firstPurchase)
                        completion(dictionary, nil)
                    } else {
                        completion(nil, nil)
                    }
                case .none:
                    completion(nil, nil)
                }
            } catch {
                completion(nil, error)
            }
        }
    }

    @objc func restorePurchasesWithCompletion(_ completion: @escaping (Error?) -> Void) {
        Task {
            do {
                try await restorePurchases()
                completion(nil)
            } catch {
                completion(error)
            }
        }
    }

    @objc func getAvailablePurchasesWithCompletion(_ completion: @escaping ([Any]?, Error?) -> Void) {
        Task {
            do {
                let purchases = try await getAvailablePurchases(nil)
                let dictionaries = OpenIapSerialization.purchases(purchases)
                completion(dictionaries, nil)
            } catch {
                completion(nil, error)
            }
        }
    }

    // MARK: - Transaction Management

    @objc func finishTransactionWithPurchaseId(
        _ purchaseId: String,
        productId: String,
        isConsumable: Bool,
        completion: @escaping (Error?) -> Void
    ) {
        Task {
            do {
                // Try to find the actual transaction from pending transactions
                let pendingTransactions = try await getPendingTransactionsIOS()

                // Use full transaction data if available in pending
                if let purchaseIOS = pendingTransactions.first(where: {
                    $0.transactionId == purchaseId || $0.id == purchaseId
                }) {
                    let purchaseInput = Purchase.purchaseIos(purchaseIOS)
                    try await finishTransaction(purchase: purchaseInput, isConsumable: isConsumable)
                    completion(nil)
                    return
                }

                // Not in pending - finishTransaction will search currentEntitlements
                // Create minimal PurchaseIOS (only purchase.id is used by finishTransaction)
                let minimalPurchase = PurchaseIOS(
                    appAccountToken: nil,
                    appBundleIdIOS: nil,
                    countryCodeIOS: nil,
                    currencyCodeIOS: nil,
                    currencySymbolIOS: nil,
                    currentPlanId: nil,
                    environmentIOS: nil,
                    expirationDateIOS: nil,
                    id: purchaseId,
                    ids: nil,
                    isAutoRenewing: false,
                    isUpgradedIOS: nil,
                    offerIOS: nil,
                    originalTransactionDateIOS: nil,
                    originalTransactionIdentifierIOS: nil,
                    ownershipTypeIOS: nil,
                    platform: .ios,
                    productId: productId,
                    purchaseState: .purchased,
                    purchaseToken: nil,
                    quantity: 1,
                    quantityIOS: nil,
                    reasonIOS: nil,
                    reasonStringRepresentationIOS: nil,
                    revocationDateIOS: nil,
                    revocationReasonIOS: nil,
                    storefrontCountryCodeIOS: nil,
                    subscriptionGroupIdIOS: nil,
                    transactionDate: Date().timeIntervalSince1970,
                    transactionId: purchaseId,
                    transactionReasonIOS: nil,
                    webOrderLineItemIdIOS: nil
                )
                let purchaseInput = Purchase.purchaseIos(minimalPurchase)
                try await finishTransaction(purchase: purchaseInput, isConsumable: isConsumable)
                completion(nil)
            } catch {
                completion(error)
            }
        }
    }

    @objc func getPendingTransactionsIOSWithCompletion(_ completion: @escaping ([Any]?, Error?) -> Void) {
        Task {
            do {
                let transactions = try await getPendingTransactionsIOS()
                // Convert [PurchaseIOS] to dictionaries directly
                let dictionaries = transactions.map { OpenIapSerialization.encode($0) }
                completion(dictionaries, nil)
            } catch {
                completion(nil, error)
            }
        }
    }

    @objc func clearTransactionIOSWithCompletion(_ completion: @escaping (Bool, Error?) -> Void) {
        Task {
            do {
                let result = try await clearTransactionIOS()
                completion(result, nil)
            } catch {
                completion(false, error)
            }
        }
    }

    // MARK: - Validation

    @objc func getReceiptDataIOSWithCompletion(_ completion: @escaping (String?, Error?) -> Void) {
        Task {
            do {
                let receipt = try await getReceiptDataIOS()
                completion(receipt, nil)
            } catch {
                completion(nil, error)
            }
        }
    }

    // MARK: - Store Information

    @objc func getStorefrontIOSWithCompletion(_ completion: @escaping (String?, Error?) -> Void) {
        Task {
            do {
                let storefront = try await getStorefrontIOS()
                completion(storefront, nil)
            } catch {
                completion(nil, error)
            }
        }
    }

    // MARK: - Subscription Management

    @objc func getActiveSubscriptionsWithCompletion(_ completion: @escaping ([Any]?, Error?) -> Void) {
        Task {
            do {
                let subscriptions = try await getActiveSubscriptions(nil)
                let dictionaries = subscriptions.map { OpenIapSerialization.encode($0) }
                completion(dictionaries, nil)
            } catch {
                completion(nil, error)
            }
        }
    }

    @objc func hasActiveSubscriptionsWithCompletion(_ completion: @escaping (Bool, Error?) -> Void) {
        Task {
            do {
                let hasActive = try await hasActiveSubscriptions(nil)
                completion(hasActive, nil)
            } catch {
                completion(false, error)
            }
        }
    }

    @objc func subscriptionStatusIOSWithSku(_ sku: String, completion: @escaping ([Any]?, Error?) -> Void) {
        Task {
            do {
                let statuses = try await subscriptionStatusIOS(sku: sku)
                let dictionaries = statuses.map { OpenIapSerialization.encode($0) }
                completion(dictionaries, nil)
            } catch {
                completion(nil, error)
            }
        }
    }

    @objc func currentEntitlementIOSWithSku(_ sku: String, completion: @escaping (Any?, Error?) -> Void) {
        Task {
            do {
                let purchase = try await currentEntitlementIOS(sku: sku)
                if let purchaseIOS = purchase {
                    let dictionary = OpenIapSerialization.encode(purchaseIOS)
                    completion(dictionary, nil)
                } else {
                    completion(nil, nil)
                }
            } catch {
                completion(nil, error)
            }
        }
    }

    @objc func latestTransactionIOSWithSku(_ sku: String, completion: @escaping (Any?, Error?) -> Void) {
        Task {
            do {
                let purchase = try await latestTransactionIOS(sku: sku)
                if let purchaseIOS = purchase {
                    let dictionary = OpenIapSerialization.encode(purchaseIOS)
                    completion(dictionary, nil)
                } else {
                    completion(nil, nil)
                }
            } catch {
                completion(nil, error)
            }
        }
    }

    @objc func isEligibleForIntroOfferIOSWithGroupID(_ groupID: String, completion: @escaping (Bool, Error?) -> Void) {
        Task {
            do {
                let isEligible = try await isEligibleForIntroOfferIOS(groupID: groupID)
                completion(isEligible, nil)
            } catch {
                completion(false, error)
            }
        }
    }

    @objc func isTransactionVerifiedIOSWithSku(_ sku: String, completion: @escaping (Bool, Error?) -> Void) {
        Task {
            do {
                let isVerified = try await isTransactionVerifiedIOS(sku: sku)
                completion(isVerified, nil)
            } catch {
                completion(false, error)
            }
        }
    }

    @objc func getTransactionJwsIOSWithSku(_ sku: String, completion: @escaping (String?, Error?) -> Void) {
        Task {
            do {
                let jws = try await getTransactionJwsIOS(sku: sku)
                completion(jws, nil)
            } catch {
                completion(nil, error)
            }
        }
    }

    @available(iOS 16.0, macOS 14.0, *)
    @objc func getAppTransactionIOSWithCompletion(_ completion: @escaping (Any?, Error?) -> Void) {
        Task {
            do {
                let transaction = try await getAppTransactionIOS()
                if let appTransaction = transaction {
                    let dictionary = OpenIapSerialization.encode(appTransaction)
                    completion(dictionary, nil)
                } else {
                    completion(nil, nil)
                }
            } catch {
                completion(nil, error)
            }
        }
    }

    // MARK: - UI

    @objc func presentCodeRedemptionSheetIOSWithCompletion(_ completion: @escaping (Bool, Error?) -> Void) {
        Task {
            do {
                let result = try await presentCodeRedemptionSheetIOS()
                completion(result, nil)
            } catch {
                completion(false, error)
            }
        }
    }

    @objc func showManageSubscriptionsIOSWithCompletion(_ completion: @escaping ([Any]?, Error?) -> Void) {
        Task {
            do {
                let purchases = try await showManageSubscriptionsIOS()
                // Convert [PurchaseIOS] to dictionaries directly
                let dictionaries = purchases.map { OpenIapSerialization.encode($0) }
                completion(dictionaries, nil)
            } catch {
                completion(nil, error)
            }
        }
    }

    @available(iOS 16.0, macOS 14.0, *)
    @objc func presentExternalPurchaseLinkIOSWithUrl(_ url: String, completion: @escaping (Any?, Error?) -> Void) {
        Task {
            do {
                let result = try await presentExternalPurchaseLinkIOS(url)
                let dictionary = OpenIapSerialization.encode(result)
                completion(dictionary, nil)
            } catch {
                completion(nil, error)
            }
        }
    }

    @available(iOS 17.4, macOS 14.4, *)
    @objc func presentExternalPurchaseNoticeSheetIOSWithCompletion(_ completion: @escaping (Any?, Error?) -> Void) {
        Task {
            do {
                let result = try await presentExternalPurchaseNoticeSheetIOS()
                let dictionary = OpenIapSerialization.encode(result)
                completion(dictionary, nil)
            } catch {
                completion(nil, error)
            }
        }
    }

    @available(iOS 17.4, macOS 14.4, *)
    @objc func canPresentExternalPurchaseNoticeIOSWithCompletion(_ completion: @escaping (Bool, Error?) -> Void) {
        Task {
            do {
                let canPresent = try await canPresentExternalPurchaseNoticeIOS()
                completion(canPresent, nil)
            } catch {
                completion(false, error)
            }
        }
    }

    // MARK: - Event Listeners

    @objc func addPurchaseUpdatedListener(_ callback: @escaping (NSDictionary) -> Void) -> NSObject {
        let subscription = purchaseUpdatedListener { purchase in
            let dictionary = OpenIapSerialization.purchase(purchase)
            callback(dictionary as NSDictionary)
        }
        return subscription as NSObject
    }

    @objc func addPurchaseErrorListener(_ callback: @escaping (NSDictionary) -> Void) -> NSObject {
        let subscription = purchaseErrorListener { error in
            let dictionary = OpenIapSerialization.encode(error)
            callback(dictionary as NSDictionary)
        }
        return subscription as NSObject
    }

    @objc func addPromotedProductListener(_ callback: @escaping (String?) -> Void) -> NSObject {
        let subscription = promotedProductListenerIOS { sku in
            callback(sku)
        }
        return subscription as NSObject
    }

    @objc func removeListener(_ subscription: NSObject) {
        if let sub = subscription as? Subscription {
            removeListener(sub)
        }
    }

    @objc func removeAllListenersObjC() {
        removeAllListeners()
    }
}