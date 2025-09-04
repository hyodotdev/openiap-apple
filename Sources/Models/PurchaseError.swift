import Foundation
import StoreKit

/// Purchase error event payload
/// Following OpenIAP specification exactly
public struct PurchaseError: Codable, Equatable {
    /// Error code constant (required)
    public let code: String
    
    /// Human-readable message (required)
    public let message: String
    
    /// Related product SKU (optional, if applicable)
    public let productId: String?
    
    public init(
        code: String,
        message: String,
        productId: String? = nil
    ) {
        self.code = code
        self.message = message
        self.productId = productId
    }
}

// MARK: - Error Codes (OpenIAP Specification)
extension PurchaseError {
    // MARK: User Action Errors
    public static let E_USER_CANCELLED = "E_USER_CANCELLED"
    public static let E_USER_ERROR = "E_USER_ERROR"
    public static let E_DEFERRED_PAYMENT = "E_DEFERRED_PAYMENT"
    public static let E_INTERRUPTED = "E_INTERRUPTED"
    
    // MARK: Product Errors
    public static let E_ITEM_UNAVAILABLE = "E_ITEM_UNAVAILABLE"
    public static let E_SKU_NOT_FOUND = "E_SKU_NOT_FOUND"
    public static let E_SKU_OFFER_MISMATCH = "E_SKU_OFFER_MISMATCH"
    public static let E_QUERY_PRODUCT = "E_QUERY_PRODUCT"
    public static let E_ALREADY_OWNED = "E_ALREADY_OWNED"
    public static let E_ITEM_NOT_OWNED = "E_ITEM_NOT_OWNED"
    
    // MARK: Network & Service Errors
    public static let E_NETWORK_ERROR = "E_NETWORK_ERROR"
    public static let E_SERVICE_ERROR = "E_SERVICE_ERROR"
    public static let E_REMOTE_ERROR = "E_REMOTE_ERROR"
    public static let E_INIT_CONNECTION = "E_INIT_CONNECTION"
    public static let E_SERVICE_DISCONNECTED = "E_SERVICE_DISCONNECTED"
    public static let E_CONNECTION_CLOSED = "E_CONNECTION_CLOSED"
    public static let E_IAP_NOT_AVAILABLE = "E_IAP_NOT_AVAILABLE"
    public static let E_BILLING_UNAVAILABLE = "E_BILLING_UNAVAILABLE"
    public static let E_FEATURE_NOT_SUPPORTED = "E_FEATURE_NOT_SUPPORTED"
    public static let E_SYNC_ERROR = "E_SYNC_ERROR"
    
    // MARK: Validation Errors
    public static let E_RECEIPT_FAILED = "E_RECEIPT_FAILED"
    public static let E_RECEIPT_FINISHED = "E_RECEIPT_FINISHED"
    public static let E_RECEIPT_FINISHED_FAILED = "E_RECEIPT_FINISHED_FAILED"
    public static let E_TRANSACTION_VALIDATION_FAILED = "E_TRANSACTION_VALIDATION_FAILED"
    public static let E_EMPTY_SKU_LIST = "E_EMPTY_SKU_LIST"
    
    // MARK: Generic Error
    public static let E_UNKNOWN = "E_UNKNOWN"
    
    /// Create PurchaseError from OpenIapError
    public init(from error: OpenIapError, productId: String? = nil) {
        switch error {
        case .purchaseCancelled:
            self.init(
                code: Self.E_USER_CANCELLED,
                message: "User cancelled the purchase flow",
                productId: productId
            )
        case .purchaseDeferred:
            self.init(
                code: Self.E_DEFERRED_PAYMENT,
                message: "Payment was deferred (pending family approval, etc.)",
                productId: productId
            )
        case .productNotFound(let id):
            self.init(
                code: Self.E_SKU_NOT_FOUND,
                message: "SKU not found: \(id)",
                productId: id
            )
        case .purchaseFailed(let reason):
            self.init(
                code: Self.E_SERVICE_ERROR,
                message: "Purchase failed: \(reason)",
                productId: productId
            )
        case .paymentNotAllowed:
            self.init(
                code: Self.E_IAP_NOT_AVAILABLE,
                message: "In-app purchase not allowed on this device",
                productId: productId
            )
        case .invalidReceipt:
            self.init(
                code: Self.E_RECEIPT_FAILED,
                message: "Receipt validation failed",
                productId: productId
            )
        case .networkError:
            self.init(
                code: Self.E_NETWORK_ERROR,
                message: "Network connection error",
                productId: productId
            )
        case .verificationFailed(let reason):
            self.init(
                code: Self.E_TRANSACTION_VALIDATION_FAILED,
                message: "Transaction validation failed: \(reason)",
                productId: productId
            )
        case .restoreFailed(let reason):
            self.init(
                code: Self.E_SERVICE_ERROR,
                message: "Restore failed: \(reason)",
                productId: productId
            )
        case .storeKitError(let error):
            self.init(
                code: Self.E_SERVICE_ERROR,
                message: "Store service error: \(error.localizedDescription)",
                productId: productId
            )
        case .notSupported:
            self.init(
                code: Self.E_FEATURE_NOT_SUPPORTED,
                message: "Feature not supported on this platform",
                productId: productId
            )
        case .unknownError:
            self.init(
                code: Self.E_UNKNOWN,
                message: "Unknown error occurred",
                productId: productId
            )
        }
    }
    
