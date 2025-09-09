import Foundation

public enum OpenIapError: LocalizedError {
    case productNotFound(id: String)
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
        case .productNotFound(let id):
            return "Product not found: \(id)"
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

// MARK: - Error Code Constants + Mapping (for bridging)
public extension OpenIapError {
    // Expose the same string codes available on PurchaseError, for convenience
    // and to avoid importing two symbols at call sites.
    static let E_UNKNOWN = OpenIapErrorEvent.E_UNKNOWN
    static let E_SERVICE_ERROR = OpenIapErrorEvent.E_SERVICE_ERROR
    static let E_USER_CANCELLED = OpenIapErrorEvent.E_USER_CANCELLED
    static let E_USER_ERROR = OpenIapErrorEvent.E_USER_ERROR
    static let E_ITEM_UNAVAILABLE = OpenIapErrorEvent.E_ITEM_UNAVAILABLE
    static let E_REMOTE_ERROR = OpenIapErrorEvent.E_REMOTE_ERROR
    static let E_NETWORK_ERROR = OpenIapErrorEvent.E_NETWORK_ERROR
    static let E_RECEIPT_FAILED = OpenIapErrorEvent.E_RECEIPT_FAILED
    static let E_RECEIPT_FINISHED = OpenIapErrorEvent.E_RECEIPT_FINISHED
    static let E_RECEIPT_FINISHED_FAILED = OpenIapErrorEvent.E_RECEIPT_FINISHED_FAILED
    static let E_NOT_PREPARED = "E_NOT_PREPARED"
    static let E_NOT_ENDED = "E_NOT_ENDED"
    static let E_ALREADY_OWNED = OpenIapErrorEvent.E_ALREADY_OWNED
    static let E_DEVELOPER_ERROR = "E_DEVELOPER_ERROR"
    static let E_PURCHASE_ERROR = "E_PURCHASE_ERROR"
    static let E_SYNC_ERROR = OpenIapErrorEvent.E_SYNC_ERROR
    static let E_DEFERRED_PAYMENT = OpenIapErrorEvent.E_DEFERRED_PAYMENT
    static let E_TRANSACTION_VALIDATION_FAILED = OpenIapErrorEvent.E_TRANSACTION_VALIDATION_FAILED
    static let E_BILLING_RESPONSE_JSON_PARSE_ERROR = "E_BILLING_RESPONSE_JSON_PARSE_ERROR"
    static let E_INTERRUPTED = OpenIapErrorEvent.E_INTERRUPTED
    static let E_IAP_NOT_AVAILABLE = OpenIapErrorEvent.E_IAP_NOT_AVAILABLE
    static let E_ACTIVITY_UNAVAILABLE = "E_ACTIVITY_UNAVAILABLE"
    static let E_ALREADY_PREPARED = "E_ALREADY_PREPARED"
    static let E_PENDING = "E_PENDING"
    static let E_CONNECTION_CLOSED = OpenIapErrorEvent.E_CONNECTION_CLOSED
    static let E_INIT_CONNECTION = OpenIapErrorEvent.E_INIT_CONNECTION
    static let E_SERVICE_DISCONNECTED = OpenIapErrorEvent.E_SERVICE_DISCONNECTED
    static let E_BILLING_UNAVAILABLE = OpenIapErrorEvent.E_BILLING_UNAVAILABLE
    static let E_FEATURE_NOT_SUPPORTED = OpenIapErrorEvent.E_FEATURE_NOT_SUPPORTED
    static let E_SKU_NOT_FOUND = OpenIapErrorEvent.E_SKU_NOT_FOUND
    static let E_SKU_OFFER_MISMATCH = OpenIapErrorEvent.E_SKU_OFFER_MISMATCH
    static let E_QUERY_PRODUCT = OpenIapErrorEvent.E_QUERY_PRODUCT
    static let E_ITEM_NOT_OWNED = OpenIapErrorEvent.E_ITEM_NOT_OWNED
    static let E_EMPTY_SKU_LIST = OpenIapErrorEvent.E_EMPTY_SKU_LIST

