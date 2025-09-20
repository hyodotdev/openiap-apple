import XCTest
@testable import OpenIAP

final class OpenIapTests: XCTestCase {

    func testProductIOS() {
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

        let product = ProductIOS(
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

        XCTAssertEqual(product.id, "dev.hyo.premium")
        XCTAssertEqual(product.platform, .ios)
        XCTAssertEqual(product.price, 9.99)
        XCTAssertEqual(product.subscriptionInfoIOS?.subscriptionGroupId, "group")
    }

    func testPurchaseIOS() {
        let purchase = PurchaseIOS(
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
}