    // MARK: - Retry Strategy
    
    /// Check if error can be retried
    public var canRetry: Bool {
        switch code {
        case Self.E_NETWORK_ERROR,
             Self.E_SERVICE_ERROR,
             Self.E_REMOTE_ERROR,
             Self.E_CONNECTION_CLOSED,
             Self.E_SYNC_ERROR,
             Self.E_INIT_CONNECTION,
             Self.E_SERVICE_DISCONNECTED:
            return true
        default:
            return false
        }
    }
    
    /// Get retry delay in seconds based on error type and attempt number
    public func retryDelay(attempt: Int) -> TimeInterval? {
        guard canRetry else { return nil }
        
        switch code {
        case Self.E_NETWORK_ERROR, Self.E_SYNC_ERROR:
            // Exponential backoff (2^n seconds)
            return TimeInterval(pow(2.0, Double(attempt)))
        case Self.E_SERVICE_ERROR:
            // Linear backoff (n * 5 seconds)
            return TimeInterval(attempt * 5)
        case Self.E_REMOTE_ERROR:
            // Fixed delay (10 seconds)
            return 10
        case Self.E_CONNECTION_CLOSED, Self.E_INIT_CONNECTION, Self.E_SERVICE_DISCONNECTED:
            // Reinitialize and retry with exponential backoff
            return TimeInterval(pow(2.0, Double(attempt)))
        default:
            return nil
        }
    }
    
    // MARK: - Convenience Factory Methods
    
    /// Create error for empty SKU list
    public static func emptySkuList() -> PurchaseError {
        return PurchaseError(
            code: E_EMPTY_SKU_LIST,
            message: "Empty SKU list provided"
        )
    }
    
    /// Create error for already owned item
    public static func alreadyOwned(productId: String) -> PurchaseError {
        return PurchaseError(
            code: E_ALREADY_OWNED,
            message: "Item already owned by user",
            productId: productId
        )
    }
    
    /// Create error for item not owned
    public static func itemNotOwned(productId: String) -> PurchaseError {
        return PurchaseError(
            code: E_ITEM_NOT_OWNED,
            message: "Item not owned by user",
            productId: productId
        )
    }
    
    /// Create error for connection initialization failure
    public static func initConnectionFailed(message: String = "Failed to initialize store connection") -> PurchaseError {
        return PurchaseError(
            code: E_INIT_CONNECTION,
            message: message
        )
    }
    
    /// Create error for service disconnected
    public static func serviceDisconnected() -> PurchaseError {
        return PurchaseError(
            code: E_SERVICE_DISCONNECTED,
            message: "Store service disconnected"
        )
    }
    
    // MARK: - StoreKit Error Mapping
    
    /// Create PurchaseError from StoreKit error
    @available(iOS 15.0, macOS 14.0, *)
    public init(from error: Error, productId: String? = nil) {
        if let skError = error as? SKError {
            switch skError.code {
            case .paymentCancelled:
                self = PurchaseError(
                    code: Self.E_USER_CANCELLED,
                    message: "User cancelled transaction",
                    productId: productId
                )
            case .cloudServiceNetworkConnectionFailed, .cloudServicePermissionDenied:
                self = PurchaseError(
                    code: Self.E_NETWORK_ERROR,
                    message: "Network unavailable",
                    productId: productId
                )
            case .storeProductNotAvailable:
                self = PurchaseError(
                    code: Self.E_ITEM_UNAVAILABLE,
                    message: "Product not available",
                    productId: productId
                )
            case .paymentNotAllowed:
                self = PurchaseError(
                    code: Self.E_IAP_NOT_AVAILABLE,
                    message: "In-app purchase not available",
                    productId: productId
                )
            case .paymentInvalid:
                self = PurchaseError(
                    code: Self.E_RECEIPT_FAILED,
                    message: "Receipt validation failed",
                    productId: productId
                )
            default:
                self = PurchaseError(
                    code: Self.E_SERVICE_ERROR,
                    message: "App Store service error: \(skError.localizedDescription)",
                    productId: productId
                )
            }
        } else if let storeKitError = error as? StoreKitError {
            switch storeKitError {
            case .userCancelled:
                self = PurchaseError(
                    code: Self.E_USER_CANCELLED,
                    message: "User cancelled the purchase",
                    productId: productId
                )
            case .networkError(_):
                self = PurchaseError(
                    code: Self.E_NETWORK_ERROR,
                    message: "Network error occurred",
                    productId: productId
                )
            case .systemError(_):
                self = PurchaseError(
                    code: Self.E_SERVICE_ERROR,
                    message: "System error occurred",
                    productId: productId
                )
            case .notAvailableInStorefront:
                self = PurchaseError(
                    code: Self.E_ITEM_UNAVAILABLE,
                    message: "Product not available in storefront",
                    productId: productId
                )
            case .notEntitled:
                self = PurchaseError(
                    code: Self.E_ITEM_NOT_OWNED,
                    message: "User not entitled to this product",
                    productId: productId
                )
            default:
                self = PurchaseError(
                    code: Self.E_UNKNOWN,
                    message: "Unknown error: \(error.localizedDescription)",
                    productId: productId
                )
            }
        } else {
            // Generic error
            self = PurchaseError(
                code: Self.E_UNKNOWN,
                message: error.localizedDescription,
                productId: productId
            )
        }
    }
}