import XCTest
@testable import OpenIAP

final class OpenIapTests: XCTestCase {
    
    func testProductModel() {
        let subscriptionInfo = OpenIapProduct.SubscriptionInfo(
            introductoryOffer: OpenIapProduct.SubscriptionOffer(
                displayPrice: "Free",
                id: "intro1",
                paymentMode: .freeTrial,
                period: OpenIapProduct.SubscriptionPeriod(unit: .week, value: 1),
                periodCount: 1,
                price: 0,
                type: .introductory
            ),
            promotionalOffers: nil,
            subscriptionGroupId: "group1",
            subscriptionPeriod: OpenIapProduct.SubscriptionPeriod(unit: .month, value: 1)
        )
        
        let product = OpenIapProduct(
            id: "dev.hyo.premium",
            title: "Premium Subscription",
            description: "Get access to all premium features",
            type: "subs",
            displayName: "Premium Subscription",
            displayPrice: "$9.99",
            currency: "USD",
            price: 9.99,
            debugDescription: nil,
            platform: "ios",
            displayNameIOS: "Premium Subscription",
            isFamilyShareableIOS: true,
            jsonRepresentationIOS: "{}",
            subscriptionInfoIOS: subscriptionInfo,
            typeIOS: .autoRenewableSubscription,
            discountsIOS: nil,
            introductoryPriceIOS: "Free",
            introductoryPriceAsAmountIOS: "0",
            introductoryPricePaymentModeIOS: "FREETRIAL",
            introductoryPriceNumberOfPeriodsIOS: "1",
            introductoryPriceSubscriptionPeriodIOS: "WEEK",
            subscriptionPeriodNumberIOS: "1",
            subscriptionPeriodUnitIOS: "MONTH"
        )
        
        XCTAssertEqual(product.id, "dev.hyo.premium")
        XCTAssertEqual(product.type, "subs")
        XCTAssertEqual(product.price, 9.99)
        XCTAssertNotNil(product.subscriptionInfoIOS)
        XCTAssertNotNil(product.subscriptionInfoIOS?.introductoryOffer)
        XCTAssertEqual(product.subscriptionInfoIOS?.introductoryOffer?.paymentMode, .freeTrial)
    }
    
    func testPurchaseModel() {
        let now = Date()
        let purchase = OpenIapPurchase(
            id: "trans123",
            productId: "dev.hyo.premium",
            ids: ["trans123"],
            transactionDate: now.timeIntervalSince1970 * 1000,
            purchaseToken: "token123",
            platform: "ios",
            quantity: 1,
            purchaseState: .purchased,
            isAutoRenewing: true,
            quantityIOS: 1,
            originalTransactionDateIOS: now.timeIntervalSince1970 * 1000,
            originalTransactionIdentifierIOS: "original123",
            appAccountToken: nil,
            expirationDateIOS: (now.timeIntervalSince1970 + 86400 * 30) * 1000,
            webOrderLineItemIdIOS: nil,
            environmentIOS: "Production",
            storefrontCountryCodeIOS: "US",
            appBundleIdIOS: "dev.hyo.martie",
            productTypeIOS: "auto_renewable_subscription",
            subscriptionGroupIdIOS: "group1",
            isUpgradedIOS: false,
            ownershipTypeIOS: "purchased",
            reasonIOS: "purchase",
            reasonStringRepresentationIOS: "purchase",
            transactionReasonIOS: "PURCHASE",
            revocationDateIOS: nil,
            revocationReasonIOS: nil,
            offerIOS: nil,
            currencyCodeIOS: "USD",
            currencySymbolIOS: "$",
            countryCodeIOS: "US"
        )
        
        XCTAssertEqual(purchase.id, "trans123")
        XCTAssertEqual(purchase.productId, "dev.hyo.premium")
        XCTAssertEqual(purchase.platform, "ios")
        XCTAssertEqual(purchase.quantityIOS, 1)
        XCTAssertEqual(purchase.transactionReasonIOS, "PURCHASE")
    }
    
