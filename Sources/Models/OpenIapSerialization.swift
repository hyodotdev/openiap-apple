import Foundation

@available(iOS 15.0, macOS 14.0, *)
public enum OpenIapSerialization {
    public typealias SerializedObject = [String: Any?]

    public static func serializeProducts(from result: FetchProductsResult) -> [SerializedObject] {
        switch result {
        case .products(let items):
            return (items ?? []).map { serializeProduct($0) }
        case .subscriptions(let items):
            return (items ?? []).map { serializeSubscription($0) }
        }
    }

    public static func serializeProduct(_ product: Product) -> SerializedObject {
        switch product {
        case .productAndroid(let value):
            return serializeProductAndroid(value)
        case .productIos(let value):
            return serializeProductIOS(value)
        }
    }

    public static func serializeSubscription(_ subscription: ProductSubscription) -> SerializedObject {
        switch subscription {
        case .productSubscriptionAndroid(let value):
            return serializeProductAndroid(value)
        case .productSubscriptionIos(let value):
            return serializeSubscriptionIOS(value)
        }
    }

    public static func serializePurchases(_ purchases: [Purchase]) -> [SerializedObject] {
        purchases.map { serializePurchase($0) }
    }

    public static func serializePurchasesIOS(_ purchases: [PurchaseIOS]) -> [SerializedObject] {
        purchases.map { serializePurchaseIOS($0) }
    }

    public static func serializePurchase(_ purchase: Purchase) -> SerializedObject {
        switch purchase {
        case .purchaseAndroid(let value):
            return serializePurchaseAndroid(value)
        case .purchaseIos(let value):
            return serializePurchaseIOS(value)
        }
    }

    public static func serializePurchaseIOS(_ purchase: PurchaseIOS) -> SerializedObject {
        serializePurchaseIOSInternal(purchase)
    }

    public static func serializePurchaseAndroid(_ purchase: PurchaseAndroid) -> SerializedObject {
        serializePurchaseAndroidInternal(purchase)
    }

    // MARK: - Legacy Helpers

    public static func errorCodes() -> [String: String] {
        var mapping: [String: String] = [:]
        for code in ErrorCode.allCases {
            mapping[code.legacyIdentifier] = code.rawValue
        }
        return mapping
    }

    public static func products(_ result: FetchProductsResult) -> [SerializedObject] {
        serializeProducts(from: result)
    }

    public static func products(_ products: [Product]) -> [SerializedObject] {
        products.map { serializeProduct($0) }
    }

    public static func products(_ products: [ProductIOS]) -> [SerializedObject] {
        products.map { serializeProductIOS($0) }
    }

    public static func subscriptions(_ products: [ProductSubscription]) -> [SerializedObject] {
        products.map { serializeSubscription($0) }
    }

    public static func purchases(_ purchases: [Purchase]) -> [SerializedObject] {
        serializePurchases(purchases)
    }

    public static func purchases(_ purchases: [PurchaseIOS]) -> [SerializedObject] {
        serializePurchasesIOS(purchases)
    }

    public static func purchase(_ purchase: Purchase) -> SerializedObject {
        serializePurchase(purchase)
    }

    public static func purchase(_ purchase: PurchaseIOS) -> SerializedObject {
        serializePurchaseIOS(purchase)
    }

    // MARK: - Product Helpers

    private static func serializeProductAndroid(_ product: ProductCommon) -> SerializedObject {
        serializeProductCommon(product)
    }

    private static func serializeProductCommon(_ product: ProductCommon) -> SerializedObject {
        [
            "platform": product.platform.rawValue,
            "currency": product.currency,
            "debugDescription": product.debugDescription,
            "description": product.description,
            "displayName": product.displayName,
            "displayPrice": product.displayPrice,
            "localizedPrice": product.displayPrice,
            "id": product.id,
            "price": product.price,
            "title": product.title,
            "type": normalizedProductType(product.type)
        ]
    }

    private static func serializeProductIOS(_ product: ProductIOS) -> SerializedObject {
        var dict = serializeProductCommon(product)
        dict["platform"] = product.platform.rawValue
        dict["displayNameIOS"] = product.displayNameIOS
        dict["isFamilyShareableIOS"] = product.isFamilyShareableIOS
        dict["isFamilyShareable"] = product.isFamilyShareableIOS
        dict["jsonRepresentationIOS"] = product.jsonRepresentationIOS
        dict["typeIOS"] = normalizedProductTypeIOS(product.typeIOS)
        if let info = product.subscriptionInfoIOS {
            dict.merge(subscriptionInfoFlattenedIOS(info), uniquingKeysWith: { _, new in new })
        }
        return dict
    }