    /// OpenIAP string code that corresponds to this error case
    var code: String {
        switch self {
        case .purchaseCancelled:
            return Self.E_USER_CANCELLED
        case .purchaseDeferred:
            return Self.E_DEFERRED_PAYMENT
        case .productNotFound:
            return Self.E_SKU_NOT_FOUND
        case .purchaseFailed:
            return Self.E_SERVICE_ERROR
        case .paymentNotAllowed:
            return Self.E_IAP_NOT_AVAILABLE
        case .invalidReceipt:
            return Self.E_RECEIPT_FAILED
        case .networkError:
            return Self.E_NETWORK_ERROR
        case .verificationFailed:
            return Self.E_TRANSACTION_VALIDATION_FAILED
        case .restoreFailed:
            return Self.E_SERVICE_ERROR
        case .storeKitError:
            return Self.E_SERVICE_ERROR
        case .notSupported:
            return Self.E_FEATURE_NOT_SUPPORTED
        case .unknownError:
            return Self.E_UNKNOWN
        }
    }

    /// Dictionary of error keys to OpenIAP codes
    static func errorCodes() -> [String: String] {
        return [
            // User Action Errors
            "userCancelled": Self.E_USER_CANCELLED,
            "userError": Self.E_USER_ERROR,
            "deferredPayment": Self.E_DEFERRED_PAYMENT,
            "interrupted": Self.E_INTERRUPTED,

            // Product Errors
            "itemUnavailable": Self.E_ITEM_UNAVAILABLE,
            "skuNotFound": Self.E_SKU_NOT_FOUND,
            "skuOfferMismatch": Self.E_SKU_OFFER_MISMATCH,
            "queryProduct": Self.E_QUERY_PRODUCT,
            "alreadyOwned": Self.E_ALREADY_OWNED,
            "itemNotOwned": Self.E_ITEM_NOT_OWNED,

            // Network & Service Errors
            "networkError": Self.E_NETWORK_ERROR,
            "serviceError": Self.E_SERVICE_ERROR,
            "remoteError": Self.E_REMOTE_ERROR,
            "initConnection": Self.E_INIT_CONNECTION,
            "serviceDisconnected": Self.E_SERVICE_DISCONNECTED,
            "connectionClosed": Self.E_CONNECTION_CLOSED,
            "iapNotAvailable": Self.E_IAP_NOT_AVAILABLE,
            "billingUnavailable": Self.E_BILLING_UNAVAILABLE,
            "featureNotSupported": Self.E_FEATURE_NOT_SUPPORTED,
            "syncError": Self.E_SYNC_ERROR,
            // Lifecycle/Preparation Errors (extra parity)
            "notPrepared": Self.E_NOT_PREPARED,
            "notEnded": Self.E_NOT_ENDED,
            "developerError": Self.E_DEVELOPER_ERROR,

            // Validation Errors
            "receiptFailed": Self.E_RECEIPT_FAILED,
            "receiptFinished": Self.E_RECEIPT_FINISHED,
            "receiptFinishedFailed": Self.E_RECEIPT_FINISHED_FAILED,
            "transactionValidationFailed": Self.E_TRANSACTION_VALIDATION_FAILED,
            "emptySkuList": Self.E_EMPTY_SKU_LIST,

            // Platform/Parsing Errors (extra parity)
            "billingResponseJsonParseError": Self.E_BILLING_RESPONSE_JSON_PARSE_ERROR,
            "activityUnavailable": Self.E_ACTIVITY_UNAVAILABLE,

            // State/Generic Errors (extra parity)
            "alreadyPrepared": Self.E_ALREADY_PREPARED,
            "pending": Self.E_PENDING,
            "purchaseError": Self.E_PURCHASE_ERROR,

            // Generic Error
            "unknown": Self.E_UNKNOWN
        ]
    }
}

// MARK: - Unified Error Event under OpenIapError namespace
public struct OpenIapErrorEvent: Codable, Equatable {
    public let code: String
    public let message: String
    public let productId: String?

    public init(code: String, message: String, productId: String? = nil) {
        self.code = code
        self.message = message
        self.productId = productId
    }

