# Development Guidelines for OpenIAP

## Function Naming Conventions

### Platform-Specific Functions

- **iOS-specific functions MUST have `IOS` suffix**
- **Android-specific functions MUST have `Android` suffix**
- **Cross-platform functions have NO suffix**

#### Examples

##### ✅ Correct

```swift
// iOS-specific functions
func presentCodeRedemptionSheetIOS()
func showManageSubscriptionsIOS()
func deepLinkToSubscriptionsIOS()
func getPromotedProductIOS()
func requestPurchaseOnPromotedProductIOS()
func syncIOS()
func getReceiptDataIOS()

// Cross-platform functions
func initConnection()
func fetchProducts()
func requestPurchase()
func finishTransaction()
```

##### ❌ Incorrect

```swift
// Missing IOS suffix for iOS-specific
func presentCodeRedemptionSheet()  // Should be presentCodeRedemptionSheetIOS()
func showManageSubscriptions()     // Should be showManageSubscriptionsIOS()

// Unnecessary suffix for cross-platform
func requestPurchaseIOS()  // Should be requestPurchase() if cross-platform
```

### API Naming Alignment

- **MUST match openiap.dev API naming**
- **Use exact same function names as React Native OpenIAP**

#### Standard API Names (Apple module)

- `initConnection()` - Initialize IAP connection
- `endConnection()` - End IAP connection
- `fetchProducts()` - Fetch products from store
- `getAvailablePurchases()` - Get available/restored purchases
- `requestPurchase()` - Request a purchase
- `finishTransaction()` - Finish a transaction

## Swift Naming Conventions for Acronyms

### General Rule

- **Acronyms should be ALL CAPS only when they appear as a suffix**
- **When acronyms appear at the beginning or middle, use Pascal case (first letter caps, rest lowercase)**
- **Package/Module names follow the same rule: `OpenIAP` (Open at beginning = `Open`, IAP as suffix = `IAP`)**

### Examples

#### ✅ Correct

- `OpenIAP` (Package name: Open at beginning, IAP as suffix)
- `IapManager` (IAP at beginning)
- `IapPurchase` (IAP at beginning)
- `IapError` (IAP at beginning)
- `OpenIapTests` (both Open and IAP at beginning/middle)
- `ProductIAP` (IAP as suffix)
- `ManagerIAP` (IAP as suffix)

#### ❌ Incorrect

- `OpenIap` (should be `OpenIAP` - IAP is suffix)
- `IAPManager` (should be `IapManager`)
- `IAPPurchase` (should be `IapPurchase`)
- `IAPError` (should be `IapError`)
- `OpenIAPTests` (should be `OpenIapTests` - IAP is in middle, not suffix)

### Specific Cases

- **iOS**: `Ios` when at beginning/middle, `IOS` when as suffix
- **IAP**: `Iap` when at beginning/middle, `IAP` when as suffix
- **API**: `Api` when at beginning/middle, `API` when as suffix
- **URL**: `Url` when at beginning/middle, `URL` when as suffix

## Error Code Naming

- `OpenIapError` static code constants use PascalCase names (e.g. `UserCancelled`, `SkuNotFound`) while the raw string value stays as the `E_` code for parity with other platforms.
- Always reference the PascalCase constants in Swift and avoid introducing new `E_`-prefixed identifiers.

## Testing

- Run tests with: `swift test`
- Build with: `swift build`
- Use real product IDs: `dev.hyo.martie.10bulbs`, `dev.hyo.martie.30bulbs`

## File Organization

### Directory Structure

- **Sources/Models/**: OpenIAP official types that match [openiap.dev/docs/types](https://www.openiap.dev/docs/types)

  - `Product.swift` - ProductIOS and related types
  - `Purchase.swift` - PurchaseIOS and related types
  - `ActiveSubscription.swift` - ActiveSubscription type
  - `PurchaseError.swift` - PurchaseError type
  - `Receipt.swift` - Receipt validation types
  - etc.

- **Sources/Helpers/**: Internal helper classes (NOT in OpenIAP official types)

  - `ProductManager.swift` - Thread-safe product caching
  - `IapStatus.swift` - UI status management for SwiftUI

- **Sources/**: Main module files
  - `OpenIapModule.swift` - Core implementation
  - `OpenIapStore.swift` - SwiftUI-friendly store
  - `OpenIapProtocol.swift` - API interface definitions

### Naming Rules

- **Models**: Must match OpenIAP specification exactly
- **Helpers**: Use descriptive names ending with purpose (Manager, Cache, Status, etc.)
- **Avoid confusing names**: Don't use "Store" for caching classes (use Cache, Manager instead)

## Git Commit Message Guidelines

### Commit Message Format

- Follow Conventional Commits format: `<type>: <description>`
- **Type MUST be lowercase** (e.g., `feat:`, `fix:`, `docs:`, `refactor:`)
- **Description starts with lowercase** after the colon and space

#### Common Types

- `feat:` - New feature
- `fix:` - Bug fix
- `docs:` - Documentation changes
- `refactor:` - Code refactoring
- `test:` - Test additions or changes
- `chore:` - Maintenance tasks

#### Examples

##### ✅ Correct

```
feat: add Objective-C bridge for Kotlin Multiplatform
fix: use DiscountOfferInputIOS for subscription offers
docs: update API documentation
refactor: simplify purchase flow logic
```

##### ❌ Incorrect

```
Feat: add new feature          // Type should be lowercase
fix: Add new feature           // Description should start with lowercase
FIX: something                 // Type should be lowercase
```

## Development Notes

- Purchase Flow should display real-time purchase events
- Transaction observer handles purchase completion
- Mock data available for testing when real products not configured