    private static func serializeSubscriptionIOS(_ subscription: ProductSubscriptionIOS) -> SerializedObject {
        var dict: SerializedObject = [
            "platform": subscription.platform.rawValue,
            "currency": subscription.currency,
            "debugDescription": subscription.debugDescription,
            "description": subscription.description,
            "displayName": subscription.displayName,
            "displayNameIOS": subscription.displayNameIOS,
            "displayPrice": subscription.displayPrice,
            "localizedPrice": subscription.displayPrice,
            "id": subscription.id,
            "isFamilyShareableIOS": subscription.isFamilyShareableIOS,
            "isFamilyShareable": subscription.isFamilyShareableIOS,
            "jsonRepresentationIOS": subscription.jsonRepresentationIOS,
            "price": subscription.price,
            "title": subscription.title,
            "type": normalizedProductType(subscription.type),
            "typeIOS": normalizedProductTypeIOS(subscription.typeIOS)
        ]

        if let paymentMode = subscription.introductoryPricePaymentModeIOS {
            dict["introductoryPricePaymentModeIOS"] = normalizedPaymentModeIOS(paymentMode)
        }
        dict["introductoryPriceIOS"] = subscription.introductoryPriceIOS
        dict["introductoryPriceAsAmountIOS"] = subscription.introductoryPriceAsAmountIOS
        dict["introductoryPriceNumberOfPeriodsIOS"] = subscription.introductoryPriceNumberOfPeriodsIOS
        if let period = subscription.introductoryPriceSubscriptionPeriodIOS {
            dict["introductoryPriceSubscriptionPeriodIOS"] = normalizedSubscriptionUnitIOS(period)
        }
        dict["subscriptionPeriodNumberIOS"] = subscription.subscriptionPeriodNumberIOS
        if let unit = subscription.subscriptionPeriodUnitIOS {
            dict["subscriptionPeriodUnitIOS"] = normalizedSubscriptionUnitIOS(unit)
        }

        if let discounts = subscription.discountsIOS, !discounts.isEmpty {
            let serialized = discounts.map { discountDictionaryIOS($0) }
            dict["discounts"] = serialized
            dict["discountsIOS"] = serialized
        }

        if let info = subscription.subscriptionInfoIOS {
            dict.merge(subscriptionInfoFlattenedIOS(info), uniquingKeysWith: { _, new in new })
        }

        return dict
    }

    private static func subscriptionInfoFlattenedIOS(_ info: SubscriptionInfoIOS) -> SerializedObject {
        var flattened: SerializedObject = [:]

        let periodUnit = normalizedSubscriptionUnitIOS(info.subscriptionPeriod.unit)
        flattened["subscriptionPeriodNumberIOS"] = String(info.subscriptionPeriod.value)
        flattened["subscriptionPeriodUnitIOS"] = periodUnit

        if let introductory = info.introductoryOffer {
            flattened["introductoryPriceIOS"] = introductory.displayPrice
            flattened["introductoryPriceAsAmountIOS"] = String(introductory.price)
            flattened["introductoryPricePaymentModeIOS"] = normalizedPaymentModeIOS(introductory.paymentMode)
            flattened["introductoryPriceNumberOfPeriodsIOS"] = String(introductory.periodCount)
            flattened["introductoryPriceSubscriptionPeriodIOS"] = normalizedSubscriptionUnitIOS(introductory.period.unit)
        }

        let discounts = buildDiscountsIOS(from: info)
        if !discounts.isEmpty {
            flattened["discounts"] = discounts
            flattened["discountsIOS"] = discounts
        }

        let infoDict: SerializedObject = [
            "subscriptionGroupId": info.subscriptionGroupId,
            "subscriptionPeriod": [
                "unit": periodUnit as Any,
                "value": info.subscriptionPeriod.value
            ],
            "introductoryOffer": info.introductoryOffer.map { offer -> SerializedObject in
                [
                    "displayPrice": offer.displayPrice,
                    "id": offer.id,
                    "paymentMode": normalizedPaymentModeIOS(offer.paymentMode),
                    "period": [
                        "unit": normalizedSubscriptionUnitIOS(offer.period.unit) as Any,
                        "value": offer.period.value
                    ],
                    "periodCount": offer.periodCount,
                    "price": offer.price,
                    "type": offer.type.rawValue
                ]
            },
            "promotionalOffers": info.promotionalOffers?.map { offer -> SerializedObject in
                [
                    "displayPrice": offer.displayPrice,
                    "id": offer.id,
                    "paymentMode": normalizedPaymentModeIOS(offer.paymentMode),
                    "period": [
                        "unit": normalizedSubscriptionUnitIOS(offer.period.unit) as Any,
                        "value": offer.period.value
                    ],
                    "periodCount": offer.periodCount,
                    "price": offer.price,
                    "type": offer.type.rawValue
                ]
            }
        ]

        flattened["subscriptionInfoIOS"] = infoDict
        return flattened
    }

