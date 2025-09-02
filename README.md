# IosIAP

A comprehensive iOS In-App Purchase library following the OpenIAP specification. Simplifies the integration of in-app purchases in iOS applications with a clean, modern API.

## Features

- ✅ StoreKit 2 support (iOS 15+)
- ✅ Legacy StoreKit support (iOS 13-14)
- ✅ Product fetching and caching
- ✅ Purchase handling
- ✅ Receipt validation
- ✅ Subscription management
- ✅ Restore purchases
- ✅ Transaction observation
- ✅ Swift Package Manager support
- ✅ CocoaPods support

## Requirements

- iOS 13.0+
- macOS 10.15+
- tvOS 13.0+
- watchOS 6.0+
- Swift 5.9+

## Installation

### Swift Package Manager

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/hyochan/ios-iap.git", from: "1.0.0")
]
```

Or add it through Xcode:
1. File → Add Package Dependencies
2. Enter the repository URL: `https://github.com/hyochan/ios-iap.git`
3. Select the version and add to your target

### CocoaPods

Add the following to your `Podfile`:

```ruby
pod 'IosIAP', '~> 1.0.0'
```

Then run:

```bash
pod install
```

## Usage

### Initialize the IAP Manager

```swift
import IosIAP

// For iOS 15+
if #available(iOS 15.0, *) {
    try await IAPManager.shared.initialize()
}
```

### Fetch Products

```swift
let productIds: Set<String> = ["com.example.premium", "com.example.coins"]
let products = try await IAPManager.shared.getProducts(productIds: productIds)

for product in products {
    print("\(product.localizedTitle): \(product.localizedPrice)")
}
```

### Make a Purchase

```swift
do {
    let purchase = try await IAPManager.shared.purchase(productId: "com.example.premium")
    print("Purchase successful: \(purchase.transactionId)")
} catch {
    print("Purchase failed: \(error)")
}
```

### Restore Purchases

```swift
let restoredPurchases = try await IAPManager.shared.restorePurchases()
print("Restored \(restoredPurchases.count) purchases")
```

### Observe Transactions

```swift
Task {
    for await update in IAPManager.shared.observeTransactions() {
        switch update.event {
        case .purchased:
            print("New purchase: \(update.transaction.productId)")
        case .restored:
            print("Restored: \(update.transaction.productId)")
        case .failed(let error):
            print("Transaction failed: \(error)")
        case .pending:
            print("Transaction pending")
        case .revoked:
            print("Transaction revoked")
        }
    }
}
```

### Get Purchase History

```swift
let purchases = try await IAPManager.shared.getPurchaseHistory()
for purchase in purchases {
    print("Product: \(purchase.productId), Date: \(purchase.purchaseTime)")
}
```

### Verify Receipt

```swift
let receipt = try await IAPManager.shared.verifyReceipt(receiptData: nil)
print("Bundle ID: \(receipt.bundleId)")
print("Purchases: \(receipt.inAppPurchases.count)")
```

## Data Models

### IAPProduct

```swift
struct IAPProduct {
    let productId: String
    let productType: ProductType
    let localizedTitle: String
    let localizedDescription: String
    let price: Decimal
    let localizedPrice: String
    let currencyCode: String?
    let countryCode: String?
    let subscriptionPeriod: SubscriptionPeriod?
    let introductoryPrice: IntroductoryOffer?
    let discounts: [Discount]?
}
```

### IAPPurchase

```swift
struct IAPPurchase {
    let productId: String
    let purchaseToken: String
    let transactionId: String
    let originalTransactionId: String?
    let purchaseTime: Date
    let originalPurchaseTime: Date?
    let expiryTime: Date?
    let isAutoRenewing: Bool
    let purchaseState: PurchaseState
    let developerPayload: String?
    let acknowledgementState: AcknowledgementState
    let quantity: Int
}
```

## Error Handling

The library provides comprehensive error handling through the `IAPError` enum:

```swift
enum IAPError: LocalizedError {
    case productNotFound(productId: String)
    case purchaseFailed(reason: String)
    case purchaseCancelled
    case purchaseDeferred
    case paymentNotAllowed
    case storeKitError(error: Error)
    case invalidReceipt
    case networkError(error: Error)
    case verificationFailed(reason: String)
    case restoreFailed(reason: String)
    case unknownError
}
```

## Example App

Check the `Example` folder for a complete SwiftUI example application demonstrating all features.

## Testing

Run the tests using:

```bash
swift test
```

Or through Xcode:
1. Product → Test (⌘U)

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Support

For issues and feature requests, please use the [GitHub Issues](https://github.com/hyochan/ios-iap/issues) page.