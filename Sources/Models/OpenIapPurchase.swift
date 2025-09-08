import Foundation
import StoreKit

public struct OpenIapPurchase: Codable, Equatable, Sendable {
    // MARK: - PurchaseCommon fields
    public let id: String                      // Transaction ID (primary identifier)
    public let productId: String               // Product identifier
    public let ids: [String]?                  // Common field for both platforms
    public let transactionDate: Double         // Unix timestamp in milliseconds
    public let transactionReceipt: String      // Purchase receipt/token
    public let purchaseToken: String?          // Purchase token
    public let platform: String                // Always "ios"
    public let quantity: Int                   // Purchase quantity (common field, defaults to 1)
    public let purchaseState: OpenIapPurchaseState    // Purchase state (common field)
    public let isAutoRenewing: Bool            // Auto-renewable subscription flag (common field)
    
    // MARK: - PurchaseIOS specific fields
    public let quantityIOS: Int?
    public let originalTransactionDateIOS: Double?
    public let originalTransactionIdentifierIOS: String?
    public let appAccountToken: String?
    public let expirationDateIOS: Double?
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
    public let transactionReasonIOS: String?  // 'PURCHASE' | 'RENEWAL' | string
    public let revocationDateIOS: Double?
    public let revocationReasonIOS: String?
    public let offerIOS: PurchaseOffer?
    public let currencyCodeIOS: String?
    public let currencySymbolIOS: String?
    public let countryCodeIOS: String?
}

// MARK: - Support structures
public struct OpenIapPurchaseOffer: Codable, Equatable, Sendable {
    public let id: String
    public let type: String
    public let paymentMode: String
    
    public init(id: String, type: String, paymentMode: String) {
        self.id = id
        self.type = type
        self.paymentMode = paymentMode
    }
}

// MARK: - StoreKit 2 Integration
@available(iOS 15.0, macOS 14.0, *)
extension OpenIapPurchase {
    init(from transaction: Transaction, jwsRepresentation: String? = nil) async {
        // PurchaseCommon fields
        self.id = String(transaction.id)  // Transaction ID is the primary identifier
        self.productId = transaction.productID
        self.ids = nil // Single product purchase
        self.transactionDate = transaction.purchaseDate.timeIntervalSince1970 * 1000  // Unix timestamp in milliseconds
        self.transactionReceipt = jwsRepresentation ?? String(transaction.id)
        self.purchaseToken = jwsRepresentation ?? String(transaction.id)
        self.platform = "ios"
        self.quantity = transaction.purchasedQuantity
        self.purchaseState = .purchased  // StoreKit 2 transactions are verified and purchased
        
        // Check if it's an auto-renewable subscription
        switch transaction.productType {
        case .autoRenewable:
            self.isAutoRenewing = true
        default:
            self.isAutoRenewing = false
        }
        
        // PurchaseIOS specific fields
        self.quantityIOS = transaction.purchasedQuantity
        self.originalTransactionDateIOS = transaction.originalPurchaseDate.timeIntervalSince1970 * 1000
        self.originalTransactionIdentifierIOS = transaction.originalID != 0 ? String(transaction.originalID) : nil
        self.appAccountToken = transaction.appAccountToken?.uuidString
        self.expirationDateIOS = transaction.expirationDate.map { $0.timeIntervalSince1970 * 1000 }
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
            self.ownershipTypeIOS = "purchased"
        case .familyShared:
            self.ownershipTypeIOS = "family_shared"
        default:
            self.ownershipTypeIOS = "purchased"
        }
        
        // Reason (iOS 17.0+)
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
        
        // Revocation
        self.revocationDateIOS = transaction.revocationDate.map { $0.timeIntervalSince1970 * 1000 }
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
        
        // Currency and country (not directly available from Transaction)
        self.currencyCodeIOS = nil
        self.currencySymbolIOS = nil
        self.countryCodeIOS = transaction.storefrontCountryCode
    }
}

// MARK: - Purchase State Enum (Common)
public enum OpenIapPurchaseState: String, Codable, CaseIterable, Sendable {
    case pending = "pending"
    case purchased = "purchased" 
    case failed = "failed"
    case restored = "restored"
    case deferred = "deferred"
    case unknown = "unknown"
    
    public var isActive: Bool {
        switch self {
        case .purchased, .restored:
            return true
        case .pending, .failed, .deferred, .unknown:
            return false
        }
    }
    
    public var isAcknowledged: Bool {
        switch self {
        case .purchased, .restored:
            return true
        case .pending, .failed, .deferred, .unknown:
            return false
        }
    }
}

// MARK: - GetAvailablePurchases Props
// Options/props for getAvailablePurchases following OpenIAP spec
public struct OpenIapGetAvailablePurchasesProps: Codable, Sendable {
    public let alsoPublishToEventListenerIOS: Bool?
    public let onlyIncludeActiveItemsIOS: Bool?
    
    public init(alsoPublishToEventListenerIOS: Bool? = false, onlyIncludeActiveItemsIOS: Bool? = false) {
        self.alsoPublishToEventListenerIOS = alsoPublishToEventListenerIOS
        self.onlyIncludeActiveItemsIOS = onlyIncludeActiveItemsIOS
    }
}

// Backward compatibility aliases
public typealias PurchaseOffer = OpenIapPurchaseOffer
public typealias PurchaseState = OpenIapPurchaseState
public typealias PurchaseOptions = OpenIapGetAvailablePurchasesProps
public typealias OpenIapPurchaseOptions = OpenIapGetAvailablePurchasesProps