    private static func buildDiscountsIOS(from info: SubscriptionInfoIOS) -> [SerializedObject] {
        var discounts: [SerializedObject] = []
        if let introductory = info.introductoryOffer {
            discounts.append(discountDictionaryIOS(for: introductory, type: "introductory"))
        }
        if let promos = info.promotionalOffers {
            for offer in promos {
                discounts.append(discountDictionaryIOS(for: offer, type: "promotional"))
            }
        }
        return discounts
    }

    private static func discountDictionaryIOS(for offer: SubscriptionOfferIOS, type: String) -> SerializedObject {
        [
            "identifier": offer.id,
            "type": type,
            "numberOfPeriods": offer.periodCount,
            "price": offer.displayPrice,
            "localizedPrice": offer.displayPrice,
            "priceAmount": offer.price,
            "paymentMode": normalizedPaymentModeIOS(offer.paymentMode),
            "subscriptionPeriod": isoPeriodIOS(from: offer.period)
        ]
    }

    private static func discountDictionaryIOS(_ discount: DiscountIOS) -> SerializedObject {
        [
            "identifier": discount.identifier,
            "type": discount.type,
            "numberOfPeriods": discount.numberOfPeriods,
            "price": discount.price,
            "localizedPrice": discount.localizedPrice,
            "priceAmount": discount.priceAmount,
            "paymentMode": normalizedPaymentModeIOS(discount.paymentMode),
            "subscriptionPeriod": discount.subscriptionPeriod
        ]
    }

    private static func normalizedProductType(_ type: ProductType) -> String {
        type.rawValue.replacingOccurrences(of: "-", with: "_").uppercased()
    }

    private static func normalizedProductTypeIOS(_ type: ProductTypeIOS) -> String {
        type.rawValue.replacingOccurrences(of: "-", with: "_").uppercased()
    }

    private static func normalizedPaymentModeIOS(_ mode: PaymentModeIOS?) -> String? {
        guard let mode else { return nil }
        return mode.rawValue.replacingOccurrences(of: "-", with: "_").uppercased()
    }

    private static func normalizedSubscriptionUnitIOS(_ unit: SubscriptionPeriodIOS?) -> String? {
        guard let unit else { return nil }
        return unit.rawValue.replacingOccurrences(of: "-", with: "_").uppercased()
    }

    private static func isoPeriodIOS(from period: SubscriptionPeriodValueIOS) -> String {
        let value = max(period.value, 0)
        let suffix: String
        switch period.unit {
        case .day, .empty: suffix = "D"
        case .week: suffix = "W"
        case .month: suffix = "M"
        case .year: suffix = "Y"
        }
        return "P\(value)\(suffix)"
    }

    // MARK: - Purchase Helpers

