import Foundation

/// Utilities to serialize OpenIAP models into dictionary payloads
/// for easy bridging to JavaScript/React Native or analytics.
/// These functions are pure and not MainActor-isolated.
@available(iOS 15.0, macOS 12.0, *)
public enum OpenIapSerialization {
    /// Serialize a product into a dictionary reflecting the OpenIAP spec fields
    @inlinable
    public static func product(_ product: OpenIapProduct) -> [String: Any?] {
        return [
            "platform": "ios",
            "id": product.id,
            "title": product.title,
            "description": product.description,
            "price": product.price ?? 0,
            "localizedPrice": product.displayPrice,
            "currency": product.currency,
            "type": product.type,
            "displayPrice": product.displayPrice,
            "displayName": product.displayName,
            "jsonRepresentationIOS": product.jsonRepresentationIOS,
            "isFamilyShareable": product.isFamilyShareableIOS,
            // Subscription fields (iOS)
            "subscriptionPeriodNumberIOS": product.subscriptionInfoIOS?.subscriptionPeriod.value ?? 0,
            "subscriptionPeriodUnitIOS": product.subscriptionInfoIOS?.subscriptionPeriod.unit.rawValue,
            "introductoryPricePaymentModeIOS": product.subscriptionInfoIOS?.introductoryOffer?.paymentMode.rawValue,
            "introductoryPriceNumberOfPeriodsIOS": product.subscriptionInfoIOS?.introductoryOffer?.periodCount ?? 0,
            "introductoryPriceSubscriptionPeriodIOS": product.subscriptionInfoIOS?.introductoryOffer?.period.unit.rawValue,
            // Android placeholders kept for schema parity
            "subscriptionPeriodAndroid": nil,
            "subscriptionPeriodUnitAndroid": nil,
            "introductoryPriceCyclesAndroid": nil,
            "introductoryPricePeriodAndroid": nil,
            "freeTrialPeriodAndroid": nil,
            // Discounts list (iOS)
            "discounts": product.discountsIOS?.map { discount in
                [
                    "identifier": discount.identifier,
                    "type": discount.type,
                    "numberOfPeriods": discount.numberOfPeriods,
                    "price": discount.priceAmount,
                    "localizedPrice": discount.price,
                    "paymentMode": discount.paymentMode,
                    "subscriptionPeriod": discount.subscriptionPeriod
                ]
            }
        ]
    }

    /// Serialize a purchase into a dictionary reflecting the OpenIAP spec fields
    @inlinable
    public static func purchase(_ purchase: OpenIapPurchase) -> [String: Any?] {
        return [
            "platform": "ios",
            "id": purchase.id,
            "productId": purchase.productId,
            "transactionDate": purchase.transactionDate,
            "transactionReceipt": purchase.transactionReceipt,
            "purchaseToken": purchase.purchaseToken,
            "quantity": purchase.quantity,
            "purchaseState": purchase.purchaseState.rawValue,
            "isAutoRenewing": purchase.isAutoRenewing,
            // iOS specific fields
            "quantityIOS": purchase.quantityIOS,
            "originalTransactionDateIOS": purchase.originalTransactionDateIOS,
            "originalTransactionIdentifierIOS": purchase.originalTransactionIdentifierIOS,
            "appAccountToken": purchase.appAccountToken,
            "expirationDateIOS": purchase.expirationDateIOS,
            "webOrderLineItemIdIOS": purchase.webOrderLineItemIdIOS,
            "environmentIOS": purchase.environmentIOS,
            "storefrontCountryCodeIOS": purchase.storefrontCountryCodeIOS,
            "appBundleIdIOS": purchase.appBundleIdIOS,
            "productTypeIOS": purchase.productTypeIOS,
            "subscriptionGroupIdIOS": purchase.subscriptionGroupIdIOS,
            "isUpgradedIOS": purchase.isUpgradedIOS,
            "ownershipTypeIOS": purchase.ownershipTypeIOS,
            "reasonIOS": purchase.reasonIOS,
            "reasonStringRepresentationIOS": purchase.reasonStringRepresentationIOS,
            "transactionReasonIOS": purchase.transactionReasonIOS,
            "revocationDateIOS": purchase.revocationDateIOS,
            "revocationReasonIOS": purchase.revocationReasonIOS,
            "offerIOS": purchase.offerIOS.map { [
                "id": $0.id,
                "type": $0.type,
                "paymentMode": $0.paymentMode
            ]},
            "currencyCodeIOS": purchase.currencyCodeIOS,
            "currencySymbolIOS": purchase.currencySymbolIOS,
            "countryCodeIOS": purchase.countryCodeIOS
        ]
    }

    /// Serialize a list of products
    @inlinable
    public static func products(_ items: [OpenIapProduct]) -> [[String: Any?]] {
        return items.map { product($0) }
    }

    /// Serialize a list of purchases
    @inlinable
    public static func purchases(_ items: [OpenIapPurchase]) -> [[String: Any?]] {
        return items.map { purchase($0) }
    }

    /// Error code map for bridging to JavaScript/TypeScript constants
    @inlinable
    public static func errorCodes() -> [String: String] {
        return OpenIapError.errorCodes()
    }

    /// Default messages for each error code (code -> message)
    @inlinable
    public static func errorMessages() -> [String: String] {
        let codes = OpenIapError.errorCodes().values
        var map: [String: String] = [:]
        for code in codes {
            map[code] = PurchaseError.defaultMessage(for: code)
        }
        return map
    }
}
