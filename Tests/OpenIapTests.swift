import XCTest
@testable import OpenIAP

final class OpenIapTests: XCTestCase {
    
    func testProductModel() {
        let product = OpenIapProduct(
            id: "dev.hyo.premium",
            productType: .autoRenewableSubscription,
            localizedTitle: "Premium Subscription",
            localizedDescription: "Get access to all premium features",
            price: 9.99,
            localizedPrice: "$9.99",
            currencyCode: "USD",
            countryCode: "US",
            subscriptionPeriod: OpenIapProduct.SubscriptionPeriod(unit: .month, value: 1),
            introductoryPrice: OpenIapProduct.IntroductoryOffer(
                id: "intro1",
                price: 0,
                localizedPrice: "Free",
                period: OpenIapProduct.SubscriptionPeriod(unit: .week, value: 1),
                numberOfPeriods: 1,
                paymentMode: .freeTrial
            ),
            discounts: nil,
            subscriptionGroupId: "group1",
            platform: "iOS",
            isFamilyShareable: true,
            jsonRepresentation: nil,
            displayNameIOS: "Premium Subscription",
            isFamilyShareableIOS: true,
            jsonRepresentationIOS: "{}",
            descriptionIOS: "Get access to all premium features",
            displayPriceIOS: "$9.99",
            priceIOS: 9.99
        )
        
        XCTAssertEqual(product.id, "dev.hyo.premium")
        XCTAssertEqual(product.productType, .autoRenewableSubscription)
        XCTAssertEqual(product.price, 9.99)
        XCTAssertNotNil(product.subscriptionPeriod)
        XCTAssertNotNil(product.introductoryPrice)
        XCTAssertEqual(product.introductoryPrice?.paymentMode, .freeTrial)
    }
    
    func testPurchaseModel() {
        let purchase = OpenIapPurchase(
            id: "trans123",
            productId: "dev.hyo.premium",
            purchaseToken: "token123",
            transactionId: "trans123",
            originalTransactionId: "original123",
            platform: "iOS",
            ids: ["trans123"],
            purchaseTime: Date(),
            originalPurchaseTime: Date(),
            expiryTime: Date().addingTimeInterval(86400 * 30),
            isAutoRenewing: true,
            purchaseState: .purchased,
            acknowledgementState: .acknowledged,
            quantity: 1,
            developerPayload: nil,
            jwsRepresentation: nil,
            jsonRepresentation: nil,
            appAccountToken: nil,
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
        XCTAssertEqual(purchase.purchaseState, .purchased)
        XCTAssertEqual(purchase.acknowledgementState, .acknowledged)
        XCTAssertTrue(purchase.isAutoRenewing)
        XCTAssertEqual(purchase.quantity, 1)
    }
    
    func testOpenIapError() {
        let error1 = OpenIapError.productNotFound(id: "test.product")
        XCTAssertNotNil(error1.errorDescription)
        XCTAssertTrue(error1.errorDescription?.contains("test.product") ?? false)
        
        let error2 = OpenIapError.purchaseCancelled
        XCTAssertNotNil(error2.errorDescription)
        XCTAssertTrue(error2.errorDescription?.contains("cancelled") ?? false)
        
        let error3 = OpenIapError.verificationFailed(reason: "Invalid signature")
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
    
    func testIntroductoryOffer() {
        let offer = OpenIapProduct.IntroductoryOffer(
            id: "intro2",
            price: 4.99,
            localizedPrice: "$4.99",
            period: OpenIapProduct.SubscriptionPeriod(unit: .month, value: 1),
            numberOfPeriods: 3,
            paymentMode: .payAsYouGo
        )
        
        XCTAssertEqual(offer.price, 4.99)
        XCTAssertEqual(offer.numberOfPeriods, 3)
        XCTAssertEqual(offer.paymentMode, .payAsYouGo)
    }
    
    func testReceipt() {
        let purchases = [
            OpenIapPurchase(
                id: "trans1",
                productId: "product1",
                purchaseToken: "token1",
                transactionId: "trans1",
                originalTransactionId: nil,
                platform: "iOS",
                ids: ["trans1"],
                purchaseTime: Date(),
                originalPurchaseTime: nil,
                expiryTime: nil,
                isAutoRenewing: false,
                purchaseState: .purchased,
                acknowledgementState: .acknowledged,
                quantity: 1,
                developerPayload: nil,
                jwsRepresentation: nil,
                jsonRepresentation: nil,
                appAccountToken: nil,
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
}