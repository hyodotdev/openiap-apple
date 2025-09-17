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
    static let Unknown = "E_UNKNOWN"
    static let ServiceError = "E_SERVICE_ERROR"
    static let UserCancelled = "E_USER_CANCELLED"
    static let UserError = "E_USER_ERROR"
    static let ItemUnavailable = "E_ITEM_UNAVAILABLE"
    static let RemoteError = "E_REMOTE_ERROR"
    static let NetworkError = "E_NETWORK_ERROR"
    static let ReceiptFailed = "E_RECEIPT_FAILED"
    static let ReceiptFinished = "E_RECEIPT_FINISHED"
    static let ReceiptFinishedFailed = "E_RECEIPT_FINISHED_FAILED"
    static let NotPrepared = "E_NOT_PREPARED"
    static let NotEnded = "E_NOT_ENDED"
    static let AlreadyOwned = "E_ALREADY_OWNED"
    static let DeveloperError = "E_DEVELOPER_ERROR"
    static let PurchaseError = "E_PURCHASE_ERROR"
    static let SyncError = "E_SYNC_ERROR"
    static let DeferredPayment = "E_DEFERRED_PAYMENT"
    static let TransactionValidationFailed = "E_TRANSACTION_VALIDATION_FAILED"
    static let BillingResponseJsonParseError = "E_BILLING_RESPONSE_JSON_PARSE_ERROR"
    static let Interrupted = "E_INTERRUPTED"
    static let IapNotAvailable = "E_IAP_NOT_AVAILABLE"
    static let ActivityUnavailable = "E_ACTIVITY_UNAVAILABLE"
    static let AlreadyPrepared = "E_ALREADY_PREPARED"
    static let Pending = "E_PENDING"
    static let ConnectionClosed = "E_CONNECTION_CLOSED"
    static let InitConnection = "E_INIT_CONNECTION"
    static let ServiceDisconnected = "E_SERVICE_DISCONNECTED"
    static let BillingUnavailable = "E_BILLING_UNAVAILABLE"
    static let FeatureNotSupported = "E_FEATURE_NOT_SUPPORTED"
    static let SkuNotFound = "E_SKU_NOT_FOUND"
    static let SkuOfferMismatch = "E_SKU_OFFER_MISMATCH"
    static let QueryProduct = "E_QUERY_PRODUCT"
    static let ItemNotOwned = "E_ITEM_NOT_OWNED"
    static let EmptySkuList = "E_EMPTY_SKU_LIST"

    /// Dictionary of error keys to OpenIAP codes
    /// Keys use PascalCase to match TS ErrorCode enum
    static func errorCodes() -> [String: String] {
        return [
            // User Action Errors
            "UserCancelled": Self.UserCancelled,
            "UserError": Self.UserError,
            "DeferredPayment": Self.DeferredPayment,
            "Interrupted": Self.Interrupted,

            // Product Errors
            "ItemUnavailable": Self.ItemUnavailable,
            "SkuNotFound": Self.SkuNotFound,
            "SkuOfferMismatch": Self.SkuOfferMismatch,
            "QueryProduct": Self.QueryProduct,
            "AlreadyOwned": Self.AlreadyOwned,
            "ItemNotOwned": Self.ItemNotOwned,

            // Network & Service Errors
            "NetworkError": Self.NetworkError,
            "ServiceError": Self.ServiceError,
            "RemoteError": Self.RemoteError,
            "InitConnection": Self.InitConnection,
            "ServiceDisconnected": Self.ServiceDisconnected,
            "ConnectionClosed": Self.ConnectionClosed,
            "IapNotAvailable": Self.IapNotAvailable,
            "BillingUnavailable": Self.BillingUnavailable,
            "FeatureNotSupported": Self.FeatureNotSupported,
            "SyncError": Self.SyncError,
            // Lifecycle/Preparation Errors (extra parity)
            "NotPrepared": Self.NotPrepared,
            "NotEnded": Self.NotEnded,
            "DeveloperError": Self.DeveloperError,

            // Validation Errors
            "ReceiptFailed": Self.ReceiptFailed,
            "ReceiptFinished": Self.ReceiptFinished,
            "ReceiptFinishedFailed": Self.ReceiptFinishedFailed,
            "TransactionValidationFailed": Self.TransactionValidationFailed,
            "EmptySkuList": Self.EmptySkuList,

            // Platform/Parsing Errors (extra parity)
            "BillingResponseJsonParseError": Self.BillingResponseJsonParseError,
            "ActivityUnavailable": Self.ActivityUnavailable,

            // State/Generic Errors (extra parity)
            "AlreadyPrepared": Self.AlreadyPrepared,
            "Pending": Self.Pending,
            "PurchaseError": Self.PurchaseError,

            // Generic Error
            "Unknown": Self.Unknown
        ]
    }
}