    private static func serializePurchaseIOSInternal(_ purchase: PurchaseIOS) -> SerializedObject {
        var dict: SerializedObject = [
            "platform": purchase.platform.rawValue,
            "id": purchase.id,
            "ids": purchase.ids,
            "productId": purchase.productId,
            "transactionId": purchase.transactionId,
            "transactionDate": purchase.transactionDate,
            "purchaseToken": purchase.purchaseToken ?? purchase.transactionId,
            "quantity": purchase.quantity,
            "quantityIOS": purchase.quantityIOS,
            "purchaseState": purchase.purchaseState.rawValue,
            "isAutoRenewing": purchase.isAutoRenewing,
            "appAccountToken": purchase.appAccountToken,
            "appBundleIdIOS": purchase.appBundleIdIOS,
            "countryCodeIOS": purchase.countryCodeIOS,
            "currencyCodeIOS": purchase.currencyCodeIOS,
            "currencySymbolIOS": purchase.currencySymbolIOS,
            "environmentIOS": purchase.environmentIOS,
            "expirationDateIOS": purchase.expirationDateIOS,
            "originalTransactionDateIOS": purchase.originalTransactionDateIOS,
            "originalTransactionIdentifierIOS": purchase.originalTransactionIdentifierIOS,
            "ownershipTypeIOS": purchase.ownershipTypeIOS,
            "reasonIOS": purchase.reasonIOS,
            "reasonStringRepresentationIOS": purchase.reasonStringRepresentationIOS,
            "storefrontCountryCodeIOS": purchase.storefrontCountryCodeIOS,
            "subscriptionGroupIdIOS": purchase.subscriptionGroupIdIOS,
            "transactionReasonIOS": purchase.transactionReasonIOS,
            "webOrderLineItemIdIOS": purchase.webOrderLineItemIdIOS,
            "isUpgradedIOS": purchase.isUpgradedIOS,
            "revocationDateIOS": purchase.revocationDateIOS,
            "revocationReasonIOS": purchase.revocationReasonIOS
        ]

        if let offer = purchase.offerIOS {
            dict["offerIOS"] = [
                "id": offer.id,
                "type": offer.type,
                "paymentMode": offer.paymentMode.replacingOccurrences(of: "-", with: "_").uppercased()
            ]
        }

        return dict
    }

    private static func serializePurchaseAndroidInternal(_ purchase: PurchaseAndroid) -> SerializedObject {
        [
            "platform": purchase.platform.rawValue,
            "id": purchase.id,
            "ids": purchase.ids,
            "productId": purchase.productId,
            "transactionId": purchase.transactionId,
            "transactionDate": purchase.transactionDate,
            "purchaseToken": purchase.purchaseToken,
            "quantity": purchase.quantity,
            "purchaseState": purchase.purchaseState.rawValue,
            "isAutoRenewing": purchase.isAutoRenewing
        ]
    }
}

@available(iOS 15.0, macOS 14.0, *)
public enum OpenIapBuilder {
    private static func decode<T: Decodable, Payload: Encodable>(_: T.Type, from payload: Payload) throws -> T {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(payload)
        return try decoder.decode(T.self, from: data)
    }

    public static func productRequest(skus: [String], type: ProductQueryType?) throws -> ProductRequest {
        struct Payload: Encodable {
            let skus: [String]
            let type: ProductQueryType?
        }
        return try decode(ProductRequest.self, from: Payload(skus: skus, type: type))
    }

    public static func purchaseOptions(alsoPublishToEventListenerIOS: Bool?, onlyIncludeActiveItemsIOS: Bool?) throws -> PurchaseOptions {
        struct Payload: Encodable {
            let alsoPublishToEventListenerIOS: Bool?
            let onlyIncludeActiveItemsIOS: Bool?
        }
        return try decode(
            PurchaseOptions.self,
            from: Payload(
                alsoPublishToEventListenerIOS: alsoPublishToEventListenerIOS,
                onlyIncludeActiveItemsIOS: onlyIncludeActiveItemsIOS
            )
        )
    }

    public static func discountOfferIOS(
        identifier: String,
        keyIdentifier: String,
        nonce: String,
        signature: String,
        timestamp: Double
    ) throws -> DiscountOfferInputIOS {
        struct Payload: Encodable {
            let identifier: String
            let keyIdentifier: String
            let nonce: String
            let signature: String
            let timestamp: Double
        }
        return try decode(
            DiscountOfferInputIOS.self,
            from: Payload(
                identifier: identifier,
                keyIdentifier: keyIdentifier,
                nonce: nonce,
                signature: signature,
                timestamp: timestamp
            )
        )
    }

