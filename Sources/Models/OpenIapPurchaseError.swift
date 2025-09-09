import Foundation
import StoreKit

// Backward compatibility: Re-export unified error event under previous names
public typealias PurchaseError = OpenIapErrorEvent
public typealias OpenIapPurchaseError = OpenIapErrorEvent

public extension PurchaseError {
    /// Create error for empty SKU list
    static func emptySkuList() -> PurchaseError {
        return .init(code: E_EMPTY_SKU_LIST, message: "Empty SKU list provided")
    }

    /// Convenience factory mirroring previous API
    static func make(code: String, productId: String? = nil, message: String? = nil) -> PurchaseError {
        return .init(code: code, message: message ?? defaultMessage(for: code), productId: productId)
    }

    /// Create from OpenIapError (mirror of previous initializer)
    init(from error: OpenIapError, productId: String? = nil) {
        self = .init(from: error, productId: productId)
    }
}
