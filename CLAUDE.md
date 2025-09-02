# Claude Development Guidelines for ios-iap

## Swift Naming Conventions for Acronyms

### General Rule

- **Acronyms should be ALL CAPS only when they appear as a suffix**
- **When acronyms appear at the beginning or middle, use Pascal case (first letter caps, rest lowercase)**
- **Package/Module names follow the same rule: `IosIAP` (iOS at beginning = `Ios`, IAP as suffix = `IAP`)**

### Examples

#### ✅ Correct

- `IosIAP` (Package name: iOS at beginning, IAP as suffix)
- `IapManager` (IAP at beginning)
- `IapPurchase` (IAP at beginning)
- `IapError` (IAP at beginning)
- `IosIapTests` (both iOS and IAP at beginning/middle)
- `ProductIAP` (IAP as suffix)
- `ManagerIAP` (IAP as suffix)

#### ❌ Incorrect

- `IosIap` (should be `IosIAP` - IAP is suffix)
- `IAPManager` (should be `IapManager`)
- `IAPPurchase` (should be `IapPurchase`)
- `IAPError` (should be `IapError`)
- `IosIAPTests` (should be `IosIapTests` - IAP is in middle, not suffix)

### Specific Cases

- **iOS**: `Ios` when at beginning/middle, `IOS` when as suffix
- **IAP**: `Iap` when at beginning/middle, `IAP` when as suffix  
- **API**: `Api` when at beginning/middle, `API` when as suffix
- **URL**: `Url` when at beginning/middle, `URL` when as suffix

## Testing

- Run tests with: `swift test`
- Build with: `swift build`
- Use real product IDs: `dev.hyo.martie.10bulbs`, `dev.hyo.martie.30bulbs`

## Development Notes

- Purchase Flow should display real-time purchase events
- Transaction observer handles purchase completion
- Mock data available for testing when real products not configured
