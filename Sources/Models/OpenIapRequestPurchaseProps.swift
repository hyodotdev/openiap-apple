import Foundation
import StoreKit

/// Purchase request parameters following OpenIAP specification
public struct OpenIapRequestPurchaseProps: Codable, Equatable, Sendable {
    /// Product SKU
    public let sku: String
    
    /// Auto-finish transaction (dangerous)
    public let andDangerouslyFinishTransactionAutomatically: Bool?
    
    /// App account token for user tracking
    public let appAccountToken: String?
    
    /// Purchase quantity
    public let quantity: Int?
    
    /// Payment discount offer
    public let withOffer: OpenIapDiscountOffer?
    
    public init(
        sku: String,
        andDangerouslyFinishTransactionAutomatically: Bool? = nil,
        appAccountToken: String? = nil,
        quantity: Int? = nil,
        withOffer: OpenIapDiscountOffer? = nil
    ) {
        self.sku = sku
        self.andDangerouslyFinishTransactionAutomatically = andDangerouslyFinishTransactionAutomatically
        self.appAccountToken = appAccountToken
        self.quantity = quantity
        self.withOffer = withOffer
    }
    
    /// Convenience init with legacy parameter names
    public init(
        sku: String,
        andDangerouslyFinishTransactionAutomatically: Bool,
        appAccountToken: String? = nil,
        quantity: Int = 1,
        discountOffer: [String: String]? = nil
    ) {
        self.sku = sku
        self.andDangerouslyFinishTransactionAutomatically = andDangerouslyFinishTransactionAutomatically
        self.appAccountToken = appAccountToken
        self.quantity = quantity
        
        // Convert legacy discountOffer to DiscountOffer
        if let discount = discountOffer {
            self.withOffer = OpenIapDiscountOffer(
                identifier: discount["identifier"] ?? "",
                keyIdentifier: discount["keyIdentifier"] ?? "",
                nonce: discount["nonce"] ?? "",
                signature: discount["signature"] ?? "",
                timestamp: discount["timestamp"] ?? ""
            )
        } else {
            self.withOffer = nil
        }
    }
}

/// Discount offer structure for promotional offers
public struct OpenIapDiscountOffer: Codable, Equatable, Sendable {
    /// Discount identifier
    public let identifier: String
    
    /// Key identifier for validation
    public let keyIdentifier: String
    
    /// Cryptographic nonce
    public let nonce: String
    
    /// Signature for validation
    public let signature: String
    
    /// Timestamp of discount offer
    public let timestamp: String
    
    public init(
        identifier: String,
        keyIdentifier: String,
        nonce: String,
        signature: String,
        timestamp: String
    ) {
        self.identifier = identifier
        self.keyIdentifier = keyIdentifier
        self.nonce = nonce
        self.signature = signature
        self.timestamp = timestamp
    }
    
    // Backward compatibility
    public init(
        id: String,
        keyIdentifier: String,
        nonce: String,
        signature: String,
        timestamp: String
    ) {
        self.identifier = id
        self.keyIdentifier = keyIdentifier
        self.nonce = nonce
        self.signature = signature
        self.timestamp = timestamp
    }
}

// MARK: - StoreKit 2 Integration

@available(iOS 15.0, macOS 14.0, *)
extension OpenIapDiscountOffer {
    /// Convert to StoreKit 2 Product.PurchaseOption for promotional offers
    func toPurchaseOption() -> Product.PurchaseOption? {
        guard let nonceUUID = UUID(uuidString: nonce),
              let signatureData = Data(base64Encoded: signature),
              let timestampInt = Int(timestamp) else {
            return nil
        }
        
        return .promotionalOffer(
            offerID: identifier,
            keyID: keyIdentifier,
            nonce: nonceUUID,
            signature: signatureData,
            timestamp: timestampInt
        )
    }
}

@available(iOS 15.0, macOS 14.0, *)
extension OpenIapRequestPurchaseProps {
    /// Convert to StoreKit 2 purchase options
    func toPurchaseOptions() -> [Product.PurchaseOption] {
        var options: [Product.PurchaseOption] = []
        
        if let quantity = quantity, quantity > 1 {
            options.append(.quantity(quantity))
        }
        
        if let token = appAccountToken,
           let uuid = UUID(uuidString: token) {
            options.append(.appAccountToken(uuid))
        }
        
        if let offer = withOffer,
           let purchaseOption = offer.toPurchaseOption() {
            options.append(purchaseOption)
        }
        
        return options
    }
}

// Backward compatibility aliases
public typealias RequestPurchaseProps = OpenIapRequestPurchaseProps
public typealias DiscountOffer = OpenIapDiscountOffer

