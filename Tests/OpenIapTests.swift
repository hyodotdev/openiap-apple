import XCTest
@testable import OpenIAP

final class OpenIapTests: XCTestCase {
    
    func testProductModel() {
        let product = OpenIapProduct(
            productId: "dev.hyo.premium",
            productType: .autoRenewableSubscription,
            localizedTitle: "Premium Subscription",
            localizedDescription: "Get access to all premium features",
            price: 9.99,
            localizedPrice: "$9.99",
            currencyCode: "USD",
            countryCode: "US",
            subscriptionPeriod: OpenIapProduct.SubscriptionPeriod(unit: .month, value: 1),
            introductoryPrice: OpenIapProduct.IntroductoryOffer(
                price: 0,
                localizedPrice: "Free",
                period: OpenIapProduct.SubscriptionPeriod(unit: .week, value: 1),
                numberOfPeriods: 1,
                paymentMode: .freeTrial
            ),
            discounts: nil
        )
        
        XCTAssertEqual(product.productId, "dev.hyo.premium")
        XCTAssertEqual(product.productType, .autoRenewableSubscription)
        XCTAssertEqual(product.price, 9.99)
        XCTAssertNotNil(product.subscriptionPeriod)
        XCTAssertNotNil(product.introductoryPrice)
        XCTAssertEqual(product.introductoryPrice?.paymentMode, .freeTrial)
    }
    
    func testPurchaseModel() {
        let purchase = OpenIapPurchase(
            productId: "dev.hyo.premium",
            purchaseToken: "token123",
            transactionId: "trans123",
            originalTransactionId: "original123",
            purchaseTime: Date(),
            originalPurchaseTime: Date(),
            expiryTime: Date().addingTimeInterval(86400 * 30),
            isAutoRenewing: true,
            purchaseState: .purchased,
            developerPayload: nil,
            acknowledgementState: .acknowledged,
            quantity: 1,
            jwsRepresentation: nil,
            jsonRepresentation: nil,
            appAccountToken: nil
        )
        
        XCTAssertEqual(purchase.productId, "dev.hyo.premium")
        XCTAssertEqual(purchase.purchaseState, .purchased)
        XCTAssertEqual(purchase.acknowledgementState, .acknowledged)
        XCTAssertTrue(purchase.isAutoRenewing)
        XCTAssertEqual(purchase.quantity, 1)
    }
    
    func testOpenIapError() {
        let error1 = OpenIapError.productNotFound(productId: "test.product")
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
                productId: "product1",
                purchaseToken: "token1",
                transactionId: "trans1",
                originalTransactionId: nil,
                purchaseTime: Date(),
                originalPurchaseTime: nil,
                expiryTime: nil,
                isAutoRenewing: false,
                purchaseState: .purchased,
                developerPayload: nil,
                acknowledgementState: .acknowledged,
                quantity: 1,
                jwsRepresentation: nil,
                jsonRepresentation: nil,
                appAccountToken: nil
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
        XCTAssertEqual(receipt.inAppPurchases.first?.productId, "product1")
    }
}