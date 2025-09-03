import Foundation
import StoreKit

public struct OpenIapPurchase: Codable, Equatable {
    // Core identification (PurchaseCommon required fields)
    public let id: String
    public let purchaseToken: String
    public let transactionId: String
    public let originalTransactionId: String?
    
    // Platform identification
    public let platform: String
    
    // Multiple product IDs support
    public let ids: [String]?
    
    // Timing information
    public let purchaseTime: Date
    public let originalPurchaseTime: Date?
    public let expiryTime: Date?
    
    // Purchase state
    public let isAutoRenewing: Bool
    public let purchaseState: PurchaseState
    public let acknowledgementState: AcknowledgementState
    public let quantity: Int
    
    // Legacy compatibility
    public let developerPayload: String?
    public let jwsRepresentation: String?
    public let jsonRepresentation: String?
    public let appAccountToken: String?
    
    // iOS StoreKit 2 additional properties
    public let webOrderLineItemIdIOS: Int?
    public let environmentIOS: String?
    public let storefrontCountryCodeIOS: String?
    public let appBundleIdIOS: String?
    public let productTypeIOS: String?
    public let subscriptionGroupIdIOS: String?
    public let isUpgradedIOS: Bool?
    public let ownershipTypeIOS: String?
    public let reasonIOS: String?
    public let reasonStringRepresentationIOS: String?
    public let transactionReasonIOS: String?
    public let revocationDateIOS: Date?
    public let revocationReasonIOS: String?
    
    // Offer information
    public let offerIOS: PurchaseOffer?
    
    // Price locale information
    public let currencyCodeIOS: String?
    public let currencySymbolIOS: String?
    public let countryCodeIOS: String?
    
    public enum PurchaseState: String, Codable {
        case pending
        case purchased
        case failed
        case restored
        case deferred
    }
    
    public enum AcknowledgementState: String, Codable {
        case notAcknowledged
        case acknowledged
    }
    
    // Computed properties for TypeScript type compatibility
    public var transactionDate: TimeInterval {
        return purchaseTime.timeIntervalSince1970 * 1000
    }
    
    public var transactionReceipt: String {
        return purchaseToken
    }
}

// Support structures
public struct PurchaseOffer: Codable, Equatable {
    public let id: String
    public let type: String
    public let paymentMode: String
    
    public init(id: String, type: String, paymentMode: String) {
        self.id = id
        self.type = type
        self.paymentMode = paymentMode
    }
}

// Options for purchase queries
public struct PurchaseOptions: Codable {
    public let alsoPublishToEventListener: Bool?
    public let onlyIncludeActiveItems: Bool?
    
    public init(alsoPublishToEventListener: Bool? = false, onlyIncludeActiveItems: Bool? = false) {
        self.alsoPublishToEventListener = alsoPublishToEventListener
        self.onlyIncludeActiveItems = onlyIncludeActiveItems
    }
}

@available(iOS 15.0, macOS 14.0, *)
extension OpenIapPurchase {
    init(from transaction: Transaction, jwsRepresentation: String? = nil) async {
        // Core identification
        self.id = transaction.productID
        self.transactionId = String(transaction.id)
        self.originalTransactionId = transaction.originalID != 0 ? String(transaction.originalID) : nil
        self.purchaseToken = jwsRepresentation ?? String(transaction.id)
        
        // Platform and IDs
        self.platform = "ios"
        self.ids = nil // Single product purchase
        
        // Timing information
        self.purchaseTime = transaction.purchaseDate
        self.originalPurchaseTime = transaction.originalPurchaseDate
        self.expiryTime = transaction.expirationDate
        
        // Purchase state
        self.isAutoRenewing = transaction.isUpgraded == false
        self.quantity = transaction.purchasedQuantity
        self.acknowledgementState = .acknowledged
        
        // Legacy compatibility
        self.developerPayload = transaction.appAccountToken?.uuidString
        self.jwsRepresentation = jwsRepresentation
        self.jsonRepresentation = String(data: transaction.jsonRepresentation, encoding: .utf8)
        self.appAccountToken = transaction.appAccountToken?.uuidString
        
        // iOS StoreKit 2 additional properties  
        self.webOrderLineItemIdIOS = Int(transaction.webOrderLineItemID ?? "0")
        
        // Environment (iOS 16.0+)
        if #available(iOS 16.0, macOS 14.0, *) {
            self.environmentIOS = transaction.environment.rawValue
        } else {
            self.environmentIOS = nil
        }
        self.storefrontCountryCodeIOS = transaction.storefrontCountryCode
        self.appBundleIdIOS = transaction.appBundleID
        self.subscriptionGroupIdIOS = transaction.subscriptionGroupID
        self.isUpgradedIOS = transaction.isUpgraded
        self.revocationDateIOS = transaction.revocationDate
        
        // Product type
        switch transaction.productType {
        case .consumable:
            self.productTypeIOS = "consumable"
        case .nonConsumable:
            self.productTypeIOS = "non_consumable" 
        case .autoRenewable:
            self.productTypeIOS = "auto_renewable_subscription"
        case .nonRenewable:
            self.productTypeIOS = "non_renewable_subscription"
        default:
            self.productTypeIOS = "unknown"
        }
        
        // Ownership type
        switch transaction.ownershipType {
        case .purchased:
            self.purchaseState = .purchased
            self.ownershipTypeIOS = "purchased"
        case .familyShared:
            self.purchaseState = .restored
            self.ownershipTypeIOS = "family_shared"
        default:
            self.purchaseState = .purchased
            self.ownershipTypeIOS = "purchased"
        }
        
        // Reason and revocation (iOS 17.0+)
        if #available(iOS 17.0, macOS 14.0, *) {
            switch transaction.reason {
            case .purchase:
                self.reasonIOS = "purchase"
                self.transactionReasonIOS = "PURCHASE"
            case .renewal:
                self.reasonIOS = "renewal"
                self.transactionReasonIOS = "RENEWAL"
            default:
                self.reasonIOS = "unknown"
                self.transactionReasonIOS = "PURCHASE"
            }
        } else {
            self.reasonIOS = nil
            self.transactionReasonIOS = "PURCHASE"
        }
        
        self.reasonStringRepresentationIOS = self.reasonIOS
        
        if let revocationReason = transaction.revocationReason {
            self.revocationReasonIOS = revocationReason.rawValue.description
        } else {
            self.revocationReasonIOS = nil
        }
        
        // Offer information (promotional offers, iOS 17.2+)
        if #available(iOS 17.2, macOS 14.2, *) {
            if let offer = transaction.offer {
                self.offerIOS = PurchaseOffer(
                    id: offer.id ?? "unknown",
                    type: offer.type.rawValue.description,
                    paymentMode: offer.paymentMode?.rawValue.description ?? "unknown"
                )
            } else {
                self.offerIOS = nil
            }
        } else {
            self.offerIOS = nil
        }
        
        // Price locale information - would need to get from Product if available
        self.currencyCodeIOS = nil
        self.currencySymbolIOS = nil
        self.countryCodeIOS = transaction.storefrontCountryCode
    }
}

public struct OpenIapReceipt: Codable {
    public let bundleId: String
    public let applicationVersion: String
    public let originalApplicationVersion: String?
    public let creationDate: Date
    public let expirationDate: Date?
    public let inAppPurchases: [OpenIapPurchase]
}