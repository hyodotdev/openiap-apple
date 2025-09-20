import XCTest
@testable import OpenIAP

final class OpenIapTests: XCTestCase {

    func testProductIOS() {
        let product = makeSampleProduct()
        XCTAssertEqual(product.id, "dev.hyo.premium")
        XCTAssertEqual(product.platform, .ios)
        XCTAssertEqual(product.price, 9.99)
        XCTAssertEqual(product.subscriptionInfoIOS?.subscriptionGroupId, "group")
    }

    func testPurchaseIOS() {
        let purchase = makeSamplePurchase()
        XCTAssertEqual(purchase.productId, "dev.hyo.premium")
        XCTAssertEqual(purchase.platform, .ios)
        XCTAssertEqual(purchase.purchaseState, .purchased)
    }

    func testPurchaseErrorStruct() {
        let error = PurchaseError(code: .skuNotFound, message: "Not found", productId: "sku")
        XCTAssertEqual(error.code, .skuNotFound)
        XCTAssertEqual(error.message, "Not found")
        XCTAssertEqual(error.productId, "sku")
    }

    func testProductRequestEncoding() throws {
        let request = ProductRequest(skus: ["sku1", "sku2"], type: .inApp)
        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(ProductRequest.self, from: data)
        XCTAssertEqual(decoded.skus.count, 2)
        XCTAssertEqual(decoded.type, .inApp)
    }

    func testPurchaseErrorDefaultMessage() {
        XCTAssertEqual(PurchaseError.defaultMessage(for: .skuNotFound), "SKU not found")
        XCTAssertEqual(PurchaseError.defaultMessage(for: "billing-unavailable"), "Billing unavailable")
        XCTAssertEqual(PurchaseError.defaultMessage(for: "unknown-code"), "Unknown error occurred")
    }

    func testPurchaseErrorMakeProvidesDefaultMessage() {
        let error = PurchaseError.make(code: .userCancelled, productId: "sku", message: nil)
        XCTAssertEqual(error.message, "User cancelled the purchase flow")
    }

    // MARK: - Helpers

    private func makeSampleProduct() -> ProductIOS {
        let subscriptionPeriod = SubscriptionPeriodValueIOS(unit: .month, value: 1)
        let offer = SubscriptionOfferIOS(
            displayPrice: "$0.00",
            id: "intro",
            paymentMode: .freeTrial,
            period: subscriptionPeriod,
            periodCount: 1,
            price: 0,
            type: .introductory
        )
        let subscriptionInfo = SubscriptionInfoIOS(
            introductoryOffer: offer,
            promotionalOffers: nil,
            subscriptionGroupId: "group",
            subscriptionPeriod: subscriptionPeriod
        )

        return ProductIOS(
            currency: "USD",
            debugDescription: "",
            description: "Premium subscription",
            displayName: "Premium",
            displayNameIOS: "Premium",
            displayPrice: "$9.99",
            id: "dev.hyo.premium",
            isFamilyShareableIOS: true,
            jsonRepresentationIOS: "{}",
            platform: .ios,
            price: 9.99,
            subscriptionInfoIOS: subscriptionInfo,
            title: "Premium",
            type: .subs,
            typeIOS: .autoRenewableSubscription
        )
    }

    private func makeSamplePurchase() -> PurchaseIOS {
        PurchaseIOS(
            appAccountToken: nil,
            appBundleIdIOS: "dev.hyo.app",
            countryCodeIOS: "US",
            currencyCodeIOS: "USD",
            currencySymbolIOS: "$",
            environmentIOS: "Production",
            expirationDateIOS: nil,
            id: "transaction",
            ids: ["transaction"],
            isAutoRenewing: false,
            isUpgradedIOS: false,
            offerIOS: nil,
            originalTransactionDateIOS: 1,
            originalTransactionIdentifierIOS: "origin",
            ownershipTypeIOS: "purchased",
            platform: .ios,
            productId: "dev.hyo.premium",
            purchaseState: .purchased,
            purchaseToken: "token",
            quantity: 1,
            quantityIOS: 1,
            reasonIOS: "purchase",
            reasonStringRepresentationIOS: "purchase",
            revocationDateIOS: nil,
            revocationReasonIOS: nil,
            storefrontCountryCodeIOS: "US",
            subscriptionGroupIdIOS: "group",
            transactionDate: 2,
            transactionId: "transaction",
            transactionReasonIOS: "PURCHASE",
            webOrderLineItemIdIOS: nil
        )
    }

    private func makeSampleSubscription() -> ProductSubscriptionIOS {
        let subscriptionPeriod = SubscriptionPeriodValueIOS(unit: .month, value: 1)
        let offer = SubscriptionOfferIOS(
            displayPrice: "$0.00",
            id: "intro",
            paymentMode: .freeTrial,
            period: subscriptionPeriod,
            periodCount: 1,
            price: 0,
            type: .introductory
        )
        let info = SubscriptionInfoIOS(
            introductoryOffer: offer,
            promotionalOffers: nil,
            subscriptionGroupId: "group",
            subscriptionPeriod: subscriptionPeriod
        )

        return ProductSubscriptionIOS(
            currency: "USD",
            debugDescription: "",
            description: "Premium subscription",
            discountsIOS: nil,
            displayName: "Premium",
            displayNameIOS: "Premium",
            displayPrice: "$9.99",
            id: "dev.hyo.premium",
            introductoryPriceAsAmountIOS: "0",
            introductoryPriceIOS: "$0.00",
            introductoryPriceNumberOfPeriodsIOS: "1",
            introductoryPricePaymentModeIOS: .freeTrial,
            introductoryPriceSubscriptionPeriodIOS: .month,
            isFamilyShareableIOS: true,
            jsonRepresentationIOS: "{}",
            platform: .ios,
            price: 9.99,
            subscriptionInfoIOS: info,
            subscriptionPeriodNumberIOS: "1",
            subscriptionPeriodUnitIOS: .month,
            title: "Premium",
            type: .subs,
            typeIOS: .autoRenewableSubscription
        )
    }
}
