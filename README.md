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
- ✅ **Unified API** following OpenIAP specification
- ✅ **Product management** with intelligent caching
- ✅ **Purchase handling** with automatic transaction verification
- ✅ **Subscription management** and renewal tracking
- ✅ **Receipt validation** and transaction security
- ✅ **Event-driven** purchase observation
- ✅ **Swift Package Manager** and **CocoaPods** support

## 📋 Requirements

| Platform | Minimum Version |
|----------|-----------------|
| iOS | 15.0+ |
| macOS | 14.0+ |
| tvOS | 15.0+ |
| watchOS | 8.0+ |
| Swift | 5.9+ |

## 📦 Installation

### Swift Package Manager

Add OpenIAP to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/hyodotdev/openiap-apple.git", from: "1.1.1")
]
```

Or through Xcode:
1. **File** → **Add Package Dependencies**
2. Enter: `https://github.com/hyodotdev/openiap-apple.git`
3. Select version and add to your target

### CocoaPods

Add to your `Podfile`:

```ruby
pod 'openiap', '~> 1.1.1'
```

Then run:

```bash
pod install
```

## 🚀 Quick Start

### Initialize Connection

```swift
import OpenIAP

// Initialize the IAP connection
try await OpenIapModule.shared.initConnection()
```

### Fetch Products

```swift
let productIds = ["dev.hyo.premium", "dev.hyo.coins"]
let products = try await OpenIapModule.shared.fetchProducts(skus: productIds)

for product in products {
    print("\(product.title): \(product.displayPrice)")
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
- **Subscription management** with renewal tracking
- **Purchase history** and transaction details
- **Event logging** for debugging and monitoring

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

## 📚 Data Models

### OpenIapProductData

```swift
struct OpenIapProductData {
    let id: String
    let title: String
    let description: String
    let price: Decimal
    let displayPrice: String
    let type: String
    let platform: String
}
```

### OpenIapPurchase

```swift
struct OpenIapPurchase {
    let productId: String
    let transactionId: String
    let purchaseTime: Date
    let purchaseState: PurchaseState
    let isAutoRenewing: Bool
    
    // iOS-specific StoreKit 2 properties
    let environmentIOS: String?
    let storefrontCountryCodeIOS: String?
    // ... additional properties
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

## 🔗 OpenIAP Ecosystem

| Platform | Repository | Status |
|----------|------------|---------|
| **Specification** | [openiap.dev](https://github.com/hyodotdev/openiap.dev) | ✅ Active |
| **Apple** | [openiap-apple](https://github.com/hyodotdev/openiap-apple) | ✅ Active |
| **React Native** | Coming Soon | 🚧 Planned |
| **Flutter** | Coming Soon | 🚧 Planned |
| **Unity** | Coming Soon | 🚧 Planned |

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