    public static func requestPurchasePropsIOS(
        autoFinish: Bool?,
        appAccountToken: String?,
        quantity: Int?,
        sku: String,
        offer: DiscountOfferInputIOS?
    ) throws -> RequestPurchaseIosProps {
        struct Payload: Encodable {
            let andDangerouslyFinishTransactionAutomatically: Bool?
            let appAccountToken: String?
            let quantity: Int?
            let sku: String
            let withOffer: DiscountOfferInputIOS?
        }
        return try decode(
            RequestPurchaseIosProps.self,
            from: Payload(
                andDangerouslyFinishTransactionAutomatically: autoFinish,
                appAccountToken: appAccountToken,
                quantity: quantity,
                sku: sku,
                withOffer: offer
            )
        )
    }

    public static func requestSubscriptionPropsIOS(
        autoFinish: Bool?,
        appAccountToken: String?,
        quantity: Int?,
        sku: String,
        offer: DiscountOfferInputIOS?
    ) throws -> RequestSubscriptionIosProps {
        struct Payload: Encodable {
            let andDangerouslyFinishTransactionAutomatically: Bool?
            let appAccountToken: String?
            let quantity: Int?
            let sku: String
            let withOffer: DiscountOfferInputIOS?
        }
        return try decode(
            RequestSubscriptionIosProps.self,
            from: Payload(
                andDangerouslyFinishTransactionAutomatically: autoFinish,
                appAccountToken: appAccountToken,
                quantity: quantity,
                sku: sku,
                withOffer: offer
            )
        )
    }

    public static func requestPurchaseProps(
        type: ProductQueryType,
        purchase: RequestPurchaseIosProps?,
        subscription: RequestSubscriptionIosProps?
    ) throws -> RequestPurchaseProps {
        struct Payload: Encodable {
            let requestPurchase: RequestPurchasePropsByPlatforms?
            let requestSubscription: RequestSubscriptionPropsByPlatforms?
            let type: ProductQueryType
        }

        let purchasePlatforms = try requestPurchasePlatforms(ios: purchase)
        let subscriptionPlatforms = try requestSubscriptionPlatforms(ios: subscription)

        return try decode(
            RequestPurchaseProps.self,
            from: Payload(
                requestPurchase: purchasePlatforms,
                requestSubscription: subscriptionPlatforms,
                type: type
            )
        )
    }

    public static func purchaseInput(
        id: String,
        ids: [String]?,
        isAutoRenewing: Bool,
        platform: IapPlatform,
        productId: String,
        purchaseState: PurchaseState,
        purchaseToken: String?,
        quantity: Int,
        transactionDate: Double
    ) throws -> PurchaseInput {
        struct Payload: Encodable {
            let id: String
            let ids: [String]?
            let isAutoRenewing: Bool
            let platform: IapPlatform
            let productId: String
            let purchaseState: PurchaseState
            let purchaseToken: String?
            let quantity: Int
            let transactionDate: Double
        }
        return try decode(
            PurchaseInput.self,
            from: Payload(
                id: id,
                ids: ids,
                isAutoRenewing: isAutoRenewing,
                platform: platform,
                productId: productId,
                purchaseState: purchaseState,
                purchaseToken: purchaseToken,
                quantity: quantity,
                transactionDate: transactionDate
            )
        )
    }

    public static func receiptValidationProps(sku: String) throws -> ReceiptValidationProps {
        struct Payload: Encodable {
            let androidOptions: ReceiptValidationAndroidOptions?
            let sku: String
        }
        return try decode(
            ReceiptValidationProps.self,
            from: Payload(androidOptions: nil, sku: sku)
        )
    }

    private static func requestPurchasePlatforms(ios: RequestPurchaseIosProps?) throws -> RequestPurchasePropsByPlatforms? {
        guard let ios else { return nil }
        struct Payload: Encodable {
            let android: RequestPurchaseAndroidProps?
            let ios: RequestPurchaseIosProps
        }
        return try decode(
            RequestPurchasePropsByPlatforms.self,
            from: Payload(android: nil, ios: ios)
        )
    }

    private static func requestSubscriptionPlatforms(ios: RequestSubscriptionIosProps?) throws -> RequestSubscriptionPropsByPlatforms? {
        guard let ios else { return nil }
        struct Payload: Encodable {
            let android: RequestSubscriptionAndroidProps?
            let ios: RequestSubscriptionIosProps
        }
        return try decode(
            RequestSubscriptionPropsByPlatforms.self,
            from: Payload(android: nil, ios: ios)
        )
    }
}
