# OpenIAP Apple

<div align="center">
  <img src="https://openiap.dev/logo.png" alt="OpenIAP Logo" width="120" height="120">
</div>

<div align="center">
  <strong>A comprehensive Swift implementation of the OpenIAP specification for iOS, macOS, tvOS, and watchOS applications.</strong>
</div>

<br />

**OpenIAP** is a unified specification for in-app purchases across platforms, frameworks, and emerging technologies. This Apple ecosystem implementation standardizes IAP implementations to reduce fragmentation and enable consistent behavioral across all Apple platforms.

In the AI coding era, having a unified IAP specification becomes increasingly important as developers build applications across multiple platforms and frameworks with automated tools.

## 🌐 Learn More

Visit [**openiap.dev**](https://openiap.dev) for complete documentation, guides, and the full OpenIAP specification.

## ✨ Features

- ✅ **StoreKit 2** support with full iOS 15+ compatibility
- ✅ **Cross-platform** support (iOS, macOS, tvOS, watchOS)
- ✅ **Thread-safe** operations with MainActor isolation
- ✅ **Unified API** following OpenIAP specification
- ✅ **Product management** with intelligent caching
- ✅ **Purchase handling** with automatic transaction verification
- ✅ **Subscription management** with cancel/reactivate support
- ✅ **Receipt validation** and transaction security
- ✅ **Event-driven** purchase observation
- ✅ **Swift Package Manager** and **CocoaPods** support

## 📋 Requirements

| Platform | Minimum Version |
| -------- | --------------- |
| iOS      | 15.0+           |
| macOS    | 14.0+           |
| tvOS     | 15.0+           |
| watchOS  | 8.0+            |
| Swift    | 5.9+            |

## 📦 Installation

### Swift Package Manager

Add OpenIAP to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/hyodotdev/openiap-apple.git", from: "1.1.5")
]
```

Or through Xcode:

1. **File** → **Add Package Dependencies**
2. Enter: `https://github.com/hyodotdev/openiap-apple.git`
3. Select version and add to your target

### CocoaPods

Add to your `Podfile`:

```ruby
pod 'openiap', '~> 1.1.5'
```

Then run:

```bash
pod install
```

## 🚀 Quick Start

### Initialize Connection

```swift
import OpenIAP

// Initialize the IAP connection (thread-safe with MainActor isolation)
try await OpenIapModule.shared.initConnection()
```

### Fetch Products

```swift
let productIds = ["dev.hyo.premium", "dev.hyo.coins"]
let products = try await OpenIapModule.shared.fetchProducts(skus: productIds)

for product in products {
    print("\(product.localizedTitle): \(product.localizedPrice)")
}
```

### Make a Purchase

```swift
do {
    let transaction = try await OpenIapModule.shared.requestPurchase(
        sku: "dev.hyo.premium",
        andDangerouslyFinishTransactionAutomatically: true
    )
    print("✅ Purchase successful!")
} catch {
    print("❌ Purchase failed: \(error)")
}
```

### Listen to Purchase Events

```swift
// Listen for successful purchases
OpenIapModule.shared.addPurchaseUpdatedListener { purchase in
    print("🎉 New purchase: \(purchase.productId)")
}

// Handle purchase errors
OpenIapModule.shared.addPurchaseErrorListener { error in
    print("💥 Purchase error: \(error.localizedDescription)")
}
```

## 📱 Example App

The repository includes a complete **SwiftUI example app** demonstrating all OpenIAP features:

- **Product catalog** with real-time pricing
- **Purchase flow** with loading states and error handling
- **Subscription management** with renewal tracking, cancel/reactivate support
- **Purchase history** and transaction details
- **Event logging** for debugging and monitoring
- **Sandbox debug tools** integrated into My Purchases section

Run the example:

```bash
cd Example
open Martie.xcodeproj
```

## 🧪 Testing

### Run Tests

```bash
# Via Swift Package Manager
swift test

# Via Xcode
⌘U (Product → Test)
```

### Test with Sandbox

1. Configure your products in **App Store Connect**
2. Create a **Sandbox Apple ID**
3. Use test card: `4242 4242 4242 4242`
4. Monitor purchase events in the Example app logs

### Server-Side Validation

OpenIAP provides comprehensive transaction verification with server-side receipt validation examples:

```swift
// Transaction finishing with validation
let transaction = try await OpenIapModule.shared.requestPurchase(
    sku: "dev.hyo.premium",
    andDangerouslyFinishTransactionAutomatically: false // Validate server-side first
)

// Validate on your server using jwsRepresentation
// Then finish the transaction manually
try await transaction.finish()
```

## 📚 Data Models

### OpenIapProduct

```swift
struct OpenIapProduct {
    // Common properties
    let id: String
    let title: String
    let description: String
    let type: String  // "inapp" or "subs"
    let displayPrice: String
    let currency: String
    let price: Double?
    let platform: String

    // iOS-specific properties
    let displayNameIOS: String
    let typeIOS: ProductTypeIOS
    let subscriptionInfoIOS: SubscriptionInfo?
    let discountsIOS: [Discount]?
    let isFamilyShareableIOS: Bool
}

enum ProductTypeIOS {
    case consumable
    case nonConsumable
    case autoRenewableSubscription
    case nonRenewingSubscription

    var isSubs: Bool { /* returns true for autoRenewableSubscription */ }
}
```

### OpenIapPurchase

```swift
struct OpenIapPurchase {
    // Common properties
    let id: String  // Transaction ID
    let productId: String
    let transactionDate: Double  // Unix timestamp in milliseconds
    let transactionReceipt: String
    let purchaseState: PurchaseState
    let isAutoRenewing: Bool
    let quantity: Int
    let platform: String

    // iOS-specific properties
    let appAccountToken: String?
    let environmentIOS: String?
    let storefrontCountryCodeIOS: String?
    let productTypeIOS: String?
    let subscriptionGroupIdIOS: String?
    let transactionReasonIOS: String?  // "PURCHASE" | "RENEWAL"
    let offerIOS: PurchaseOffer?
    // ... additional properties
}

enum PurchaseState {
    case pending, purchased, failed, restored, deferred, unknown
}
```

### DiscountOffer

```swift
struct DiscountOffer {
    let identifier: String
    let keyIdentifier: String
    let nonce: String
    let signature: String
    let timestamp: String
}
```

## ⚡ Error Handling

OpenIAP provides comprehensive error handling:

```swift
enum OpenIapError: LocalizedError {
    case purchaseFailed(reason: String)
    case purchaseCancelled
    case purchaseDeferred
    case productNotFound(productId: String)
    case verificationFailed(reason: String)
    case storeKitError(error: Error)
    case notSupported
}
```

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

## 📄 License

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.

## 💬 Support

- 📖 **Documentation**: [openiap.dev](https://openiap.dev)
- 🐛 **Bug Reports**: [GitHub Issues](https://github.com/hyodotdev/openiap-apple/issues)
- 💡 **Feature Requests**: [GitHub Discussions](https://github.com/hyodotdev/openiap-apple/discussions)
- 💬 **Community**: [Discord](https://discord.gg/openiap) (Coming Soon)

---

<div align="center">
  <strong>Built with ❤️ for the OpenIAP community</strong>
</div>
