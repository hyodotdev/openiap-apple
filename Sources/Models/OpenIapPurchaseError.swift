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

// Backward/forward compatible prefixed alias
public typealias OpenIapPurchaseError = PurchaseError

// MARK: - Error Codes (OpenIAP Specification)
extension PurchaseError {
    /// Create error for empty SKU list
    public static func emptySkuList() -> PurchaseError {
        return PurchaseError(
            code: E_EMPTY_SKU_LIST,
            message: "Empty SKU list provided"
        )
    }
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
    
    // MARK: Extra Parity / Lifecycle (cross-platform constants)
    public static let E_NOT_PREPARED = "E_NOT_PREPARED"
    public static let E_NOT_ENDED = "E_NOT_ENDED"
    public static let E_DEVELOPER_ERROR = "E_DEVELOPER_ERROR"
    public static let E_PURCHASE_ERROR = "E_PURCHASE_ERROR"
    public static let E_ACTIVITY_UNAVAILABLE = "E_ACTIVITY_UNAVAILABLE"
    public static let E_ALREADY_PREPARED = "E_ALREADY_PREPARED"
    public static let E_PENDING = "E_PENDING"
    
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
}

// MARK: - Retry Strategy

extension PurchaseError {
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
}

// MARK: - Default Messages + Convenience Factory

extension PurchaseError {
    /// Default human-readable message for a given error code
    public static func defaultMessage(for code: String) -> String {
        switch code {
        // User Action Errors
        case Self.E_USER_CANCELLED: return "User cancelled the purchase flow"
        case Self.E_USER_ERROR: return "User action error"
        case Self.E_DEFERRED_PAYMENT: return "Payment was deferred (pending approval)"
        case Self.E_INTERRUPTED: return "Purchase flow interrupted"

        // Product Errors
        case Self.E_ITEM_UNAVAILABLE: return "Item unavailable"
        case Self.E_SKU_NOT_FOUND: return "SKU not found"
        case Self.E_SKU_OFFER_MISMATCH: return "SKU offer mismatch"
        case Self.E_QUERY_PRODUCT: return "Failed to query product"
        case Self.E_ALREADY_OWNED: return "Item already owned"
        case Self.E_ITEM_NOT_OWNED: return "Item not owned"

        // Network & Service Errors
        case Self.E_NETWORK_ERROR: return "Network connection error"
        case Self.E_SERVICE_ERROR: return "Store service error"
        case Self.E_REMOTE_ERROR: return "Remote service error"
        case Self.E_INIT_CONNECTION: return "Failed to initialize billing connection"
        case Self.E_SERVICE_DISCONNECTED: return "Billing service disconnected"
        case Self.E_CONNECTION_CLOSED: return "Connection closed"
        case Self.E_IAP_NOT_AVAILABLE: return "In-app purchases not available on this device"
        case Self.E_BILLING_UNAVAILABLE: return "Billing unavailable"
        case Self.E_FEATURE_NOT_SUPPORTED: return "Feature not supported on this platform"
        case Self.E_SYNC_ERROR: return "Sync error"

        // Validation Errors
        case Self.E_RECEIPT_FAILED: return "Receipt validation failed"
        case Self.E_RECEIPT_FINISHED: return "Receipt already finished"
        case Self.E_RECEIPT_FINISHED_FAILED: return "Receipt finish failed"
        case Self.E_TRANSACTION_VALIDATION_FAILED: return "Transaction validation failed"
        case Self.E_EMPTY_SKU_LIST: return "Empty SKU list provided"

        // Extra Parity / Lifecycle
        case Self.E_NOT_PREPARED: return "Billing is not prepared"
        case Self.E_NOT_ENDED: return "Billing connection not ended"
        case Self.E_DEVELOPER_ERROR: return "Developer configuration error"
        case Self.E_PURCHASE_ERROR: return "Purchase error"
        case Self.E_ACTIVITY_UNAVAILABLE: return "Required activity is unavailable"
        case Self.E_ALREADY_PREPARED: return "Billing already prepared"
        case Self.E_PENDING: return "Transaction pending"

        // Generic
        case Self.E_UNKNOWN: return "Unknown error occurred"
        default: return "Unknown error occurred"
        }
    }

    /// Convenience factory that fills a default message for the code
    public static func make(code: String, productId: String? = nil, message: String? = nil) -> PurchaseError {
        return PurchaseError(
            code: code,
            message: message ?? defaultMessage(for: code),
            productId: productId
        )
    }
}
