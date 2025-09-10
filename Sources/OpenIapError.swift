import Foundation

// MARK: - Unified Error Event + Codes
public struct OpenIapError: Codable, Equatable, LocalizedError {
    public let code: String
    public let message: String
    public let productId: String?

    public init(code: String, message: String, productId: String? = nil) {
        self.code = code
        self.message = message
        self.productId = productId
    }

    public var errorDescription: String? { message }
}

public extension OpenIapError {
    // Error Code Constants (single source)
    static let E_UNKNOWN = "E_UNKNOWN"
    static let E_SERVICE_ERROR = "E_SERVICE_ERROR"
    static let E_USER_CANCELLED = "E_USER_CANCELLED"
    static let E_USER_ERROR = "E_USER_ERROR"
    static let E_ITEM_UNAVAILABLE = "E_ITEM_UNAVAILABLE"
    static let E_REMOTE_ERROR = "E_REMOTE_ERROR"
    static let E_NETWORK_ERROR = "E_NETWORK_ERROR"
    static let E_RECEIPT_FAILED = "E_RECEIPT_FAILED"
    static let E_RECEIPT_FINISHED = "E_RECEIPT_FINISHED"
    static let E_RECEIPT_FINISHED_FAILED = "E_RECEIPT_FINISHED_FAILED"
    static let E_NOT_PREPARED = "E_NOT_PREPARED"
    static let E_NOT_ENDED = "E_NOT_ENDED"
    static let E_ALREADY_OWNED = "E_ALREADY_OWNED"
    static let E_DEVELOPER_ERROR = "E_DEVELOPER_ERROR"
    static let E_PURCHASE_ERROR = "E_PURCHASE_ERROR"
    static let E_SYNC_ERROR = "E_SYNC_ERROR"
    static let E_DEFERRED_PAYMENT = "E_DEFERRED_PAYMENT"
    static let E_TRANSACTION_VALIDATION_FAILED = "E_TRANSACTION_VALIDATION_FAILED"
    static let E_BILLING_RESPONSE_JSON_PARSE_ERROR = "E_BILLING_RESPONSE_JSON_PARSE_ERROR"
    static let E_INTERRUPTED = "E_INTERRUPTED"
    static let E_IAP_NOT_AVAILABLE = "E_IAP_NOT_AVAILABLE"
    static let E_ACTIVITY_UNAVAILABLE = "E_ACTIVITY_UNAVAILABLE"
    static let E_ALREADY_PREPARED = "E_ALREADY_PREPARED"
    static let E_PENDING = "E_PENDING"
    static let E_CONNECTION_CLOSED = "E_CONNECTION_CLOSED"
    static let E_INIT_CONNECTION = "E_INIT_CONNECTION"
    static let E_SERVICE_DISCONNECTED = "E_SERVICE_DISCONNECTED"
    static let E_BILLING_UNAVAILABLE = "E_BILLING_UNAVAILABLE"
    static let E_FEATURE_NOT_SUPPORTED = "E_FEATURE_NOT_SUPPORTED"
    static let E_SKU_NOT_FOUND = "E_SKU_NOT_FOUND"
    static let E_SKU_OFFER_MISMATCH = "E_SKU_OFFER_MISMATCH"
    static let E_QUERY_PRODUCT = "E_QUERY_PRODUCT"
    static let E_ITEM_NOT_OWNED = "E_ITEM_NOT_OWNED"
    static let E_EMPTY_SKU_LIST = "E_EMPTY_SKU_LIST"

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

public extension OpenIapError {
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
    static func make(code: String, productId: String? = nil, message: String? = nil) -> OpenIapError {
        return OpenIapError(
            code: code,
            message: message ?? defaultMessage(for: code),
            productId: productId
        )
    }

    /// Convenience: create error for empty SKU list (parity with previous API)
    static func emptySkuList() -> OpenIapError {
        return OpenIapError(code: OpenIapError.E_EMPTY_SKU_LIST, message: "Empty SKU list provided")
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

