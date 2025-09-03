import Foundation

public enum OpenIapError: LocalizedError {
    case productNotFound(productId: String)
    case purchaseFailed(reason: String)
    case purchaseCancelled
    case purchaseDeferred
    case paymentNotAllowed
    case storeKitError(error: Error)
    case invalidReceipt
    case networkError
    case verificationFailed(reason: String)
    case restoreFailed(reason: String)
    case unknownError
    case notSupported
    
    public var errorDescription: String? {
        switch self {
        case .productNotFound(let productId):
            return "Product not found: \(productId)"
        case .purchaseFailed(let reason):
            return "Purchase failed: \(reason)"
        case .purchaseCancelled:
            return "Purchase cancelled by user"
        case .purchaseDeferred:
            return "Purchase deferred"
        case .paymentNotAllowed:
            return "Payment not allowed"
        case .storeKitError(let error):
            return "StoreKit error: \(error.localizedDescription)"
        case .invalidReceipt:
            return "Invalid receipt"
        case .networkError:
            return "Network error occurred"
        case .verificationFailed(let reason):
            return "Verification failed: \(reason)"
        case .restoreFailed(let reason):
            return "Restore failed: \(reason)"
        case .unknownError:
            return "Unknown error occurred"
        case .notSupported:
            return "Feature not supported on this platform"
        }
    }
}