    func testOpenIapError() {
        let error1 = OpenIapError.make(code: OpenIapError.SkuNotFound, productId: "test.product")
        XCTAssertEqual(error1.code, OpenIapError.SkuNotFound)
        XCTAssertEqual(error1.productId, "test.product")
        XCTAssertFalse(error1.message.isEmpty)

        let error2 = OpenIapError.make(code: OpenIapError.UserCancelled)
        XCTAssertNotNil(error2.errorDescription)
        XCTAssertTrue(error2.errorDescription?.contains("cancelled") ?? false)

        let error3 = OpenIapError.make(code: OpenIapError.TransactionValidationFailed, message: "Invalid signature")
        XCTAssertNotNil(error3.errorDescription)
        XCTAssertTrue(error3.errorDescription?.contains("Invalid signature") ?? false)
    }
    
    func testSubscriptionPeriod() {
        let period1 = OpenIapProduct.SubscriptionPeriod(unit: .month, value: 1)
        let period2 = OpenIapProduct.SubscriptionPeriod(unit: .month, value: 1)
        let period3 = OpenIapProduct.SubscriptionPeriod(unit: .year, value: 1)
        
        XCTAssertEqual(period1, period2)
        XCTAssertNotEqual(period1, period3)
    }
    
    func testSubscriptionOffer() {
        let offer = OpenIapProduct.SubscriptionOffer(
            displayPrice: "$4.99",
            id: "intro2",
            paymentMode: .payAsYouGo,
            period: OpenIapProduct.SubscriptionPeriod(unit: .month, value: 1),
            periodCount: 3,
            price: 4.99,
            type: .introductory
        )
        
        XCTAssertEqual(offer.price, 4.99)
        XCTAssertEqual(offer.periodCount, 3)
        XCTAssertEqual(offer.paymentMode, .payAsYouGo)
        XCTAssertEqual(offer.type, .introductory)
    }
    
    func testReceipt() {
        let now = Date()
        let purchases = [
            OpenIapPurchase(
                id: "trans1",
                productId: "product1",
                ids: ["trans1"],
                transactionDate: now.timeIntervalSince1970 * 1000,
                purchaseToken: "token1",
                platform: "ios",
                quantity: 1,
                purchaseState: .purchased,
                isAutoRenewing: false,
                quantityIOS: 1,
                originalTransactionDateIOS: nil,
                originalTransactionIdentifierIOS: nil,
                appAccountToken: nil,
                expirationDateIOS: nil,
                webOrderLineItemIdIOS: nil,
                environmentIOS: "Production",
                storefrontCountryCodeIOS: "US",
                appBundleIdIOS: "dev.hyo.app",
                productTypeIOS: "consumable",
                subscriptionGroupIdIOS: nil,
                isUpgradedIOS: false,
                ownershipTypeIOS: "purchased",
                reasonIOS: "purchase",
                reasonStringRepresentationIOS: "purchase",
                transactionReasonIOS: "PURCHASE",
                revocationDateIOS: nil,
                revocationReasonIOS: nil,
                offerIOS: nil,
                currencyCodeIOS: "USD",
                currencySymbolIOS: "$",
                countryCodeIOS: "US"
            )
        ]
        
        let receipt = OpenIapReceipt(
            bundleId: "dev.hyo.app",
            applicationVersion: "1.0.0",
            originalApplicationVersion: "1.0.0",
            creationDate: Date(),
            expirationDate: nil,
            inAppPurchases: purchases
        )
        
        XCTAssertEqual(receipt.bundleId, "dev.hyo.app")
        XCTAssertEqual(receipt.applicationVersion, "1.0.0")
        XCTAssertEqual(receipt.inAppPurchases.count, 1)
        XCTAssertEqual(receipt.inAppPurchases.first?.id, "trans1")
    }

    func testProductRequestTypeNormalization() {
        let legacyRequest = OpenIapProductRequest(skus: ["sku1"], type: "inapp")
        XCTAssertEqual(legacyRequest.type, "in-app")
        XCTAssertEqual(legacyRequest.requestType, .inApp)

        let modernRequest = OpenIapProductRequest(skus: ["sku1"], type: "in-app")
        XCTAssertEqual(modernRequest.type, "in-app")
        XCTAssertEqual(modernRequest.requestType, .inApp)

        let enumRequest = OpenIapProductRequest(skus: ["sku1"], type: .inApp)
        XCTAssertEqual(enumRequest.type, "in-app")
        XCTAssertEqual(enumRequest.requestType, .inApp)
    }
}
