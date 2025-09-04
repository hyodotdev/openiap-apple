import Foundation

// MARK: - Receipt Validation Request

/// Receipt validation properties following OpenIAP specification
public struct ReceiptValidationProps: Codable, Equatable {
    /// Product SKU to validate
    public let sku: String
    
    public init(sku: String) {
        self.sku = sku
    }
}

// MARK: - Receipt Validation Result

/// Receipt Validation Result for iOS
public struct ReceiptValidationResult: Codable, Equatable {
    /// Whether the receipt is valid
    public let isValid: Bool
    
    /// Receipt data string
    public let receiptData: String
    
    /// JWS representation
    public let jwsRepresentation: String
    
    /// Latest transaction if available
    public let latestTransaction: OpenIapPurchase?
    
    public init(
        isValid: Bool,
        receiptData: String,
        jwsRepresentation: String,
        latestTransaction: OpenIapPurchase? = nil
    ) {
        self.isValid = isValid
        self.receiptData = receiptData
        self.jwsRepresentation = jwsRepresentation
        self.latestTransaction = latestTransaction
    }
}