    // Re-export error code constants (single source under OpenIapError)
    public static let E_USER_CANCELLED = OpenIapError.E_USER_CANCELLED
    public static let E_USER_ERROR = OpenIapError.E_USER_ERROR
    public static let E_DEFERRED_PAYMENT = OpenIapError.E_DEFERRED_PAYMENT
    public static let E_INTERRUPTED = OpenIapError.E_INTERRUPTED
    public static let E_ITEM_UNAVAILABLE = OpenIapError.E_ITEM_UNAVAILABLE
    public static let E_SKU_NOT_FOUND = OpenIapError.E_SKU_NOT_FOUND
    public static let E_SKU_OFFER_MISMATCH = OpenIapError.E_SKU_OFFER_MISMATCH
    public static let E_QUERY_PRODUCT = OpenIapError.E_QUERY_PRODUCT
    public static let E_ALREADY_OWNED = OpenIapError.E_ALREADY_OWNED
    public static let E_ITEM_NOT_OWNED = OpenIapError.E_ITEM_NOT_OWNED
    public static let E_NETWORK_ERROR = OpenIapError.E_NETWORK_ERROR
    public static let E_SERVICE_ERROR = OpenIapError.E_SERVICE_ERROR
    public static let E_REMOTE_ERROR = OpenIapError.E_REMOTE_ERROR
    public static let E_INIT_CONNECTION = OpenIapError.E_INIT_CONNECTION
    public static let E_SERVICE_DISCONNECTED = OpenIapError.E_SERVICE_DISCONNECTED
    public static let E_CONNECTION_CLOSED = OpenIapError.E_CONNECTION_CLOSED
    public static let E_IAP_NOT_AVAILABLE = OpenIapError.E_IAP_NOT_AVAILABLE
    public static let E_BILLING_UNAVAILABLE = OpenIapError.E_BILLING_UNAVAILABLE
    public static let E_FEATURE_NOT_SUPPORTED = OpenIapError.E_FEATURE_NOT_SUPPORTED
    public static let E_SYNC_ERROR = OpenIapError.E_SYNC_ERROR
    public static let E_RECEIPT_FAILED = OpenIapError.E_RECEIPT_FAILED
    public static let E_RECEIPT_FINISHED = OpenIapError.E_RECEIPT_FINISHED
    public static let E_RECEIPT_FINISHED_FAILED = OpenIapError.E_RECEIPT_FINISHED_FAILED
    public static let E_TRANSACTION_VALIDATION_FAILED = OpenIapError.E_TRANSACTION_VALIDATION_FAILED
    public static let E_EMPTY_SKU_LIST = OpenIapError.E_EMPTY_SKU_LIST
    public static let E_NOT_PREPARED = OpenIapError.E_NOT_PREPARED
    public static let E_NOT_ENDED = OpenIapError.E_NOT_ENDED
    public static let E_DEVELOPER_ERROR = OpenIapError.E_DEVELOPER_ERROR
    public static let E_PURCHASE_ERROR = OpenIapError.E_PURCHASE_ERROR
    public static let E_ACTIVITY_UNAVAILABLE = OpenIapError.E_ACTIVITY_UNAVAILABLE
    public static let E_ALREADY_PREPARED = OpenIapError.E_ALREADY_PREPARED
    public static let E_PENDING = OpenIapError.E_PENDING
    public static let E_UNKNOWN = OpenIapError.E_UNKNOWN
}

public extension OpenIapErrorEvent {
    /// Default human-readable message for a given error code
    static func defaultMessage(for code: String) -> String {
        switch code {
        // User Action Errors
        case E_USER_CANCELLED: return "User cancelled the purchase flow"
        case E_USER_ERROR: return "User action error"
        case E_DEFERRED_PAYMENT: return "Payment was deferred (pending approval)"
        case E_INTERRUPTED: return "Purchase flow interrupted"

        // Product Errors
        case E_ITEM_UNAVAILABLE: return "Item unavailable"
        case E_SKU_NOT_FOUND: return "SKU not found"
        case E_SKU_OFFER_MISMATCH: return "SKU offer mismatch"
        case E_QUERY_PRODUCT: return "Failed to query product"
        case E_ALREADY_OWNED: return "Item already owned"
        case E_ITEM_NOT_OWNED: return "Item not owned"

        // Network & Service Errors
        case E_NETWORK_ERROR: return "Network connection error"
        case E_SERVICE_ERROR: return "Store service error"
        case E_REMOTE_ERROR: return "Remote service error"
        case E_INIT_CONNECTION: return "Failed to initialize billing connection"
        case E_SERVICE_DISCONNECTED: return "Billing service disconnected"
        case E_CONNECTION_CLOSED: return "Connection closed"
        case E_IAP_NOT_AVAILABLE: return "In-app purchases not available on this device"
        case E_BILLING_UNAVAILABLE: return "Billing unavailable"
        case E_FEATURE_NOT_SUPPORTED: return "Feature not supported on this platform"
        case E_SYNC_ERROR: return "Sync error"

        // Validation Errors
        case E_RECEIPT_FAILED: return "Receipt validation failed"
        case E_RECEIPT_FINISHED: return "Receipt already finished"
        case E_RECEIPT_FINISHED_FAILED: return "Receipt finish failed"
        case E_TRANSACTION_VALIDATION_FAILED: return "Transaction validation failed"
        case E_EMPTY_SKU_LIST: return "Empty SKU list provided"

        // Extra Parity / Lifecycle
        case E_NOT_PREPARED: return "Billing is not prepared"
        case E_NOT_ENDED: return "Billing connection not ended"
        case E_DEVELOPER_ERROR: return "Developer configuration error"
        case E_PURCHASE_ERROR: return "Purchase error"
        case E_ACTIVITY_UNAVAILABLE: return "Required activity is unavailable"
        case E_ALREADY_PREPARED: return "Billing already prepared"
        case E_PENDING: return "Transaction pending"

        // Generic
        case E_UNKNOWN: return "Unknown error occurred"
        default: return "Unknown error occurred"
        }
    }

