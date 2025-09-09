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
    static let E_UNKNOWN = PurchaseError.E_UNKNOWN
    static let E_SERVICE_ERROR = PurchaseError.E_SERVICE_ERROR
    static let E_USER_CANCELLED = PurchaseError.E_USER_CANCELLED
    static let E_USER_ERROR = PurchaseError.E_USER_ERROR
    static let E_ITEM_UNAVAILABLE = PurchaseError.E_ITEM_UNAVAILABLE
    static let E_REMOTE_ERROR = PurchaseError.E_REMOTE_ERROR
    static let E_NETWORK_ERROR = PurchaseError.E_NETWORK_ERROR
    static let E_RECEIPT_FAILED = PurchaseError.E_RECEIPT_FAILED
    static let E_RECEIPT_FINISHED = PurchaseError.E_RECEIPT_FINISHED
    static let E_RECEIPT_FINISHED_FAILED = PurchaseError.E_RECEIPT_FINISHED_FAILED
    static let E_NOT_PREPARED = "E_NOT_PREPARED"
    static let E_NOT_ENDED = "E_NOT_ENDED"
    static let E_ALREADY_OWNED = PurchaseError.E_ALREADY_OWNED
    static let E_DEVELOPER_ERROR = "E_DEVELOPER_ERROR"
    static let E_PURCHASE_ERROR = "E_PURCHASE_ERROR"
    static let E_SYNC_ERROR = PurchaseError.E_SYNC_ERROR
    static let E_DEFERRED_PAYMENT = PurchaseError.E_DEFERRED_PAYMENT
    static let E_TRANSACTION_VALIDATION_FAILED = PurchaseError.E_TRANSACTION_VALIDATION_FAILED
    static let E_BILLING_RESPONSE_JSON_PARSE_ERROR = "E_BILLING_RESPONSE_JSON_PARSE_ERROR"
    static let E_INTERRUPTED = PurchaseError.E_INTERRUPTED
    static let E_IAP_NOT_AVAILABLE = PurchaseError.E_IAP_NOT_AVAILABLE
    static let E_ACTIVITY_UNAVAILABLE = "E_ACTIVITY_UNAVAILABLE"
    static let E_ALREADY_PREPARED = "E_ALREADY_PREPARED"
    static let E_PENDING = "E_PENDING"
    static let E_CONNECTION_CLOSED = PurchaseError.E_CONNECTION_CLOSED
    static let E_INIT_CONNECTION = PurchaseError.E_INIT_CONNECTION
    static let E_SERVICE_DISCONNECTED = PurchaseError.E_SERVICE_DISCONNECTED
    static let E_BILLING_UNAVAILABLE = PurchaseError.E_BILLING_UNAVAILABLE
    static let E_FEATURE_NOT_SUPPORTED = PurchaseError.E_FEATURE_NOT_SUPPORTED
    static let E_SKU_NOT_FOUND = PurchaseError.E_SKU_NOT_FOUND
    static let E_SKU_OFFER_MISMATCH = PurchaseError.E_SKU_OFFER_MISMATCH
    static let E_QUERY_PRODUCT = PurchaseError.E_QUERY_PRODUCT
    static let E_ITEM_NOT_OWNED = PurchaseError.E_ITEM_NOT_OWNED
    static let E_EMPTY_SKU_LIST = PurchaseError.E_EMPTY_SKU_LIST

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
