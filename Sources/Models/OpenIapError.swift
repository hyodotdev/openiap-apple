import Foundation

public extension PurchaseError {
    // MARK: - Default Messages

    static func defaultMessage(for code: ErrorCode) -> String {
        switch code {
        case .unknown: return "Unknown error occurred"
        case .userCancelled: return "User cancelled the purchase flow"
        case .userError: return "User action error"
        case .itemUnavailable: return "Item unavailable"
        case .remoteError: return "Remote service error"
        case .networkError: return "Network connection error"
        case .serviceError: return "Store service error"
        case .receiptFailed: return "Receipt validation failed"
        case .receiptFinished: return "Receipt already finished"
        case .receiptFinishedFailed: return "Receipt finish failed"
        case .notPrepared: return "Billing is not prepared"
        case .notEnded: return "Billing connection not ended"
        case .alreadyOwned: return "Item already owned"
        case .developerError: return "Developer configuration error"
        case .billingResponseJsonParseError: return "Failed to parse billing response"
        case .deferredPayment: return "Payment was deferred (pending approval)"
        case .interrupted: return "Purchase flow interrupted"
        case .iapNotAvailable: return "In-app purchases not available on this device"
        case .purchaseError: return "Purchase error"
        case .syncError: return "Sync error"
        case .transactionValidationFailed: return "Transaction validation failed"
        case .activityUnavailable: return "Required activity is unavailable"
        case .alreadyPrepared: return "Billing already prepared"
        case .pending: return "Transaction pending"
        case .connectionClosed: return "Connection closed"
        case .initConnection: return "Failed to initialize billing connection"
        case .serviceDisconnected: return "Billing service disconnected"
        case .queryProduct: return "Failed to query product"
        case .skuNotFound: return "SKU not found"
        case .skuOfferMismatch: return "SKU offer mismatch"
        case .itemNotOwned: return "Item not owned"
        case .billingUnavailable: return "Billing unavailable"
        case .featureNotSupported: return "Feature not supported on this platform"
        case .emptySkuList: return "Empty SKU list provided"
        }
    }

    static func defaultMessage(for rawCode: String) -> String {
        if let parsed = ErrorCode(rawValue: rawCode) {
            return defaultMessage(for: parsed)
        }
        return "Unknown error occurred"
    }

    static func make(
        code: ErrorCode,
        productId: String? = nil,
        message: String? = nil
    ) -> PurchaseError {
        PurchaseError(
            code: code,
            message: message ?? defaultMessage(for: code),
            productId: productId
        )
    }

    // MARK: - Legacy Identifiers

    static let E_UNKNOWN = ErrorCode.unknown.legacyIdentifier
    static let E_USER_CANCELLED = ErrorCode.userCancelled.legacyIdentifier
    static let E_USER_ERROR = ErrorCode.userError.legacyIdentifier
    static let E_ITEM_UNAVAILABLE = ErrorCode.itemUnavailable.legacyIdentifier
    static let E_REMOTE_ERROR = ErrorCode.remoteError.legacyIdentifier
    static let E_NETWORK_ERROR = ErrorCode.networkError.legacyIdentifier
    static let E_SERVICE_ERROR = ErrorCode.serviceError.legacyIdentifier
    static let E_RECEIPT_FAILED = ErrorCode.receiptFailed.legacyIdentifier
    static let E_RECEIPT_FINISHED = ErrorCode.receiptFinished.legacyIdentifier
    static let E_RECEIPT_FINISHED_FAILED = ErrorCode.receiptFinishedFailed.legacyIdentifier
    static let E_NOT_PREPARED = ErrorCode.notPrepared.legacyIdentifier
    static let E_NOT_ENDED = ErrorCode.notEnded.legacyIdentifier
    static let E_ALREADY_OWNED = ErrorCode.alreadyOwned.legacyIdentifier
    static let E_DEVELOPER_ERROR = ErrorCode.developerError.legacyIdentifier
    static let E_BILLING_RESPONSE_JSON_PARSE_ERROR = ErrorCode.billingResponseJsonParseError.legacyIdentifier
    static let E_DEFERRED_PAYMENT = ErrorCode.deferredPayment.legacyIdentifier
    static let E_INTERRUPTED = ErrorCode.interrupted.legacyIdentifier
    static let E_IAP_NOT_AVAILABLE = ErrorCode.iapNotAvailable.legacyIdentifier
    static let E_PURCHASE_ERROR = ErrorCode.purchaseError.legacyIdentifier
    static let E_SYNC_ERROR = ErrorCode.syncError.legacyIdentifier
    static let E_TRANSACTION_VALIDATION_FAILED = ErrorCode.transactionValidationFailed.legacyIdentifier
    static let E_ACTIVITY_UNAVAILABLE = ErrorCode.activityUnavailable.legacyIdentifier
    static let E_ALREADY_PREPARED = ErrorCode.alreadyPrepared.legacyIdentifier
    static let E_PENDING = ErrorCode.pending.legacyIdentifier
    static let E_CONNECTION_CLOSED = ErrorCode.connectionClosed.legacyIdentifier
    static let E_INIT_CONNECTION = ErrorCode.initConnection.legacyIdentifier
    static let E_SERVICE_DISCONNECTED = ErrorCode.serviceDisconnected.legacyIdentifier
    static let E_QUERY_PRODUCT = ErrorCode.queryProduct.legacyIdentifier
    static let E_SKU_NOT_FOUND = ErrorCode.skuNotFound.legacyIdentifier
    static let E_SKU_OFFER_MISMATCH = ErrorCode.skuOfferMismatch.legacyIdentifier
    static let E_ITEM_NOT_OWNED = ErrorCode.itemNotOwned.legacyIdentifier
    static let E_BILLING_UNAVAILABLE = ErrorCode.billingUnavailable.legacyIdentifier
    static let E_FEATURE_NOT_SUPPORTED = ErrorCode.featureNotSupported.legacyIdentifier
    static let E_EMPTY_SKU_LIST = ErrorCode.emptySkuList.legacyIdentifier

    static func make(
        code: String,
        productId: String? = nil,
        message: String? = nil
    ) -> PurchaseError {
        let resolved = ErrorCode.fromLegacyIdentifier(code) ?? ErrorCode(rawValue: code) ?? .unknown
        return make(code: resolved, productId: productId, message: message)
    }

    static func emptySkuList(message: String? = nil) -> PurchaseError {
        make(code: .emptySkuList, message: message)
    }

    static func purchaseError(message: String? = nil, productId: String? = nil) -> PurchaseError {
        make(code: .purchaseError, productId: productId, message: message)
    }
}

extension ErrorCode {
    var legacyIdentifier: String {
        let transformed = rawValue.replacingOccurrences(of: "-", with: "_").uppercased()
        if transformed.hasPrefix("E_") {
            return transformed
        }
        return "E_" + transformed
    }

    static func fromLegacyIdentifier(_ value: String) -> ErrorCode? {
        if let direct = ErrorCode(rawValue: value) {
            return direct
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.uppercased().hasPrefix("E_") else {
            return nil
        }
        let normalized = trimmed.dropFirst(2)
        let hyphenated = normalized
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "_", with: "-")
            .lowercased()
        return ErrorCode(rawValue: hyphenated)
    }
}