    /// Convenience factory that fills a default message for the code
    static func make(code: String, productId: String? = nil, message: String? = nil) -> OpenIapErrorEvent {
        return OpenIapErrorEvent(
            code: code,
            message: message ?? defaultMessage(for: code),
            productId: productId
        )
    }

    /// Create from OpenIapError
    init(from error: OpenIapError, productId: String? = nil) {
        switch error {
        case .purchaseCancelled:
            self.init(code: Self.E_USER_CANCELLED, message: "User cancelled the purchase flow", productId: productId)
        case .purchaseDeferred:
            self.init(code: Self.E_DEFERRED_PAYMENT, message: "Payment was deferred (pending family approval, etc.)", productId: productId)
        case .productNotFound(let id):
            self.init(code: Self.E_SKU_NOT_FOUND, message: "SKU not found: \(id)", productId: id)
        case .purchaseFailed(let reason):
            self.init(code: Self.E_SERVICE_ERROR, message: "Purchase failed: \(reason)", productId: productId)
        case .paymentNotAllowed:
            self.init(code: Self.E_IAP_NOT_AVAILABLE, message: "In-app purchase not allowed on this device", productId: productId)
        case .invalidReceipt:
            self.init(code: Self.E_RECEIPT_FAILED, message: "Receipt validation failed", productId: productId)
        case .networkError:
            self.init(code: Self.E_NETWORK_ERROR, message: "Network connection error", productId: productId)
        case .verificationFailed(let reason):
            self.init(code: Self.E_TRANSACTION_VALIDATION_FAILED, message: "Transaction validation failed: \(reason)", productId: productId)
        case .restoreFailed(let reason):
            self.init(code: Self.E_SERVICE_ERROR, message: "Restore failed: \(reason)", productId: productId)
        case .storeKitError(let error):
            self.init(code: Self.E_SERVICE_ERROR, message: "Store service error: \(error.localizedDescription)", productId: productId)
        case .notSupported:
            self.init(code: Self.E_FEATURE_NOT_SUPPORTED, message: "Feature not supported on this platform", productId: productId)
        case .unknownError:
            self.init(code: Self.E_UNKNOWN, message: "Unknown error occurred", productId: productId)
        }
    }

    /// Check if error can be retried
    var canRetry: Bool {
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
    func retryDelay(attempt: Int) -> TimeInterval? {
        guard canRetry else { return nil }
        switch code {
        case Self.E_NETWORK_ERROR, Self.E_SYNC_ERROR:
            return TimeInterval(pow(2.0, Double(attempt)))
        case Self.E_SERVICE_ERROR:
            return TimeInterval(attempt * 5)
        case Self.E_REMOTE_ERROR:
            return 10
        case Self.E_CONNECTION_CLOSED, Self.E_INIT_CONNECTION, Self.E_SERVICE_DISCONNECTED:
            return TimeInterval(pow(2.0, Double(attempt)))
        default:
            return nil
        }
    }
}
