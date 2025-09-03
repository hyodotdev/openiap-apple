# OpenIAP

A comprehensive cross-platform In-App Purchase library following the OpenIAP specification. Simplifies the integration of in-app purchases in iOS/macOS/tvOS/watchOS applications with a clean, modern API.

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
    .package(url: "https://github.com/hyodotdev/openiap-apple.git", from: "1.0.0")
]
```

Or add it through Xcode:
1. File → Add Package Dependencies
2. Enter the repository URL: `https://github.com/hyodotdev/openiap-apple.git`
3. Select the version and add to your target

### CocoaPods

Add the following to your `Podfile`:

```ruby
pod 'openiap', '~> 1.0.0'
```

Then run:

```bash
pod install
```

## Usage

### Initialize the IAP Manager

```swift
import OpenIAP

// For iOS 15+
if #available(iOS 15.0, *) {
    try await IapModule.shared.initConnection()
}
```

### Fetch Products

```swift
let productIds = ["com.example.premium", "com.example.coins"]
let products = try await IapModule.shared.fetchProducts(skus: productIds)

for product in products {
    print("\(product.title): \(product.displayPrice)")
}
```

### Make a Purchase

```swift
do {
    let transaction = try await IapModule.shared.requestPurchase(
        sku: "com.example.premium",
        andDangerouslyFinishTransactionAutomatically: true
    )
    print("Purchase successful: \(transaction?.transactionIdentifier ?? "")")
} catch {
    print("Purchase failed: \(error)")
}
```

### Restore Purchases

```swift
let restoredPurchases = try await IapModule.shared.getAvailablePurchases()
print("Restored \(restoredPurchases.count) purchases")
```

### Observe Transactions (Event Listeners)

```swift
// Add purchase updated listener
IapModule.shared.addPurchaseUpdatedListener { purchase in
    print("New purchase: \(purchase.productId)")
}

// Add purchase error listener
IapModule.shared.addPurchaseErrorListener { error in
    print("Purchase failed: \(error)")
}
```

### Get Purchase History

```swift
let purchases = try await IapModule.shared.getAvailablePurchases()
for purchase in purchases {
    print("Product: \(purchase.productId), Date: \(purchase.purchaseTime)")
}
```

### Receipt Validation

```swift
let receiptData = try await IapModule.shared.getReceiptDataIOS()
print("Receipt data: \(receiptData)")
```

## Data Models

### IapProductData

```swift
struct IapProductData {
    let id: String
    let title: String
    let description: String
    let type: String
    let displayPrice: String
    let price: Double
    let currency: String
    let platform: String
    // ... additional properties
}
```

### IapPurchase

```swift
struct IapPurchase {
    let productId: String
    let transactionId: String
    let originalTransactionId: String?
    let purchaseTime: Double
    let originalPurchaseTime: Double?
    let platform: String
    // ... additional properties
}
```

## Error Handling

The library provides comprehensive error handling through the `IapError` enum:

```swift
enum IapError: LocalizedError {
    case purchaseFailed(reason: String)
    case purchaseCancelled
    case purchaseDeferred
    case storeKitError(error: Error)
    case verificationFailed(reason: String)
    case unknownError
    case notSupported
    // ... additional cases
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

For issues and feature requests, please use the [GitHub Issues](https://github.com/hyodotdev/openiap-apple/issues) page.