public extension OpenIapError {
    /// Default human-readable message for a given error code
    static func defaultMessage(for code: String) -> String {
        switch code {
        // User Action Errors
        case UserCancelled: return "User cancelled the purchase flow"
        case UserError: return "User action error"
        case DeferredPayment: return "Payment was deferred (pending approval)"
        case Interrupted: return "Purchase flow interrupted"

        // Product Errors
        case ItemUnavailable: return "Item unavailable"
        case SkuNotFound: return "SKU not found"
        case SkuOfferMismatch: return "SKU offer mismatch"
        case QueryProduct: return "Failed to query product"
        case AlreadyOwned: return "Item already owned"
        case ItemNotOwned: return "Item not owned"

        // Network & Service Errors
        case NetworkError: return "Network connection error"
        case ServiceError: return "Store service error"
        case RemoteError: return "Remote service error"
        case InitConnection: return "Failed to initialize billing connection"
        case ServiceDisconnected: return "Billing service disconnected"
        case ConnectionClosed: return "Connection closed"
        case IapNotAvailable: return "In-app purchases not available on this device"
        case BillingUnavailable: return "Billing unavailable"
        case FeatureNotSupported: return "Feature not supported on this platform"
        case SyncError: return "Sync error"

        // Validation Errors
        case ReceiptFailed: return "Receipt validation failed"
        case ReceiptFinished: return "Receipt already finished"
        case ReceiptFinishedFailed: return "Receipt finish failed"
        case TransactionValidationFailed: return "Transaction validation failed"
        case EmptySkuList: return "Empty SKU list provided"

        // Extra Parity / Lifecycle
        case NotPrepared: return "Billing is not prepared"
        case NotEnded: return "Billing connection not ended"
        case DeveloperError: return "Developer configuration error"
        case PurchaseError: return "Purchase error"
        case ActivityUnavailable: return "Required activity is unavailable"
        case AlreadyPrepared: return "Billing already prepared"
        case Pending: return "Transaction pending"

        // Generic
        case Unknown: return "Unknown error occurred"
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
        return OpenIapError(code: OpenIapError.EmptySkuList, message: "Empty SKU list provided")
    }

    /// Check if error can be retried
    var canRetry: Bool {
        switch code {
        case Self.NetworkError,
             Self.ServiceError,
             Self.RemoteError,
             Self.ConnectionClosed,
             Self.SyncError,
             Self.InitConnection,
             Self.ServiceDisconnected:
            return true
        default:
            return false
        }
    }

    /// Get retry delay in seconds based on error type and attempt number
    func retryDelay(attempt: Int) -> TimeInterval? {
        guard canRetry else { return nil }
        switch code {
        case Self.NetworkError, Self.SyncError:
            return TimeInterval(pow(2.0, Double(attempt)))
        case Self.ServiceError:
            return TimeInterval(attempt * 5)
        case Self.RemoteError:
            return 10
        case Self.ConnectionClosed, Self.InitConnection, Self.ServiceDisconnected:
            return TimeInterval(pow(2.0, Double(attempt)))
        default:
            return nil
        }
    }
}
